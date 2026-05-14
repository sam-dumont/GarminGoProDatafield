using Toybox.Lang;
using Toybox.System;
using Toybox.StringUtil;
using Toybox.Math;

module ProtobufLib {
  // Stateful decoder over a ByteArray. Preferred over the free decodeVarint
  // function because it avoids the per-call [value, newPos] tuple allocation
  // (which is hot enough to matter on resource-constrained Garmin devices —
  // a single nested protobuf message can do hundreds of varint decodes).
  //
  // Use subDecoder() for nested message decoding to share the parent's
  // backing ByteArray instead of slicing.
  class Decoder {
    private var data;
    private var pos;
    private var limit;

    function initialize(data) {
      self.data = data;
      self.pos = 0;
      self.limit = data.size();
    }

    // Reconfigure this Decoder to view a sub-range of the same backing
    // ByteArray. Used by subDecoder() to allow zero-copy nested decode.
    function setRange(start, limit) {
      self.pos = start;
      self.limit = limit;
    }

    function remaining() {
      return limit - pos;
    }

    function position() {
      return pos;
    }

    function varint() {
      var result = 0;
      var shift = 0;
      var b;
      do {
        b = data[pos];
        pos++;
        result |= (b & 0x7F) << shift;
        shift += 7;
      } while (b & 0x80);
      return result;
    }

    function skipField(wireType) {
      if (wireType == 0) {            // varint
        while ((data[pos] & 0x80) != 0) { pos++; }
        pos++;
      } else if (wireType == 1) {     // 64-bit
        pos += 8;
      } else if (wireType == 2) {     // length-delimited
        pos += varint();
      } else if (wireType == 5) {     // 32-bit
        pos += 4;
      }
    }

    // Read a length-prefixed byte range as a fresh ByteArray.
    // Use subDecoder() instead when the bytes are a nested protobuf message.
    function bytes() {
      var len = varint();
      var b = data.slice(pos, pos + len);
      pos += len;
      return b;
    }

    // Read a length-prefixed byte range and decode as a UTF-8 string.
    // Avoids the char-array-build path that the free decodeVarint loop used.
    function string() {
      var len = varint();
      var s = StringUtil.convertEncodedString(
        data.slice(pos, pos + len),
        {:fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
         :toRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
         :encoding => StringUtil.CHAR_ENCODING_UTF8});
      pos += len;
      return s;
    }

    // Return a Decoder bounded over the next length-prefixed sub-range,
    // sharing the parent's backing ByteArray (no slice/copy). Advances the
    // parent past the sub-range.
    function subDecoder() {
      var len = varint();
      var sub = new Decoder(data);
      sub.setRange(pos, pos + len);
      pos += len;
      return sub;
    }

    function float32() {
      var b = data.slice(pos, pos + 4);
      var v = b.decodeNumber(Lang.NUMBER_FORMAT_FLOAT, {:endianness => Lang.ENDIAN_LITTLE});
      pos += 4;
      return v;
    }

    // Read 64-bit double (delegates to the free decodeFloat64 for the
    // bit-twiddling, then advances pos).
    function float64() {
      var v = ProtobufLib.decodeFloat64(data, pos);
      pos += 8;
      return v;
    }
  }

  // ---- Free functions (kept for backward compat with hand-written code) ----

  // Decode a varint from the data starting at pos
  // Returns [value, new_pos]
  function decodeVarint(data, pos) {
    var result = 0;
    var shift = 0;
    var b;
    do {
      b = data[pos];
      pos++;
      result |= (b & 0x7F) << shift;
      shift += 7;
    } while (b & 0x80);
    return [result, pos];
  }

  // Encode a varint value into the buffer
  function encodeVarint(buf, val) {
    while (val > 0x7F) {
      buf.add(0x80 | (val & 0x7F));
      val >>= 7;
    }
    buf.add(val);
  }

  // Skip a field based on its wire type
  function skipField(data, pos, wireType) {
    switch (wireType) {
      case 0: // Varint
        while (data[pos] & 0x80) { pos++; }
        pos++;
        break;
      case 1: // 64-bit
        pos += 8;
        break;
      case 2: // Length-delimited
        var len = decodeVarint(data, pos);
        pos = len[1] + len[0];
        break;
      case 5: // 32-bit
        pos += 4;
        break;
    }
    return pos;
  }

  // Decode a fixed 32-bit value
  function decodeFixed32(data, pos) {
    return data[pos] | (data[pos + 1] << 8) | (data[pos + 2] << 16) | (data[pos + 3] << 24);
  }

  // Decode a fixed 64-bit value (returns as two 32-bit parts)
  function decodeFixed64(data, pos) {
    var low = decodeFixed32(data, pos);
    var high = decodeFixed32(data, pos + 4);
    return [low, high];
  }

  // Encode a fixed 32-bit value
  function encodeFixed32(buf, val) {
    buf.add(val & 0xFF);
    buf.add((val >> 8) & 0xFF);
    buf.add((val >> 16) & 0xFF);
    buf.add((val >> 24) & 0xFF);
  }

  // Encode a fixed 64-bit value (from two 32-bit parts)
  function encodeFixed64(buf, low, high) {
    encodeFixed32(buf, low);
    encodeFixed32(buf, high);
  }

  // Decode IEEE 754 float32
  function decodeFloat32(data, pos) {
    // Use MonkeyC's native ByteArray decodeNumber for IEEE 754 float
    var bytes = data.slice(pos, pos + 4);
    return bytes.decodeNumber(Lang.NUMBER_FORMAT_FLOAT, {:endianness => Lang.ENDIAN_LITTLE});
  }

  // Decode IEEE 754 float64. Monkey C has no NUMBER_FORMAT_DOUBLE, so we
  // reconstruct the value from the raw bit pattern using Math.pow / division.
  // The previous implementation tried to coerce double bits into float32
  // bits and had off-by-one shifts that broke even simple round-trips.
  function decodeFloat64(data, pos) {
    var b0 = data[pos];
    var b1 = data[pos + 1];
    var b2 = data[pos + 2];
    var b3 = data[pos + 3];
    var b4 = data[pos + 4];
    var b5 = data[pos + 5];
    var b6 = data[pos + 6];
    var b7 = data[pos + 7];

    var signBit = (b7 & 0x80) >> 7;
    var biasedExp = ((b7 & 0x7F) << 4) | ((b6 & 0xF0) >> 4);

    // 52-bit mantissa: low 48 bits = bytes 0..5 (LE); high 4 bits = b6 & 0x0F.
    var mantLow = b0.toLong()
      | (b1.toLong() << 8)
      | (b2.toLong() << 16)
      | (b3.toLong() << 24)
      | (b4.toLong() << 32)
      | (b5.toLong() << 40);
    var mantissa = ((b6 & 0x0F).toLong() << 48) | mantLow;

    // Zero / negative zero.
    if (biasedExp == 0 && mantissa == 0l) {
      return signBit == 0 ? 0.0d : -0.0d;
    }
    // Infinity and NaN. Monkey C may not represent NaN as such; we return 0.
    if (biasedExp == 0x7FF) {
      if (mantissa == 0l) {
        return signBit == 0 ? Math.pow(2.0d, 1023) * 2.0d : -Math.pow(2.0d, 1023) * 2.0d;
      }
      return 0.0d;
    }

    // mantissa.toDouble() is exact only up to 2^53; above that we lose bits,
    // but that's beyond what protobuf serialization can reproduce anyway.
    var fraction = mantissa.toDouble() / Math.pow(2.0d, 52);
    var value;
    if (biasedExp == 0) {
      // Subnormal: implicit leading bit is 0, exponent is fixed at -1022.
      value = fraction * Math.pow(2.0d, -1022);
    } else {
      // Normalized: 1.xxx * 2^(biasedExp - 1023)
      value = (1.0d + fraction) * Math.pow(2.0d, biasedExp - 1023);
    }
    return signBit == 0 ? value : -value;
  }

  // Encode IEEE 754 float32.
  function encodeFloat32(buf, val) {
    var bytes = new [4]b;
    bytes.encodeNumber(val, Lang.NUMBER_FORMAT_FLOAT, {:endianness => Lang.ENDIAN_LITTLE});
    buf.addAll(bytes);
  }

  // Encode IEEE 754 float64. Inverse of decodeFloat64 above. Computes
  // sign/exponent/mantissa from the value and packs them little-endian.
  function encodeFloat64(buf, val) {
    // NaN: produce a canonical quiet NaN.
    if (val != val) {
      buf.addAll([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF8, 0x7F]b);
      return;
    }
    // Zero (Monkey C doesn't reliably distinguish +0.0 from -0.0; emit +0).
    if (val == 0.0d) {
      buf.addAll([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]b);
      return;
    }

    var signBit = 0;
    var absVal = val.toDouble();
    if (absVal < 0.0d) {
      signBit = 1;
      absVal = -absVal;
    }

    // Find the unbiased exponent: largest integer k such that 2^k <= absVal.
    // Math.log returns natural log; divide by ln(2) for log2.
    var unbiasedExp = Math.floor(Math.log(absVal, Math.E) / Math.log(2.0d, Math.E)).toNumber();

    // Compute the fractional part: absVal / 2^unbiasedExp - 1 should be in [0, 1).
    // Adjust for floating-point edge cases (frac may be slightly >=1 or <0).
    var scale = Math.pow(2.0d, unbiasedExp);
    var fraction = absVal / scale - 1.0d;
    if (fraction >= 1.0d) {
      fraction = (fraction + 1.0d) / 2.0d - 1.0d;
      unbiasedExp += 1;
    } else if (fraction < 0.0d) {
      fraction = (fraction + 1.0d) * 2.0d - 1.0d;
      unbiasedExp -= 1;
    }

    var biasedExp = unbiasedExp + 1023;
    var mantissa = (fraction * Math.pow(2.0d, 52)).toLong();

    // Pack low 48 bits of mantissa into bytes 0-5 (LE).
    buf.add((mantissa & 0xFF).toNumber());
    buf.add(((mantissa >> 8) & 0xFF).toNumber());
    buf.add(((mantissa >> 16) & 0xFF).toNumber());
    buf.add(((mantissa >> 24) & 0xFF).toNumber());
    buf.add(((mantissa >> 32) & 0xFF).toNumber());
    buf.add(((mantissa >> 40) & 0xFF).toNumber());
    // Byte 6: high 4 bits of mantissa | low 4 bits of biased exponent.
    var mantHi = ((mantissa >> 48) & 0x0F).toNumber();
    buf.add(mantHi | ((biasedExp & 0x0F) << 4));
    // Byte 7: sign | high 7 bits of biased exponent.
    buf.add((signBit << 7) | ((biasedExp >> 4) & 0x7F));
  }

  // Encode a tag (field number and wire type)
  function encodeTag(buf, fieldNum, wireType) {
    encodeVarint(buf, (fieldNum << 3) | wireType);
  }

  // Decode a length-delimited field (string or bytes)
  function decodeLengthDelimited(data, pos) {
    var lenResult = decodeVarint(data, pos);
    var len = lenResult[0];
    pos = lenResult[1];
    return [data.slice(pos, pos + len), pos + len];
  }

  // Encode a length-delimited field (string or bytes)
  function encodeLengthDelimited(buf, fieldNum, data) {
    encodeTag(buf, fieldNum, 2);
    if (data instanceof Toybox.Lang.String) {
      var strBytes = StringUtil.convertEncodedString(data, {:fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT, 
                                                            :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY});
      encodeVarint(buf, strBytes.size());
      buf.addAll(strBytes);
    } else {
      encodeVarint(buf, data.size());
      buf.addAll(data);
    }
  }

  // Convert string to byte array
  function stringToBytes(str) {
    return StringUtil.convertEncodedString(str, {:fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT, 
                                                  :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY});
  }

  // Convert byte array to string
  function bytesToString(bytes) {
    return StringUtil.convertEncodedString(bytes, {:fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
                                                    :toRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT});
  }
}