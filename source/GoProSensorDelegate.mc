// GoProSensorDelegate.mc
// Refactored BLE connection using Garmin SensorDelegate
// See migration plan for details

using Toybox.BluetoothLowEnergy as Ble;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Sensor;

// This class manages GoPro BLE as a system sensor
class GoProSensorDelegate extends Sensor.SensorDelegate {
    private var _bleDelegate as GoPro; // Your BLE handler (extends Ble.BleDelegate)
    private var _sensor as Sensor.SensorInfo?;
    private var _scanResult as Ble.ScanResult?;

    // Constructor
    public function initialize(gopro as GoPro) {
        SensorDelegate.initialize();
        _bleDelegate = gopro;
        Ble.setDelegate(_bleDelegate);
    }

    // Called when the system wants to scan for sensors
    public function onScan() as Boolean {
        // If already paired, skip scan
        if (Application.Storage.getValue("paired")) {
            return false;
        }
        Ble.setScanState(Ble.SCAN_STATE_SCANNING);
        return true;
    }

    // Called when a BLE scan result is found
    public function procScanResult(scanResult as Ble.ScanResult) as Void {
        var name = scanResult.getDeviceName();
        if (name == null) { name = "Unknown Device"; }
        var sensor = new Sensor.SensorInfo();
        sensor.name = name;
        sensor.technology = Sensor.SENSOR_TECHNOLOGY_BLE;
        sensor.type = Sensor.SENSOR_GENERIC;
        sensor.data = {:bleScanResult => scanResult};
        sensor.partNumber = 0;
        sensor.manufacturerId = 0;
        Sensor.notifyNewSensor(sensor, true);
        Sensor.notifyScanComplete();
        Ble.setScanState(Ble.SCAN_STATE_OFF);
    }

    // Called when the system wants to pair with a sensor
    public function onPair(sensor as Sensor.SensorInfo) as Boolean {
        var pairing = false;
        var data = sensor.data;
        if (data != null) {
            var scanResult = data[:bleScanResult] as Ble.ScanResult?;
            if (scanResult != null) {
                if (Ble.pairDevice(scanResult) != null) {
                    pairing = true;
                    _sensor = sensor;
                    _scanResult = scanResult;
                }
            }
        }
        return pairing;
    }

    // Called when a connection is established after pairing
    public function procConnection(device as Ble.Device) as Void {
        if (_sensor != null) {
            Sensor.notifyPairComplete(_sensor);
            Application.Storage.setValue("paired", true);
        }
    }

    // Called when the system wants to unpair
    public function onUnpair(sensor as Sensor.SensorInfo) as Boolean {
        var unpaired = false;
        var data = sensor.data;
        if (data != null) {
            var scanResult = data[:bleScanResult] as Ble.ScanResult?;
            if (scanResult != null) {
                var paired = Application.Storage.getValue("paired");
                if (paired) {
                    unpaired = true;
                    Sensor.notifyUnpairComplete(sensor);
                    Application.Storage.deleteValue("paired");
                    _sensor = null;
                    _scanResult = null;
                }
            }
        }
        return unpaired;
    }

    public function getBleDelegate() as GoPro {
        return _bleDelegate;
    }
}
