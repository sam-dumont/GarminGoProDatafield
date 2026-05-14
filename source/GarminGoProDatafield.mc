import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Time;
using Toybox.Background;
using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Sensor;

var mainView;

class GarminGoProDatafieldApp extends Application.AppBase {
  var goproSensorDelegate;
  var gopro;
  var screenCoordinates;

  function initialize() {
    AppBase.initialize();
    // Do not instantiate GoProSensorDelegate here; handled by getSensorDelegate()
  }

  //! Get the sensor delegate for the app when pairing
  //! @return SensorDelegate The sensor delegate for the app
  public function getSensorDelegate() as $.Toybox.Sensor.SensorDelegate or Null {
    return new GoProSensorDelegate(gopro);
  }

  // onStart() is called on application start up
  function onStart(state as Dictionary?) as Void {
    AppBase.onStart(state);
  }

  // onStop() is called when your application is exiting
  function onStop(state as Dictionary?) as Void {
    gopro = null;
    goproSensorDelegate = null;
    screenCoordinates = null;
    AppBase.onStop(state);
  }

  // Return the initial view of your application here
  function getInitialView() as Array<Views or InputDelegates>? {
    Application.Storage.setValue("scanResult", null);

    if (Application.Storage.getValue("lastPresetGroupUploaded") == null) {
      Application.Storage.setValue("lastPresetGroupUploaded", false);
    }

    gopro = new GoPro(); // Use the BLE delegate from the sensor delegate
    screenCoordinates = new ScreenCoordinates();
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
  }
}
