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

    function encodeFieldVarint(f as Number, v as Number or Long or Boolean, force as Boolean) as ByteArray {
        if (!force) {
            if (v instanceof Boolean) {
                if (!v) {
                    return []b;
                }
            } else {
                if (v == 0) {
                    return []b;
                }
            }
        }
        var result = []b;
        result.addAll(encodeTag(f, VARINT));
        result.addAll(encodeVarint(v));
        return result;
    }

    function encodeField32(f as Number, v as Number or Float, force as Boolean) as ByteArray {
        if (v == 0 && !force) {
            return []b;
        }
        var result = []b;
        result.addAll(encodeTag(f, I32));
        var format = Lang.NUMBER_FORMAT_SINT32;
        if (v instanceof Float) {
            format = Lang.NUMBER_FORMAT_FLOAT;
        }
        result.addAll((new [4]b).encodeNumber(v, format, {:endianness => Lang.ENDIAN_LITTLE}));
        return result;
    }

    function encodeField64(f as Number, v as Long, force as Boolean) as ByteArray {
        if (v == 0 && !force) {
            return []b;
        }
        var result = []b;
        result.addAll(encodeTag(f, I64));
        result.addAll((new [4]b).encodeNumber(v&0xffffffff, Lang.NUMBER_FORMAT_SINT32, {:endianness => Lang.ENDIAN_LITTLE}));
        result.addAll((new [4]b).encodeNumber(v>>32, Lang.NUMBER_FORMAT_SINT32, {:endianness => Lang.ENDIAN_LITTLE}));
        return result;
    }

    function encodeFieldLen(f as Number, v as String or ByteArray, force as Boolean) as ByteArray {
        if (v instanceof String) {
            v = StringUtil.convertEncodedString(v, {
                :fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
                :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
                :encoding => StringUtil.CHAR_ENCODING_UTF8,
            }) as ByteArray;
        }
        if (v.size() == 0 && !force) {
            return []b;
        }
        var result = []b;
        result.addAll(encodeTag(f, LEN));
        result.addAll(encodeVarint(v.size()));
        result.addAll(v);
        return result;
    }

    function encodeTag(f as Number, w as WireType) as ByteArray {
        if (f <= 0) {
            return []b;
        }
        return encodeVarint(f << 3 | w);
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

    function encodeVarint(v as Number or Long or Boolean) as ByteArray {
        if (v instanceof Boolean) {
            v = v ? 1 : 0;
        }
        var result = []b;
        do {
            var b = (v & 0x7f).toNumber();
            v = v >> 7;
            // remove negative bit that replicates on shift
            v &= 0x01ffffffffffffffl;
            if (v > 0) {
                b |= (1<<7);
            }
            result.add(b);
        } while (v != 0);
        return result;
    }

    function assertWireType(tag as Number, wt as WireType) as Void {
        if (((tag & 7) as WireType) != wt) {
            throw new Exception("invalid wire type");
        }
    }

    class Decoder {
        private var input as ByteArray;
        private var startIdx as Number;
        private var endIdx as Number;

        public function initialize(inp as ByteArray) {
            input = inp;
            startIdx = -1;
            endIdx = 0;
        }

        public function varint32() as Number {
            var result = 0;
            for (var off = 0; true; off += 7) {
                // negative numbers are always 64 bits, so that length is permitted
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

        public function data() as ByteArray {
            consume(varint32());
            return input.slice(startIdx, endIdx);
        }

        public function string() as String {
            return StringUtil.convertEncodedString(data(), {
                :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
                :toRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
                :encoding => StringUtil.CHAR_ENCODING_UTF8,
            }) as String;
        }

        public function remaining() as Number {
            return input.size() - endIdx;
        }

        private function consume(l as Number) as Void {
            startIdx = endIdx;
            endIdx = startIdx + l;
            if (endIdx > input.size()) {
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
