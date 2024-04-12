// vim: syntax=c

using Toybox.System;
using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Application;

class GoPro extends Ble.BleDelegate {
  const DEVICE_NAME = "GoPro Cam";
  const CONTROL_AND_QUERY_SERVICE = Ble.stringToUuid(
    "0000fea6-0000-1000-8000-00805f9b34fb"
  );
  const COMMAND_CHAR = Ble.stringToUuid("B5F90072-aa8d-11e3-9046-0002a5d5c51b");
  const COMMAND_NOTIFICATION = Ble.stringToUuid(
    "B5F90073-aa8d-11e3-9046-0002a5d5c51b"
  );
  const SETTINGS_CHAR = Ble.stringToUuid(
    "B5F90074-aa8d-11e3-9046-0002a5d5c51b"
  );
  const SETTINGS_NOTIFICATION = Ble.stringToUuid(
    "B5F90075-aa8d-11e3-9046-0002a5d5c51b"
  );
  const QUERY_CHAR = Ble.stringToUuid("B5F90076-aa8d-11e3-9046-0002a5d5c51b");
  const QUERY_NOTIFICATION = Ble.stringToUuid(
    "B5F90077-aa8d-11e3-9046-0002a5d5c51b"
  );
  const CONTROL_AND_QUERY_DESC = Ble.cccdUuid();

  enum {
    COMMAND_START_REC = 0,
    COMMAND_STOP_REC = 1,
  }

  enum {
    MODE_VIDEO = 0,
    MODE_PHOTO = 1,
    MODE_TIMELAPSE = 2,
  }

  enum {
    STATUS_SEARCHING = 0,
    STATUS_CONNECTING = 1,
    STATUS_CONNECTED = 2,
  }

  const COMMANDS = [
    [0x03, 0x01, 0x01, 0x01]b,
    [0x03, 0x01, 0x01, 0x00]b,
  ];

  var scanning = false;
  var device = null;
  var cameraID = Application.Properties.getValue("gopro_id");
  var connectionStatus = STATUS_SEARCHING;
  var batteryLife = 100;
  var remainingTime = 3600;
  var mode = GoPro.MODE_TIMELAPSE;
  var modeName = "Standard";
  var recordingDuration = 0;
  var recording = false;
  var settings = "4K | 30 | L+";
  var logs = ["", "", ""];

  function debug(str) {
    System.println("[ble] " + str);
    logs.add(str);
    logs = logs.slice(1, null);
  }

  function initialize() {
    BleDelegate.initialize();
    debug("initialize");
  }

  function sendCommand(command) {
    var service;
    var ch;

    if (device == null) {
      debug("sendCommand: not connected");
      return;
    }

    debug("sendCommand " + COMMANDS[command] + "now !");
    service = device.getService(CONTROL_AND_QUERY_SERVICE);
    ch = service.getCharacteristic(COMMAND_CHAR);
    try {
      ch.requestWrite(COMMANDS[command], {
        :writeType => Ble.WRITE_TYPE_DEFAULT,
      });
    } catch (ex) {
      debug("can't send command " + COMMANDS[command]);
    }
  }

  function onCharacteristicWrite(ch, value) {
    debug("char write " + ch.getUuid() + " " + value);
  }

  function onCharacteristicChanged(ch, value) {
    debug("char changed " + ch.getUuid() + " " + value);
  }

  function onDescriptorWrite(desc, value) {
    debug("descriptor write " + desc.getUuid() + " " + value);
    if (desc.getUuid().equals(COMMAND_NOTIFICATION)) {
      debug("enabling notifications for QUERY");
      enableNotifications(QUERY_NOTIFICATION);
    } else if (desc.getUuid().equals(QUERY_NOTIFICATION)) {
      debug("enabling notifications for SETTINGS");
      enableNotifications(SETTINGS_NOTIFICATION);
    } else if (desc.getUuid().equals(SETTINGS_NOTIFICATION)) {
      debug("all notifications enabled");
      connectionStatus = STATUS_CONNECTED;
    }
  }

  function enableNotifications(characteristic) {
    var service;
    var command;
    var desc;

    if (device == null) {
      debug("setNotifications: not connected");
      return;
    }
    debug("setNotifications");

    service = device.getService(CONTROL_AND_QUERY_SERVICE);

    command = service.getCharacteristic(characteristic);
    desc = command.getDescriptor(CONTROL_AND_QUERY_DESC);
    desc.requestWrite([0x01, 0x00]b);
    debug("Notifications requested for " + characteristic);
  }

  function onProfileRegister(uuid, status) {
    debug("registered: " + uuid + " " + status);
  }

  function registerProfiles() {
    var profile = {
      :uuid => CONTROL_AND_QUERY_SERVICE,
      :characteristics => [
        {
          :uuid => COMMAND_NOTIFICATION,
          :descriptors => [CONTROL_AND_QUERY_DESC],
        },
        {
          :uuid => COMMAND_CHAR,
        },
        {
          :uuid => SETTINGS_NOTIFICATION,
          :descriptors => [CONTROL_AND_QUERY_DESC],
        },
        {
          :uuid => SETTINGS_CHAR,
        },
        {
          :uuid => QUERY_NOTIFICATION,
          :descriptors => [CONTROL_AND_QUERY_DESC],
        },
        {
          :uuid => QUERY_CHAR,
        },
      ],
    };

    BluetoothLowEnergy.registerProfile(profile);
  }

  function onScanStateChange(scanState, status) {
    debug("scanstate: " + scanState + " " + status);
    if (scanState == Ble.SCAN_STATE_SCANNING) {
      scanning = true;
    } else {
      scanning = false;
    }
  }

  function onEncryptionStatus(device, status) {
    debug("encryption status: " + device.getName() + " " + status);
    if (status == Ble.STATUS_SUCCESS) {
      Application.Storage.setValue("paired", true);
      enableNotifications(COMMAND_NOTIFICATION);
    }
  }

  function onConnectedStateChanged(device, state) {
    debug("connected: " + device.getName() + " " + state);
    if (state == Ble.CONNECTION_STATE_CONNECTED) {
      self.device = device;
      self.device.requestBond();
    } else {
      self.device = null;
    }
  }

  private function connect(result) {
    debug("connect");
    Ble.setScanState(Ble.SCAN_STATE_OFF);
    var ld = Ble.pairDevice(result);
    return ld;
  }

  private function dumpUuids(iter) {
    for (var x = iter.next(); x != null; x = iter.next()) {}
  }

  private function dumpMfg(iter) {
    for (var x = iter.next(); x != null; x = iter.next()) {
      debug("mfg: companyId: " + x.get(:companyId) + " data: " + x.get(:data));
    }
  }

  function onScanResults(scanResults) {
    debug("scan results");
    var appearance, name, rssi;
    var mfg, uuids, service;
    for (
      var result = scanResults.next();
      result != null;
      result = scanResults.next()
    ) {
      appearance = result.getAppearance();
      name = result.getDeviceName();
      rssi = result.getRssi();
      mfg = result.getManufacturerSpecificDataIterator();
      uuids = result.getServiceUuids();

      /*debug(
        "device: appearance: " +
          appearance +
          " name: " +
          name +
          " rssi: " +
          rssi
      );
      dumpMfg(mfg);
      debug(" ");*/

      for (var x = uuids.next(); x != null; x = uuids.next()) {
        if (x.equals(CONTROL_AND_QUERY_SERVICE)) {
          debug("found matching device. uuid: " + x);
          if (
            Application.Storage.getValue("paired") != null &&
            Application.Storage.getValue("paired")
          ) {
            if (name.equals("GoPro " + cameraID.toString())) {
              debug("connecting to camera with id:" + cameraID.toString());
              connectionStatus = STATUS_CONNECTING;
              connect(result);
              return;
            }
          } else {
            debug("pairing camera for the first time");
            connectionStatus = STATUS_CONNECTING;
            connect(result);
            return;
          }
        }
      }
    }
  }

  function open() {
    registerProfiles();
    Ble.setScanState(Ble.SCAN_STATE_SCANNING);
    connectionStatus = STATUS_SEARCHING;
  }

  function close() {
    debug("close");
    if (scanning) {
      Ble.setScanState(Ble.SCAN_STATE_OFF);
    }
    if (device) {
      Ble.unpairDevice(device);
    }
  }
}
