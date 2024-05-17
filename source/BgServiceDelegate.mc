import Toybox.Application;
using Toybox.Background;
import Toybox.Communications;
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
      if (data["types"].indexOf("logs") != -1) {
        Application.Storage.setValue("logsUploaded", true);
      }
      if (data["types"].indexOf("profiles") != -1) {
        Application.Storage.setValue("lastPresetGroupUploaded", true);
      }
    }
    data["responseCode"] = responseCode;

    Background.exit(data);
  }

  function makeRequest() {
    if (Communications has :makeWebRequest) {
      var data;
      var upload = false;

      var mySettings = System.getDeviceSettings();
      var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

      var params = {
        "version" => Lang.format("$1$.$2$.$3$", mySettings.monkeyVersion),
        "partNumber" => mySettings.partNumber,
        "uniqueIdentifier" => mySettings.uniqueIdentifier,
        "timestamp" => Lang.format("$1$$2$$3$T$4$$5$$6$", [
          now.year,
          now.month.format("%02d"),
          now.day.format("%02d"),
          now.hour.format("%02d"),
          now.min.format("%02d"),
          now.sec.format("%02d"),
        ]),
      };

      if (
        Application.Storage.getValue("lastPresetGroupUploaded") != null &&
        !Application.Storage.getValue("lastPresetGroupUploaded")
      ) {
        data = Application.Storage.getValue("lastPresetGroupResult");
        if (data != null) {
          upload = true;
          params.put("profilesData", data);
        }
      }
      if (
        Application.Storage.getValue("logsUploaded") != null &&
        !Application.Storage.getValue("logsUploaded")
      ) {
        data = Application.Storage.getValue("storedLogs");
        if (data != null) {
          upload = true;
          params.put("logs", data);
        }
      }

      if (!upload) {
        return;
      }

      var apiKey = Application.Properties.getValue("api_key");
      var apiEndpoint = Lang.format("$1$$2$", [
        Application.Properties.getValue("api_endpoint"),
        "full",
      ]);

      Communications.makeWebRequest(
        apiEndpoint,
        params,
        {
          :headers => {
            "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
            "x-api-key" => apiKey,
          },
          :method => Communications.HTTP_REQUEST_METHOD_POST,
          :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
        },
        method(:onReceive)
      );
    }
  }

  function onTemporalEvent() {
    if (
      Application.Properties.getValue("send_logs") != null &&
      Application.Properties.getValue("send_logs")
    ) {
      makeRequest();
    }
  }
}
