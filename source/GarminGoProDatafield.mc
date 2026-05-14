import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Sensor;

var mainView;

class GarminGoProDatafieldApp extends Application.AppBase {
  var gopro;
  var screenCoordinates;

  function initialize() {
    AppBase.initialize();
  }

  // Activity-time BLE setup. The pairing-time setup happens inside the
  // SensorDelegate instance the framework creates separately for the
  // Sensors & Accessories flow — they do not share state.
  function onStart(state as Dictionary?) as Void {
    AppBase.onStart(state);
    gopro = new GoPro();
    // No onScanResultCallback / onConnectionCallback in the activity-time
    // instance — we don't scan and the connection event is handled
    // internally by GoPro itself.
    Ble.setDelegate(gopro);
    gopro.registerProfiles();

    // If we have a previously-paired GoPro, reconnect directly. No scan.
    var paired = Application.Storage.getValue(GoProSensorDelegate.PAIRED_SCAN_RESULT) as Ble.ScanResult?;
    if (paired != null) {
      Ble.pairDevice(paired);
    }
  }

  function onStop(state as Dictionary?) as Void {
    gopro = null;
    screenCoordinates = null;
    AppBase.onStop(state);
  }

  // Called by the framework from the Sensors & Accessories flow. Returns a
  // FRESH SensorDelegate each call — the system invokes this in a separate
  // app instance, so we cannot share `gopro` with it. The SensorDelegate
  // constructs its own internal GoPro BleDelegate for the pairing scan.
  public function getSensorDelegate() as Sensor.SensorDelegate or Null {
    return new GoProSensorDelegate();
  }

  function getInitialView() as Array<Views or InputDelegates>? {
    Application.Storage.setValue("scanResult", null);
    if (Application.Storage.getValue("lastPresetGroupUploaded") == null) {
      Application.Storage.setValue("lastPresetGroupUploaded", false);
    }

    screenCoordinates = new ScreenCoordinates();
    $.mainView = new MainView(gopro, screenCoordinates);

    return [
      $.mainView,
      new RecordingDelegate(gopro, screenCoordinates, $.mainView),
    ] as Array<Views or InputDelegates>;
  }

  function onSettingsChanged() {
    $.mainView.handleSettingsChanged();
  }
}
