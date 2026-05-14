/* Parts of this file are direct copy or modifications of code originating from
https://github.com/chesapeaketechnology/BufMonkey

Licensed under Apache License
*/

using Toybox.Lang;
using Toybox.Application;
using OpenGopro;
import ProtobufLib;

class PresetGroups {
  var data;
  var parsed = false;
  var presets = {};
  var presetsIndexes = {};

  function initialize(data) {
    self.data = data;
  }

  function parse() {
    if (data != null && !parsed) {
      // The generated NotifyPresetStatus.decode accepts a raw ByteArray
      // (it constructs an internal ProtobufLib.Decoder). Nested message
      // decoding then uses subDecoder() for zero-copy traversal.
      var notify = new OpenGopro.NotifyPresetStatus();
      notify.decode(data);
      var presetGroups = notify.getPresetGroupArray();
      for (var i = 0; i < presetGroups.size(); i++) {
        var group = presetGroups[i];
        var groupId = group.getId().toNumber();
        presets.put(groupId, {});
        presetsIndexes.put(groupId, []);
        var presetArray = group.getPresetArray();
        for (var j = 0; j < presetArray.size(); j++) {
          var preset = presetArray[j];
          var presetId = preset.getId().toNumber();
          presets.get(groupId).put(presetId, preset);
          presetsIndexes.get(groupId).add(presetId);
        }
      }
      parsed = true;
      data = null;
    }
  }
}
