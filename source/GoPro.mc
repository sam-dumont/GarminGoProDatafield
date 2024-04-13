// vim: syntax=c

using Toybox.System;
using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Application;
using Toybox.Lang;

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

  const CONT_MASK = 0x80;
  const HDR_MASK = 0x60;
  const GEN_LEN_MASK = 0x1f;
  const EXT_13_BYTE0_MASK = 0x1f;
  const GENERAL = 0x00;
  const EXT_13 = 0x01;
  const EXT_16 = 0x10;
  const RESERVED = 0x11;

  const RESPONSE_TYPE_STATUS = 0x53;
  const RESPONSE_TYPE_SETTING = 0x52;
  const NOTIFICATION_TYPE_STATUS = 0x93;
  const NOTIFICATION_TYPE_SETTING = 0x92;

  enum {
    COMMAND_START_REC = 0,
    COMMAND_STOP_REC = 1,
  }

  enum {
    MODE_VIDEO = 1000,
    MODE_PHOTO = 1001,
    MODE_TIMELAPSE = 1002,
  }

  enum {
    STATUS_SEARCHING = 0,
    STATUS_CONNECTING = 1,
    STATUS_CONNECTED = 2,
  }

  const STATUS_RES = 0x02;
  const STATUS_FPS = 0x03;
  const STATUS_FOV = 0x2b;
  const STATUS_RECORDING = 0xa;
  const STATUS_DURATION = 0xd;
  const STATUS_REM_PHOTOS = 0x22;
  const STATUS_REM_VIDEOS = 0x23;
  const STATUS_REM_TIMELAPSE = 0x40;
  const STATUS_BATTERY_PERCENT = 0x46;
  const STATUS_PRESET = 0x60;

  const RES_IDS = {
    1 => "4K",
    4 => "2.7K",
    6 => "2.7K 4:3",
    7 => "1440",
    9 => "1080",
    18 => "4K 4:3",
    24 => "5K",
    25 => "5K 4:3",
    26 => "5.3K 8:7",
    27 => "5.3K 4:3",
    28 => "4K 8:7",
    100 => "5.3K",
    107 => "5.3K",
    108 => "4K",
    109 => "4K",
    110 => "1080",
    111 => "2.7K",
  };
  const FOV_IDS = {
    0 => "W",
    2 => "N",
    3 => "SV",
    4 => "L",
  };
  const FPS_IDS = {
    0 => "240",
    1 => "120",
    2 => "100",
    5 => "60",
    6 => "50",
    8 => "30",
    9 => "25",
    10 => "24",
    13 => "200",
  };
  var commands = {
    "SHUTTER_ON" => [0x03, 0x01, 0x01, 0x01]b, // set shutter on
    "SHUTTER_OFF" => [0x03, 0x01, 0x01, 0x00]b, // set shutter off
    "KEEPALIVE" => [0x03, 0x5b, 0x01, 0x42]b, // set keepalive
    "SETTINGS_UPDATES" => [0x04, 0x52, 0x02, 0x03, 0x2b]b, // settings value updates
    "VALUES_UPDATES" => [
      0x09, 0x53, 0xa, 0xd, 0x22, 0x23, 0x40, 0x46, 0x60, 0x61,
    ]b, // status value updates
    "PRESET_PHOTO" => [0x04, 0x3e, 0x02, 0x03, 0xe9]b,
    "PRESET_VIDEO" => [0x04, 0x3e, 0x02, 0x03, 0xe8]b,
    "PRESET_TIMELAPSE" => [0x04, 0x3e, 0x02, 0x03, 0xea]b,
  };

  var scanning = false;
  var device = null;
  var cameraID = Application.Properties.getValue("gopro_id");
  var connectionStatus = STATUS_SEARCHING;
  var batteryLife = 100;
  var remainingTime = 3600;
  var remainingPhotos = 3600;
  var remainingTimelapse = 3600;
  var mode = GoPro.MODE_VIDEO;
  var modeName = "Standard";
  var recordingDuration = 0;
  var recording = false;
  var settings = "4K | 30 | L+";
  var logs = ["", "", ""];
  var commandNotificationsEnabled = false;
  var settingsNotificationsEnabled = false;
  var queryNotificationsEnabled = false;
  var queryResponsesQueue = [];
  var queryResponse = new [0]b;
  var bytesRemaining = 0;
  var settingsSubscribed = false;
  var resolution = 1;
  var fps = 5;
  var fov = 0;

  function debug(str) {
    System.println("[ble] " + str);
    logs.add(str);
    logs = logs.slice(1, null);
  }

  function initialize() {
    BleDelegate.initialize();
    debug("initialize");
  }

  function formatSettings() {
    settings = Lang.format("$1$ | $2$ | $3$", [
      RES_IDS.get(resolution),
      FPS_IDS.get(fps),
      FOV_IDS.get(fov),
    ]);
  }

  function accumulateQueryResponses() {
    while (queryResponsesQueue.size() > 0) {
      var buf = queryResponsesQueue[0] as Lang.ByteArray;
      queryResponsesQueue = queryResponsesQueue.slice(1, null);

      if ((buf[0] & CONT_MASK) != 0) {
        buf = buf.slice(1, null);
      } else {
        queryResponse = new [0]b;
        var hdr = (buf[0] & HDR_MASK) >> 5;
        if (hdr == GENERAL) {
          bytesRemaining = buf[0] & GEN_LEN_MASK;
          buf = buf.slice(1, null);
        } else if (hdr == EXT_13) {
          bytesRemaining = ((buf[0] & EXT_13_BYTE0_MASK) << 8) + buf[1];
          buf = buf.slice(2, null);
        } else if (hdr == EXT_16) {
          bytesRemaining = (buf[1] << 8) + buf[2];
          buf = buf.slice(3, null);
        }
      }
      queryResponse = queryResponse.addAll(buf);
      bytesRemaining -= buf.size();

      if (bytesRemaining < 0) {
        debug("received too much data. parsing is in unknown state");
      } else if (bytesRemaining == 0) {
        parseQueryResponse();
      }
    }
  }

  function parseQueryResponse() {
    var currentByte = 2;
    if (queryResponse.size() > 0) {
      var currentId = -1;
      var data = new [0]b;
      var size = 0;
      while (currentByte < queryResponse.size()) {
        currentId = queryResponse[currentByte];
        size = queryResponse[currentByte + 1].toNumber();
        data = queryResponse.slice(currentByte + 2, currentByte + 2 + size);
        debug(Lang.format("$1$ $2$ $3$", [currentId, size, data]));
        currentByte = currentByte + 2 + size;
        if (
          queryResponse[0] == RESPONSE_TYPE_STATUS ||
          queryResponse[0] == NOTIFICATION_TYPE_STATUS
        ) {
          if (currentId == STATUS_DURATION) {
            recordingDuration = data.decodeNumber(Lang.NUMBER_FORMAT_UINT32, {
              :offset => 0,
              :endianness => Lang.ENDIAN_BIG,
            });
          } else if (currentId == STATUS_REM_PHOTOS) {
            remainingPhotos = data.decodeNumber(Lang.NUMBER_FORMAT_UINT32, {
              :offset => 0,
              :endianness => Lang.ENDIAN_BIG,
            });
          } else if (currentId == STATUS_REM_VIDEOS) {
            remainingTime = data.decodeNumber(Lang.NUMBER_FORMAT_UINT32, {
              :offset => 0,
              :endianness => Lang.ENDIAN_BIG,
            });
          } else if (currentId == STATUS_REM_TIMELAPSE) {
            remainingTimelapse = data.decodeNumber(Lang.NUMBER_FORMAT_UINT32, {
              :offset => 0,
              :endianness => Lang.ENDIAN_BIG,
            });
          } else if (currentId == STATUS_BATTERY_PERCENT) {
            batteryLife = data.decodeNumber(Lang.NUMBER_FORMAT_UINT8, {
              :offset => 0,
              :endianness => Lang.ENDIAN_BIG,
            });
          } else if (currentId == STATUS_PRESET) {
            mode = data.decodeNumber(Lang.NUMBER_FORMAT_UINT32, {
              :offset => 0,
              :endianness => Lang.ENDIAN_BIG,
            });
          } else if (currentId == STATUS_RECORDING) {
            recording =
              data.decodeNumber(Lang.NUMBER_FORMAT_UINT8, {
                :offset => 0,
                :endianness => Lang.ENDIAN_BIG,
              }) == 1;
          }
        } else if (
          queryResponse[0] == RESPONSE_TYPE_SETTING ||
          queryResponse[0] == NOTIFICATION_TYPE_SETTING
        ) {
          if (currentId == STATUS_RES) {
            resolution = data.decodeNumber(Lang.NUMBER_FORMAT_UINT8, {
              :offset => 0,
              :endianness => Lang.ENDIAN_BIG,
            });
          } else if (currentId == STATUS_FOV) {
            fov = data.decodeNumber(Lang.NUMBER_FORMAT_UINT8, {
              :offset => 0,
              :endianness => Lang.ENDIAN_BIG,
            });
          }
          if (currentId == STATUS_FPS) {
            fps = data.decodeNumber(Lang.NUMBER_FORMAT_UINT8, {
              :offset => 0,
              :endianness => Lang.ENDIAN_BIG,
            });
          }
        }
      }
    }
  }

  function sendCommand(command) {
    var service;
    var ch;

    if (device == null) {
      debug("sendCommand: not connected");
      return;
    }

    debug("sendCommand " + commands.get(command) + " now !");
    service = device.getService(CONTROL_AND_QUERY_SERVICE);
    ch = service.getCharacteristic(COMMAND_CHAR);
    try {
      ch.requestWrite(commands.get(command), {
        :writeType => Ble.WRITE_TYPE_DEFAULT,
      });
    } catch (ex) {
      debug("can't send command " + commands.get(command));
    }
  }

  function sendQuery(query) {
    var service;
    var ch;

    if (device == null) {
      debug("sendQuery: not connected");
      return;
    }

    debug("sendQuery " + commands.get(query) + "now !");
    service = device.getService(CONTROL_AND_QUERY_SERVICE);
    ch = service.getCharacteristic(QUERY_CHAR);
    try {
      ch.requestWrite(commands.get(query), {
        :writeType => Ble.WRITE_TYPE_DEFAULT,
      });
    } catch (ex) {
      debug("can't send query " + commands.get(query));
    }
  }

  function keepalive() {
    sendCommand("KEEPALIVE");
  }

  function onCharacteristicWrite(ch, value) {
    debug("char write " + ch.getUuid() + " " + value);
    if (!settingsSubscribed) {
      sendQuery("SETTINGS_UPDATES");
      settingsSubscribed = true;
    }
  }

  function onCharacteristicChanged(ch, value) {
    debug("char changed " + ch.getUuid() + " " + value);
    if (ch.getUuid().equals(COMMAND_NOTIFICATION)) {
    } else if (ch.getUuid().equals(QUERY_NOTIFICATION)) {
      queryResponsesQueue.add(value);
    }
  }

  function onDescriptorWrite(desc, value) {
    debug("descriptor write " + desc.getUuid() + " " + value);
    if (!commandNotificationsEnabled) {
      commandNotificationsEnabled = true;
      debug("command enabled, enabling notifications for QUERY");
      enableNotifications(QUERY_NOTIFICATION);
    } else if (!queryNotificationsEnabled) {
      queryNotificationsEnabled = true;
      debug("query enabled, enabling notifications for SETTINGS");
      enableNotifications(SETTINGS_NOTIFICATION);
    } else if (!settingsNotificationsEnabled) {
      settingsNotificationsEnabled = true;
      debug("all notifications enabled");
      connectionStatus = STATUS_CONNECTED;
      sendQuery("VALUES_UPDATES");
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
      commandNotificationsEnabled = false;
      settingsNotificationsEnabled = false;
      queryNotificationsEnabled = false;
      connectionStatus = STATUS_SEARCHING;
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

  function onScanResults(scanResults) {
    debug("scan results");
    var name;
    var uuids;
    for (
      var result = scanResults.next();
      result != null;
      result = scanResults.next()
    ) {
      name = result.getDeviceName();
      uuids = result.getServiceUuids();

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
