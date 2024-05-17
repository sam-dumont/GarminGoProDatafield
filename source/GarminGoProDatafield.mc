import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Time;
using Toybox.Background;
using Toybox.BluetoothLowEnergy as Ble;

var mainView;

class GarminGoProDatafieldApp extends Application.AppBase {
  hidden var gopro;
  hidden var screenCoordinates;

  function initialize() {
    AppBase.initialize();
  }

  // onStart() is called on application start up
  function onStart(state as Dictionary?) as Void {
    AppBase.onStart(state);
  }

  // onStop() is called when your application is exiting
  function onStop(state as Dictionary?) as Void {
    if (gopro != null && gopro.device != null) {
      gopro.close();
    }
    AppBase.onStop(state);
  }

  // Return the initial view of your application here
  function getInitialView() as Array<Views or InputDelegates>? {
    regTempEvent();
    Application.Storage.setValue(
      "storedLogs",
      Util.replaceNull(Application.Storage.getValue("logs"), [])
    );
    Application.Storage.setValue("logsUploaded", false);
    Application.Storage.setValue("logs", []);

    if (Application.Storage.getValue("lastPresetGroupUploaded") == null) {
      Application.Storage.setValue("lastPresetGroupUploaded", false);
    }

    if (Application.Storage.getValue("paired") == null) {
      Application.Storage.setValue("paired", false);
    }

    gopro = new GoPro();
    screenCoordinates = new ScreenCoordinates();
    Ble.setDelegate(gopro);
    gopro.open();
    $.mainView = new MainView(gopro, screenCoordinates);

    return (
      [$.mainView, new RecordingDelegate(gopro, screenCoordinates)] as
      Array<Views or InputDelegates>
    );
  }

  function onBackgroundData(dataIn as PersistableType) {
    var data = dataIn as Dictionary;
    System.println(data);
    if (data["responseCode"] == 200) {
      if (data["types"].indexOf("logs") != -1) {
        Application.Storage.setValue("logsUploaded", true);
      }
      if (data["types"].indexOf("profiles") != -1) {
        Application.Storage.setValue("lastPresetGroupUploaded", true);
      }
    }
  }

  function onSettingsChanged() {
    $.mainView.handleSettingsChanged();
    WatchUi.requestUpdate();
  }

  function getServiceDelegate() {
    return [new BgServiceDelegate()];
  }

  function getSettingsView() {
    return [new SettingsMenu(), new SettingsMenuDelegate()];
  }
}

function regTempEvent() {
  var minutes = 5;

  var time = new Time.Duration(minutes * 60);

  if (Toybox.System has :ServiceDelegate) {
    Background.registerForTemporalEvent(time);
  }
}
