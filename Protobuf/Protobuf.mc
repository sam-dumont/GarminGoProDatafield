import Toybox.Lang;
using Toybox.StringUtil;

module Protobuf {
    enum WireType {
        VARINT = 0,
        I64 = 1,
        LEN = 2,
        SGROUP = 3,
        EGROUP = 4,
        I32 = 5,
    }

    // ---- Append-style encoders (write in place, no intermediate ByteArrays) ----
    // Use these in generated Encode() functions instead of the old encodeField*
    // helpers, which allocated a fresh ByteArray per call.

    function appendVarint(target as ByteArray, v as Number or Long or Boolean) as Void {
        if (v instanceof Boolean) {
            v = v ? 1 : 0;
        }
        do {
            var b = (v & 0x7f).toNumber();
            v = v >> 7;
            // remove negative bit that replicates on shift
            v &= 0x01ffffffffffffffl;
            if (v > 0) {
                b |= (1<<7);
            }
            target.add(b);
        } while (v != 0);
    }

    function appendTag(target as ByteArray, f as Number, w as WireType) as Void {
        if (f > 0) {
            appendVarint(target, f << 3 | w);
        }
    }

    function appendFieldVarint(target as ByteArray, f as Number, v as Number or Long or Boolean, force as Boolean) as Void {
        if (!force) {
            if (v instanceof Boolean) {
                if (!v) { return; }
            } else {
                if (v == 0) { return; }
            }
        }
        appendTag(target, f, VARINT);
        appendVarint(target, v);
    }

    function appendField32(target as ByteArray, f as Number, v as Number or Float, force as Boolean) as Void {
        if (v == 0 && !force) { return; }
        appendTag(target, f, I32);
        var format = Lang.NUMBER_FORMAT_SINT32;
        if (v instanceof Float) {
            format = Lang.NUMBER_FORMAT_FLOAT;
        }
        var buf = new [4]b;
        buf.encodeNumber(v, format, {:endianness => Lang.ENDIAN_LITTLE});
        target.addAll(buf);
    }

    function appendField64(target as ByteArray, f as Number, v as Long, force as Boolean) as Void {
        if (v == 0 && !force) { return; }
        appendTag(target, f, I64);
        var buf = new [8]b;
        buf.encodeNumber(v&0xffffffff, Lang.NUMBER_FORMAT_SINT32, {:offset => 0, :endianness => Lang.ENDIAN_LITTLE});
        buf.encodeNumber(v>>32, Lang.NUMBER_FORMAT_SINT32, {:offset => 4, :endianness => Lang.ENDIAN_LITTLE});
        target.addAll(buf);
    }

    function appendFieldLen(target as ByteArray, f as Number, v as String or ByteArray, force as Boolean) as Void {
        if (v instanceof String) {
            v = StringUtil.convertEncodedString(v, {
                :fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
                :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
                :encoding => StringUtil.CHAR_ENCODING_UTF8,
            }) as ByteArray;
        }
        if (v.size() == 0 && !force) { return; }
        appendTag(target, f, LEN);
        appendVarint(target, v.size());
        target.addAll(v);
    }

    // ---- Legacy alloc-returning encoders ----
    // Kept for backward compat with any out-of-tree code; new generated
    // Encode functions should use the append* variants above.

    function encodeFieldVarint(f as Number, v as Number or Long or Boolean, force as Boolean) as ByteArray {
        var result = []b;
        appendFieldVarint(result, f, v, force);
        return result;
    }

    function encodeField32(f as Number, v as Number or Float, force as Boolean) as ByteArray {
        var result = []b;
        appendField32(result, f, v, force);
        return result;
    }

    function encodeField64(f as Number, v as Long, force as Boolean) as ByteArray {
        var result = []b;
        appendField64(result, f, v, force);
        return result;
    }

    function encodeFieldLen(f as Number, v as String or ByteArray, force as Boolean) as ByteArray {
        var result = []b;
        appendFieldLen(result, f, v, force);
        return result;
    }

    function encodeTag(f as Number, w as WireType) as ByteArray {
        var result = []b;
        appendTag(result, f, w);
        return result;
    }

    function encodeVarint(v as Number or Long or Boolean) as ByteArray {
        var result = []b;
        appendVarint(result, v);
        return result;
    }

    function toSignedInt(v as Number or Long) as Number or Long {
        if (v instanceof Number) {
            return (v << 1) ^ (v >> 31);
        } else {
            return (v << 1) ^ (v >> 63);
        }
    }

    function fromSignedNumber(v as Number) as Number {
        var result = v >> 1;
        if (v & 1 != 0) {
            result = ~result;
        }
        return result;
    }

    function fromSignedLong(v as Long) as Long {
        var result = v >> 1;
        if (v & 1 != 0) {
            result = ~result;
        }
        return result;
    }

    function assertWireType(tag as Number, wt as WireType) as Void {
        if ((tag & 7) != wt) {
            throw new Exception("invalid wire type");
        }
    }

    class Decoder {
        private var input as ByteArray;
        private var startIdx as Number;
        private var endIdx as Number;
        private var limitIdx as Number;

        public function initialize(inp as ByteArray) {
            input = inp;
            startIdx = -1;
            endIdx = 0;
            limitIdx = inp.size();
        }

        // Reconfigure to view a sub-range of the same underlying ByteArray.
        // Used by subDecoder() to allow zero-copy nested-message decoding.
        public function setRange(start as Number, limit as Number) as Void {
            startIdx = start - 1;
            endIdx = start;
            limitIdx = limit;
        }

        public function varint32() as Number {
            var result = 0;
            for (var off = 0; true; off += 7) {
                if (off >= 64) {
                    throw new Exception("varint32 too long");
                }
                consume(1);
                if (off < 32) {
                    result |= (input[startIdx] & 0x7f).toNumber() << off;
                }
                if (input[startIdx]&(1<<7) == 0) {
                    break;
                }
            }
            return result;
        }

        public function varint64() as Long {
            var result = 0l;
            for (var off = 0; true; off += 7) {
                if (off >= 64) {
                    throw new Exception("varint64 too long");
                }
                consume(1);
                result |= (input[startIdx] & 0x7f).toLong() << off;
                if (input[startIdx]&(1<<7) == 0) {
                    break;
                }
            }
            return result;
        }

        public function number() as Number {
            consume(4);
            return input.decodeNumber(Lang.NUMBER_FORMAT_SINT32, {:offset => startIdx, :endianness => Lang.ENDIAN_LITTLE}) as Number;
        }

        public function float() as Float {
            consume(4);
            return input.decodeNumber(Lang.NUMBER_FORMAT_FLOAT, {:offset => startIdx, :endianness => Lang.ENDIAN_LITTLE}) as Float;
        }

        public function long() as Long {
            consume(8);
            var lower = input.decodeNumber(Lang.NUMBER_FORMAT_SINT32, {:offset => startIdx, :endianness => Lang.ENDIAN_LITTLE});
            var upper = input.decodeNumber(Lang.NUMBER_FORMAT_SINT32, {:offset => startIdx+4, :endianness => Lang.ENDIAN_LITTLE});
            return (upper.toLong() << 32) | (lower.toLong() & 0xffffffffl) ;
        }

        // Returns a length-prefixed sub-range as a fresh ByteArray.
        // Prefer subDecoder() for nested message decoding (no allocation).
        public function data() as ByteArray {
            consume(varint32());
            return input.slice(startIdx, endIdx);
        }

        // Zero-copy sub-decoder over the same underlying ByteArray.
        // Returned Decoder is bounded by the next length-delimited field.
        public function subDecoder() as Decoder {
            var len = varint32();
            var subStart = endIdx;
            consume(len);
            var sub = new Decoder(input);
            sub.setRange(subStart, subStart + len);
            return sub;
        }

        public function string() as String {
            return StringUtil.convertEncodedString(data(), {
                :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
                :toRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
                :encoding => StringUtil.CHAR_ENCODING_UTF8,
            }) as String;
        }

        public function remaining() as Number {
            return limitIdx - endIdx;
        }

        // Kept as a no-op for compatibility with previously-generated pb.mc
        // files that call it; emits no output, no allocations.
        public function debugPosition(msg as String) as Void {
        }

        private function consume(l as Number) as Void {
            startIdx = endIdx;
            endIdx = startIdx + l;
            if (endIdx > limitIdx) {
                throw new Exception("decode out of range");
            }
        }
    }

    class Exception extends Lang.Exception {
        function initialize(msg as String) {
            Exception.initialize();
            mMessage = msg;
        }
    }
}
