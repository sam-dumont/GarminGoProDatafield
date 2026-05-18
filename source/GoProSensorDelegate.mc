// GoProSensorDelegate.mc
// DISCOVERY-ONLY shim for the system Sensors & Accessories pairing UX.
//
// The GoPro has a NON-STANDARD BLE bond: the central must explicitly drive
// requestBond() and re-enable the COMMAND/QUERY/SETTINGS notification
// descriptors, in order, on every connection. Garmin's native pairing
// model (see the NordicThingy52 SDK sample) assumes the SYSTEM performs
// the bond — true for standard sensors, false for the GoPro. Trying to
// complete the GoPro handshake inside the native pairing flow makes the
// camera connect, wait for a bond that never comes the way it expects,
// then drop the link.
//
// So this delegate does discovery ONLY: scan, present the sensor, and on
// pair persist the ScanResult + report complete. The real connection
// (pairDevice + requestBond + notification chain) is driven entirely by
// the activity-time GoPro BleDelegate in App.onStart — the exact manual
// sequence that worked pre-migration.
//
// IMPORTANT: this delegate runs in a different app instance than the main
// datafield's GoPro BleDelegate. The only state bridge is Application.Storage.

using Toybox.BluetoothLowEnergy as Ble;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Sensor;

// Storage key for the persisted ScanResult of a previously-paired GoPro.
// Module-level (not class-level) so it can be read from App.onStart without
// requiring a SensorDelegate instance — they live in different app contexts.
const PAIRED_SCAN_RESULT = "paired_scan_result";

class GoProSensorDelegate extends Sensor.SensorDelegate {
  // Our own BLE delegate, used only during the pairing-flow scan. It is
  // separate from the GoPro BleDelegate the main App.onStart constructs.
  // BLE delegate used ONLY for the discovery scan. It never drives a
  // connection — onPair hands off to the activity-time delegate.
  private var _pairingBle as GoPro;
  // BLE advertisements are noisy: onScanResults fires procScanResult for
  // every matching packet. Present exactly one sensor and ignore the rest
  // until the scan is restarted.
  private var _notified as Boolean = false;

  public function initialize() {
    SensorDelegate.initialize();
    _pairingBle = new GoPro();
    _pairingBle.onScanResultCallback = method(:procScanResult);
    _pairingBle.registerProfiles();
    Ble.setDelegate(_pairingBle);
  }

  // Always return true. Edge 1040 firmware has a known bug where returning
  // false causes the device to reboot — see SmartBikeLights source comment.
  public function pairingRequired() as Boolean {
    return true;
  }

  // System asks us to start scanning. Return true if we kicked off a scan.
  public function onScan() as Boolean {
    if (Application.Storage.getValue(PAIRED_SCAN_RESULT) != null) {
      // Already paired — don't show the scanning UI.
      return false;
    }
    _notified = false;
    Ble.setScanState(Ble.SCAN_STATE_SCANNING);
    return true;
  }

  // Called from _pairingBle.onScanResults for each scan hit matching the
  // GoPro service UUID (filtering happens in GoPro.onScanResults).
  public function procScanResult(scanResult as Ble.ScanResult) as Void {
    if (_notified) { return; }
    _notified = true;

    var name = scanResult.getDeviceName();
    if (name == null) { name = "GoPro Cam"; }

    var sensor = new Sensor.SensorInfo();
    sensor.name = name;
    sensor.technology = Sensor.SENSOR_TECHNOLOGY_BLE;
    sensor.type = Sensor.SENSOR_GENERIC;
    sensor.data = { :bleScanResult => scanResult };
    sensor.partNumber = 0;
    sensor.manufacturerId = 0;

    Sensor.notifyNewSensor(sensor, true);
    Sensor.notifyScanComplete();
    Ble.setScanState(Ble.SCAN_STATE_OFF);
  }

  // System asks us to pair the user-selected sensor.
  //
  // Discovery-only: we do NOT call Ble.pairDevice here. Attempting the
  // GoPro bond inside the native pairing flow is exactly what fails
  // ("boom disappear"). Instead persist the ScanResult and report the
  // pair complete immediately. The activity-time GoPro delegate does the
  // real connect + requestBond + notification chain on the next activity.
  public function onPair(sensor as Sensor.SensorInfo) as Boolean {
    var data = sensor.data;
    if (data == null) { return false; }
    var scanResult = data[:bleScanResult] as Ble.ScanResult?;
    if (scanResult == null) { return false; }

    Application.Storage.setValue(PAIRED_SCAN_RESULT, scanResult);
    Sensor.notifyPairComplete(sensor);
    Ble.setScanState(Ble.SCAN_STATE_OFF);
    return true;
  }

  // System asks us to unpair. Compare via isSameDevice on the stored ScanResult.
  public function onUnpair(sensor as Sensor.SensorInfo) as Boolean {
    var data = sensor.data;
    if (data == null) { return false; }
    var scanResult = data[:bleScanResult] as Ble.ScanResult?;
    if (scanResult == null) { return false; }

    var paired = Application.Storage.getValue(PAIRED_SCAN_RESULT) as Ble.ScanResult?;
    if (paired == null || !paired.isSameDevice(scanResult)) { return false; }

    Sensor.notifyUnpairComplete(sensor);
    Application.Storage.deleteValue(PAIRED_SCAN_RESULT);
    return true;
  }
}
