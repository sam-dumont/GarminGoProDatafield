import Toybox.Application;
using Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

(:background)
class BgServiceDelegate extends System.ServiceDelegate {
  function initialize() {
    System.ServiceDelegate.initialize();
  }

  // callback function
  function onReceive(
    responseCode as Number,
    data as Dictionary or String or Null
  ) as Void {
    if (data == null || data instanceof String) {
      data = {};
    } else if (data["types"] != null) {
      if (data["types"].indexOf("profiles") != -1) {
        Application.Storage.setValue("lastPresetGroupUploaded", true);
      }
    }
    data["responseCode"] = responseCode;
    Background.exit(data);
  }

  function onTemporalEvent() {
    // Only keep profile upload if needed in the future
  }
}
