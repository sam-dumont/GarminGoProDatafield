/* Parts of this file are direct copy or modifications of code originating from
https://github.com/chesapeaketechnology/BufMonkey

Licensed under Apache License
*/

using Toybox.Lang;
using Toybox.Application;
using OpenGopro;
import ProtobufLib;

class PresetGroups {
  var data as Lang.ByteArray?;
  var parsed as Lang.Boolean = false;
  // presets: groupId (Number) → (presetId (Number) → Preset)
  var presets as Lang.Dictionary<Lang.Number, Lang.Dictionary<Lang.Number, OpenGopro.Preset>> = {};
  // presetsIndexes: groupId (Number) → ordered list of preset IDs
  var presetsIndexes as Lang.Dictionary<Lang.Number, Lang.Array<Lang.Number>> = {};

  function initialize(data as Lang.ByteArray?) {
    self.data = data;
  }

  function parse() as Void {
    var d = data;
    if (d != null && !parsed) {
      // The generated NotifyPresetStatus.decode accepts a raw ByteArray
      // (it constructs an internal ProtobufLib.Decoder). Nested message
      // decoding then uses subDecoder() for zero-copy traversal.
      var notify = new OpenGopro.NotifyPresetStatus();
      notify.decode(d);
      var presetGroups = notify.getPresetGroupArray();
      for (var i = 0; i < presetGroups.size(); i++) {
        var group = presetGroups[i];
        var groupId = group.getId().toNumber();
        presets.put(groupId, {});
        presetsIndexes.put(groupId, []);
        var presetArray = group.getPresetArray();
        var presetMap = presets[groupId] as Lang.Dictionary<Lang.Number, OpenGopro.Preset>;
        var idxList = presetsIndexes[groupId] as Lang.Array<Lang.Number>;
        for (var j = 0; j < presetArray.size(); j++) {
          var preset = presetArray[j];
          var presetId = preset.getId().toNumber();
          presetMap.put(presetId, preset);
          idxList.add(presetId);
        }
      }
      parsed = true;
      data = null;
    }
  }
}
