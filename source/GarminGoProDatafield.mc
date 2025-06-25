import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Time;
using Toybox.Background;
using Toybox.BluetoothLowEnergy as Ble;

var mainView;

class GarminGoProDatafieldApp extends Application.AppBase {
  var gopro;
  var screenCoordinates;

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
    gopro = null;
    screenCoordinates = null;
    AppBase.onStop(state);
  }

  // Return the initial view of your application here
  function getInitialView() as Array<Views or InputDelegates>? {
    Application.Storage.setValue("scanResult", null);

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
      [
        $.mainView,
        new RecordingDelegate(gopro, screenCoordinates, $.mainView),
      ] as Array<Views or InputDelegates>
    );
  }

  function onSettingsChanged() {
    $.mainView.handleSettingsChanged();
    WatchUi.requestUpdate();
  }
}
