// GoProSensorDelegate.mc
// Bridges the GoPro into the system Sensors & Accessories pairing UX.
// Pattern: NordicThingy52 SDK sample + SmartBikeLights for the storage bridge.
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
  private var _pairingBle as GoPro;
  private var _sensor as Sensor.SensorInfo?;
  private var _scanResult as Ble.ScanResult?;
  // BLE advertisements are noisy: onScanResults fires procScanResult for
  // every matching packet. Present exactly one sensor and ignore the rest
  // until the scan is restarted.
  private var _notified as Boolean = false;

  public function initialize() {
    SensorDelegate.initialize();
    _pairingBle = new GoPro();
    _pairingBle.onScanResultCallback = method(:procScanResult);
    _pairingBle.onConnectionCallback = method(:procConnection);
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
  public function onPair(sensor as Sensor.SensorInfo) as Boolean {
    var data = sensor.data;
    if (data == null) { return false; }
    var scanResult = data[:bleScanResult] as Ble.ScanResult?;
    if (scanResult == null) { return false; }
    if (Ble.pairDevice(scanResult) == null) { return false; }
    _sensor = sensor;
    _scanResult = scanResult;
    return true;
  }

  // Bridged from _pairingBle.onConnectedStateChanged on CONNECTED.
  public function procConnection(device as Ble.Device) as Void {
    if (_sensor != null && device != null) {
      Sensor.notifyPairComplete(_sensor);
      Application.Storage.setValue(PAIRED_SCAN_RESULT, _scanResult);
      _sensor = null;
      _scanResult = null; // single-shot — release once persisted
    }
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
    _sensor = null;
    _scanResult = null;
    return true;
  }
}
