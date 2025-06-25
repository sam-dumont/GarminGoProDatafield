/* Parts of this file are direct copy or modifications of code originating from
https://github.com/chesapeaketechnology/BufMonkey

Licensed under Apache License
*/

using Toybox.Lang;
using Toybox.Application;
import Protobuf;

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
      // Use generated protobuf class to decode
      var notify = new NotifyPresetStatus();
      notify.Decode(data);
      // Populate presets and presetsIndexes from decoded data
      var presetGroups = notify.GetPresetGroupArray();
      for (var i = 0; i < presetGroups.size(); i++) {
        var group = presetGroups[i];
        var groupId = group.id.toNumber();
        presets.put(groupId, {});
        presetsIndexes.put(groupId, []);
        var presetArray = group.presetArray;
        for (var j = 0; j < presetArray.size(); j++) {
          var preset = presetArray[j];
          var presetId = preset.id.toNumber();
          presets.get(groupId).put(presetId, preset);
          presetsIndexes.get(groupId).add(presetId);
        }
      }
      parsed = true;
      data = null;
    }
  }
}
