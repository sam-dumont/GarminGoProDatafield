import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Sensor;

var mainView as MainView?;

class GarminGoProDatafieldApp extends Application.AppBase {
  var gopro as GoPro?;
  var screenCoordinates as ScreenCoordinates?;

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
    var paired = Application.Storage.getValue($.PAIRED_SCAN_RESULT) as Ble.ScanResult?;
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

  function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
    if (Application.Storage.getValue("lastPresetGroupUploaded") == null) {
      Application.Storage.setValue("lastPresetGroupUploaded", false);
    }

    // gopro / screenCoordinates are guaranteed non-null here by onStart()
    // and getInitialView()'s assignment above, respectively. Cast away
    // the nullable types for the strict checker.
    var g = gopro as GoPro;
    screenCoordinates = new ScreenCoordinates();
    var sc = screenCoordinates as ScreenCoordinates;
    var mv = new MainView(g, sc);
    $.mainView = mv;

    return [mv, new RecordingDelegate(g, sc, mv)];
  }

  function onSettingsChanged() as Void {
    var mv = $.mainView;
    if (mv != null) {
      mv.handleSettingsChanged();
    }
  }
}
