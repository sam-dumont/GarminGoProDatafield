/* Parts of this file are direct copy or modifications of code originating from
https://github.com/chesapeaketechnology/BufMonkey

Licensed under Apache License
*/

/**
 * Most Significant Bit in a byte
 */
const MSB = 128;

/**
 * Maximum numerical value for an unsigned byte
 */
const MAX_BYTE_VALUE = 255;

/**
 * 0x0000111 byte value which is useful for grabbing Protobuf header info
 */
const LAST_THREE = 7;

/**
 * Infinity definition for floating point calculations
 */
const INFINITY = 0x7ff0000000000000l;

class PresetGroups {
  var data;
  var index = 0;
  var parsed = false;
  var presets = {};
  var presetsIndexes = {};

  hidden var binPresetData = [];
  hidden var currentPresetDataIndex = 0;
  hidden var currentPresetGroup = -1;
  hidden var presetGroupParserIndex = 0;
  hidden var currentlyParsing = false;

  function initialize(data) {
    self.data = data;
  }

  // due to watchdog limitations, we need to parse a few presets, one at a time
  function parse() {
    if (data != null) {
      parsed = false;
      currentPresetDataIndex = 0;
      currentPresetGroup = -1;
      binPresetData = [];
      index = 0;
      splitData();
    }
    if (!parsed && !currentlyParsing && binPresetData.size() > 0) {
      currentlyParsing = true;
      parsePresetGroup(currentPresetDataIndex);
      currentlyParsing = false;
      if (currentPresetDataIndex >= binPresetData.size()) {
        parsed = true;
      }
    }
  }

  function splitData() {
    var header;
    var length;

    while (index < data.size()) {
      header = parseProtoHeader(data[index]);
      if (header[0] == 2 && header[1] == 1) {
        length = parseUnsignedVarInt(data, index);
        binPresetData.add(data.slice(length[1] + 1, length[1] + 1 + length[0]));
        index = length[1] + 1 + length[0];
      }
    }
    data = null;
  }

  function parsePresetGroup(presetGroupIndex) {
    var header;
    var length;

    while (presetGroupParserIndex < binPresetData[presetGroupIndex].size()) {
      header = parseProtoHeader(
        binPresetData[presetGroupIndex][presetGroupParserIndex]
      );
      if (header[0] == 0 && header[1] == 1) {
        // groupID
        var groupId = parseUnsignedVarInt(
          binPresetData[presetGroupIndex],
          presetGroupParserIndex
        );
        presetGroupParserIndex = groupId[1] + 1;
        currentPresetGroup = groupId[0];
        presets.put(groupId[0].toNumber(), {});
        presetsIndexes.put(groupId[0].toNumber(), []);
      } else if (header[0] == 2 && header[1] == 2) {
        var preset = {
          "id" => 0,
          "flatMode" => 0,
          "title" => 0,
          "titleNumber" => 0,
          "icon" => 0,
          "userDefined" => false,
          "settings" => [],
          "isModified" => false,
          "isFixed" => false,
          "customName" => "",
        };
        // preset
        length = parseUnsignedVarInt(
          binPresetData[presetGroupIndex],
          presetGroupParserIndex
        );
        presetGroupParserIndex = length[1] + 1;
        var localEnd = presetGroupParserIndex + length[0];
        while (presetGroupParserIndex < localEnd) {
          var presetHeader = parseProtoHeader(
            binPresetData[presetGroupIndex][presetGroupParserIndex]
          );
          if (presetHeader[0] == 0) {
            var fieldData = parseUnsignedVarInt(
              binPresetData[presetGroupIndex],
              presetGroupParserIndex
            );
            if (presetHeader[1] == 1) {
              // id
              preset.put("id", fieldData[0]);
            } else if (presetHeader[1] == 2) {
              // id
              preset.put("flatMode", fieldData[0]);
            } else if (presetHeader[1] == 3) {
              // id
              preset.put("title", fieldData[0]);
            } else if (presetHeader[1] == 4) {
              // id
              preset.put("titleNumber", fieldData[0]);
            } else if (presetHeader[1] == 5) {
              // id
              preset.put("userDefined", fieldData[0] == 1);
            } else if (presetHeader[1] == 6) {
              // id
              preset.put("icon", fieldData[0]);
            } else if (presetHeader[1] == 8) {
              // id
              preset.put("isModified", fieldData[0] == 1);
            } else if (presetHeader[1] == 9) {
              // id
              preset.put("isFixed", fieldData[0] == 1);
            }
            presetGroupParserIndex = fieldData[1] + 1;
          } else if (presetHeader[0] == 2 && presetHeader[1] == 7) {
            length = parseUnsignedVarInt(
              binPresetData[presetGroupIndex],
              presetGroupParserIndex
            );
            var presetSetting = parsePresetSetting(
              length[1] + 1,
              length[1] + length[0],
              presetGroupIndex
            );
            preset["settings"].add(presetSetting[0]);
            presetGroupParserIndex = length[1] + 1 + length[0];
          }
        }
        if (preset.get("title") != null) {
          presets
            .get(currentPresetGroup)
            .put(preset.get("id").toNumber(), preset);
          presetsIndexes
            .get(currentPresetGroup)
            .add(preset.get("id").toNumber());
        }
      } else if (header[0] == 0 && header[1] != 1) {
        // other fields we ignore
        var fieldId = parseUnsignedVarInt(
          binPresetData[presetGroupIndex],
          presetGroupParserIndex
        );
        presetGroupParserIndex = fieldId[1] + 1;
      } else {
        // other fields we ignore
        var fieldId = parseUnsignedVarInt(
          binPresetData[presetGroupIndex],
          presetGroupParserIndex
        );
        presetGroupParserIndex = fieldId[1] + 1;
      }
    }
    presetGroupParserIndex = 0;
    currentPresetDataIndex++;
  }

  function parsePresetSetting(start, end, presetGroupIndex) {
    var localIdx = start;
    var header;

    var presetSetting = {
      "id" => -1,
      "value" => -1,
      "is_caption" => false,
    };

    while (localIdx < end) {
      header = parseProtoHeader(binPresetData[presetGroupIndex][localIdx]);
      var field = parseUnsignedVarInt(
        binPresetData[presetGroupIndex],
        localIdx
      );

      if (header[0] == 0 && header[1] == 1) {
        presetSetting.put("id", field[0]);
      } else if (header[0] == 0 && header[1] == 2) {
        presetSetting.put("value", field[0]);
      } else if (header[0] == 0 && header[1] == 3) {
        presetSetting.put("is_caption", field[0] == 1);
      }
      localIdx = field[1] + 1;
    }

    return [presetSetting, localIdx];
  }

  function parseUnsignedVarInt(buf, idx) {
    var shifter = 0;
    var val = 0;
    do {
      idx++;
      val |= (buf[idx] & 0x7f) << shifter;
      shifter += 7;
    } while (buf[idx] & 0x80);

    return [val.toNumber(), idx];
  }

  function parseProtoHeader(byte) {
    if (byte != null) {
      if (byte > MSB - 1) {
        var strippedFirst = byte ^ MSB;
        byte = strippedFirst;
      }

      var wireType = byte & LAST_THREE;
      var fieldNum = byte >> 3;

      return [wireType, fieldNum];
    }

    return null;
  }
}
