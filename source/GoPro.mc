// vim: syntax=c

using Toybox.System;
using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Application;
using Toybox.Lang;
using Toybox.StringUtil;
using Toybox.Time;

class GoPro extends Ble.BleDelegate {
  function initialize() {
    Ble.BleDelegate.initialize();
  }

  const DEVICE_NAME = "GoPro Cam";
  // GoPro's normal Open API service. Advertised once the camera is paired
  // (device name "GoPro 1234").
  const CONTROL_AND_QUERY_SERVICE = Ble.stringToUuid(
    "0000fea6-0000-1000-8000-00805f9b34fb"
  );
  // Google Fast Pair service. A GoPro in pairing mode (Connections →
  // Connect Device) advertises THIS, not FEA6, with the generic name
  // "GoPro Cam". First-time pairing must match this or the camera is
  // invisible to the scan.
  const PAIR_SERVICE = Ble.stringToUuid(
    "0000fe2c-0000-1000-8000-00805f9b34fb"
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
  const FEATURE_TYPE_PRESET = 0xf5;
  const RESPONSE_TYPE_PRESET = 0xf2;
  const NOTIFICATION_TYPE_PRESET = 0xf3;
  const RESPONSE_TYPE_SLEEP = 0x05;

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
    STATUS_SLEEP = 3,
  }

  const STATUS_RES = 0x02;
  const STATUS_FPS = 0x03;
  const STATUS_TIME_LAPSE_SPEED = 0x05;
  const STATUS_FOV = 0x2b;
  const STATUS_RECORDING = 0xa;
  const STATUS_DURATION = 0xd;
  const STATUS_NIGHT_PHOTO_SHUTTER = 0x13;
  const STATUS_NIGHT_LAPSE_SPEED = 0x20;
  const STATUS_REM_PHOTOS = 0x22;
  const STATUS_REM_VIDEOS = 0x23;
  const STATUS_REM_TIMELAPSE = 0x40;
  const STATUS_BATTERY_PERCENT = 0x46;
  const STATUS_VIDEO_PRESET = 0x5d;
  const STATUS_PHOTO_PRESET = 0x5e;
  const STATUS_TIMELAPSE_PRESET = 0x5f;
  const STATUS_PRESET_GROUP = 0x60;
  const STATUS_TIMEWARP_SPEED = 0x6f;
  const STATUS_PRESET = 0x61;
  const STATUS_LENS_121 = 0x79;
  const STATUS_LENS_122 = 0x7a;
  const STATUS_LENS_123 = 0x7b;
  const STATUS_FORMAT = 0x80;
  const STATUS_LIVE_BURST_FORMAT = 0x85;
  const STATUS_BURST_FREQUENCY = 0x93;

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
    0 => "Wide",
    2 => "Narrow",
    3 => "SuperView",
    4 => "Linear",
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
  const LENS_121_IDS = {
    0 => "Wide",
    2 => "Narrow",
    3 => "SuperView",
    4 => "Linear",
    7 => "Max SV",
    8 => "Linear+HLev",
    9 => "HyperView",
    10 => "Linear+HLock",
    11 => "Max HV",
  };
  const LENS_122_123_IDS = {
    19 => "Narrow",
    100 => "Max SV",
    101 => "Wide",
    102 => "Linear",
  };

  const FORMAT_IDS = {
    13 => "Video",
    20 => "Photo",
    21 => "Photo",
    26 => "Video",
  };

  const PRESET_TITLES_IDS = {
    0 => "Activity",
    1 => "Standard",
    2 => "Cinematic",
    3 => "Photo",
    4 => "Live Burst",
    5 => "Burst",
    6 => "Night",
    7 => "Time Warp",
    8 => "Time Lapse",
    9 => "Night Lapse",
    10 => "Video",
    11 => "SloMo",
    13 => "Photo",
    14 => "Panorama",
    16 => "Time Warp",
    18 => "Custom",
    19 => "Air",
    20 => "Bike",
    21 => "Epic",
    22 => "Indoor",
    23 => "Motor",
    24 => "Mounted",
    25 => "Outdoor",
    26 => "POV",
    27 => "Selfie",
    28 => "Skate",
    29 => "Snow",
    30 => "Trail",
    31 => "Travel",
    32 => "Water",
    33 => "Looping",
    34 => "Stars",
    35 => "Action",
    36 => "Follow cam",
    37 => "Surf",
    38 => "City",
    39 => "Shaky",
    40 => "Chesty",
    41 => "Helmet",
    42 => "Bite",
    // Hero 13 / Max 2 additions (Open API v2.1 preset_status.proto)
    43 => "Cinematic",
    44 => "Vlog",
    45 => "FPV",
    46 => "HDR",
    47 => "Landscape",
    48 => "Log",
    49 => "SloMo",
    50 => "Tripod",
    55 => "Video Max",
    58 => "Basic",
    59 => "Ultra SloMo",
    60 => "Standard Endurance",
    61 => "Activity Endurance",
    62 => "Cinematic Endurance",
    63 => "SloMo Endurance",
    64 => "Stationary",
    65 => "Stationary",
    66 => "Stationary",
    67 => "Stationary",
    68 => "Simple Video",
    69 => "Simple Time Warp",
    70 => "Simple Super Photo",
    71 => "Simple Night Photo",
    72 => "Simple Video Endurance",
    73 => "Highest Quality",
    74 => "Extended Battery",
    75 => "Longest Battery",
    76 => "Star Trail",
    77 => "Light Painting",
    78 => "Light Trail",
    79 => "Full Frame",
    82 => "Standard Quality Video",
    83 => "Basic Quality Video",
    93 => "Highest Quality Video",
    94 => "User Defined",
    // Hero 13 / Max 2 additions
    99 => "Standard",
    100 => "HDR",
    106 => "Burst SloMo",
    125 => "Video 4:3",
    126 => "Video 16:9",
    127 => "SloMo 16:9",
    131 => "Time Lapse",
    132 => "Time Lapse",
    133 => "Night Lapse",
    134 => "Night Lapse",
  };

  const NIGHT_LAPSE_SPEED = {
    4 => "4s",
    5 => "5s",
    10 => "10s",
    15 => "15s",
    20 => "20s",
    30 => "30s",
    60 => "1m",
    120 => "2m",
    300 => "5m",
    1800 => "30m",
    3600 => "60m",
    3601 => "Auto",
  };
  const TIME_LAPSE_SPEED = {
    0 => "0,5s",
    1 => "1s",
    2 => "2s",
    3 => "5s",
    4 => "10s",
    5 => "30s",
    6 => "60s",
    7 => "2m",
    8 => "5m",
    9 => "30m",
    10 => "60m",
  };

  const TIMEWARP_SPEED = {
    0 => "x15",
    1 => "x30",
    7 => "x2",
    8 => "x5",
    9 => "x10",
    10 => "Auto",
  };

  const LIVEBURST_FORMAT = {
    0 => "8MP",
    1 => "12MP",
  };

  const BURST_FREQUENCY = {
    0 => "3/1s",
    1 => "5/1s",
    2 => "10/1s",
    4 => "10/3s",
  };

  const NIGHT_PHOTO_SHUTTER = {
    0 => "Auto",
    1 => "2s",
    2 => "5s",
    3 => "10s",
    4 => "15s",
    5 => "20s",
    6 => "30s",
  };
  var commands as Lang.Dictionary<Lang.String, Lang.ByteArray> = {
    "SHUTTER_ON" => [0x03, 0x01, 0x01, 0x01]b, // set shutter on
    "SHUTTER_OFF" => [0x03, 0x01, 0x01, 0x00]b, // set shutter off
    "HILIGHT" => [0x01, 0x18]b, // hilight video
    "SLEEP" => [0x01, 0x05]b, // put camera to sleep
    "KEEPALIVE" => [0x03, 0x5b, 0x01, 0x42]b, // set keepalive
    "SETTINGS_UPDATES" => [
      0x0e, 0x52, 0x02, 0x03, 0x05, 0x13, 0x20, 0x2b, 0x6f, 0x79, 0x7a, 0x7b,
      0x80, 0x85, 0x93,
    ]b, // settings value updates
    "VALUES_UPDATES" => [
      0x0c, 0x53, 0xa, 0xd, 0x22, 0x23, 0x40, 0x46, 0x5d, 0x5e, 0x5f, 0x60,
      0x61,
    ]b, // status value updates
    "PRESET_PHOTO" => [0x04, 0x3e, 0x02, 0x03, 0xe9]b,
    "PRESET_VIDEO" => [0x04, 0x3e, 0x02, 0x03, 0xe8]b,
    "PRESET_TIMELAPSE" => [0x04, 0x3e, 0x02, 0x03, 0xea]b,
    "PRESET_LIST" => [0x04, 0xf5, 0x72, 0x08, 0x01]b,
    "PRESET_ID" => [0x06, 0x40, 0x04]b,
  };

  var batteryLife as Lang.Number = 100;
  var burstFrequency as Lang.Number = 0;
  var queryBytesRemaining as Lang.Number = 0;
  var commandBytesRemaining as Lang.Number = 0;
  var cameraID as Lang.Number = 0;
  var commandNotificationsEnabled as Lang.Boolean = false;
  var connectionStatus as Lang.Number = STATUS_SEARCHING;
  var currentPreset as OpenGopro.Preset? = null;
  var device as Ble.Device? = null;
  var format as Lang.Number = 0;
  var fov as Lang.Number = 0;
  var fps as Lang.Number = 5;
  var lens_121 as Lang.Number = 0;
  var lens_122 as Lang.Number = 0;
  var lens_123 as Lang.Number = 0;
  var liveBurstFormat as Lang.Number = 0;
  var mode as Lang.Number = GoPro.MODE_VIDEO;
  var modeId as Lang.Number = 9;
  var modeName as Lang.String = "Standard";
  var nightLapseSpeed as Lang.Number = 3601;
  var nightPhotoShutter as Lang.Number = 0;
  var presetGroups as PresetGroups = new PresetGroups(null);
  var presetListFetched as Lang.Boolean = false;
  var profileRegistered as Lang.Boolean = false;
  var queryNotificationsEnabled as Lang.Boolean = false;
  var queryResponse as Lang.ByteArray = new [0]b;
  var queryResponsesQueue as Lang.Array<Lang.ByteArray> = [];
  var commandResponse as Lang.ByteArray = new [0]b;
  var commandResponseQueue as Lang.Array<Lang.ByteArray> = [];
  var flatModeId as Lang.Number = 0;
  var recording as Lang.Boolean = false;
  var recordingDuration as Lang.Number = 0;
  var remainingPhotos as Lang.Number = 3600;
  var remainingTime as Lang.Number = 3600;
  var remainingTimeDelta as Lang.Number = 0;
  var remainingTimelapse as Lang.Number = 3600;
  var resolution as Lang.Number = 1;
  var settings as Lang.String = "4K | 30 | L+";
  var settingsNotificationsEnabled as Lang.Boolean = false;
  var settingsSubscribed as Lang.Boolean = false;
  var shouldConnect as Lang.Boolean = false;
  var timeLapseSpeed as Lang.Number = 0;
  var timeWarpSpeed as Lang.Number = 0;
  var lastPreset as Lang.Boolean = false;
  var firstPreset as Lang.Boolean = false;
  var asleep as Lang.Boolean = false;
  var hasBeenConnected as Lang.Boolean = false;
  var autoReconnect as Lang.Boolean = (Application.Properties.getValue("auto_reconnect") != null
    ? Application.Properties.getValue("auto_reconnect")
    : false) as Lang.Boolean;
  // Tick counter for the connecting-phase watchdog. -1 = inactive, 0+ counts
  // seconds since CONNECTING was entered. MainView.compute() (1 Hz) drives
  // tickConnectingWatchdog(); we fire onConnectingTimeout at WATCHDOG_TICKS.
  // Toybox.Timer is not available in DataField app type — this is the
  // workaround.
  var connectingWatchdogTicks as Lang.Number = -1;
  const WATCHDOG_TICKS = 10;

  const SIMULATION_MODE = false; // Set to true to enable simulation mode

  // Optional callbacks set by the pairing-time GoProSensorDelegate instance.
  // Null in the activity-time instance (which does not scan and handles
  // connection state internally).
  var onScanResultCallback as Lang.Method?;
  var onConnectionCallback as Lang.Method?;

  var commandQueue as Lang.Array<Lang.Dictionary<Lang.Symbol, Lang.Object>> = [];
  var sendingCommand as Lang.Boolean = false;

  // Set this to true for build/dev, false for release
  const DEBUG_LOG = false;

  // Unified logging method
  function log(str as Lang.Object) as Void {
    if (DEBUG_LOG) {
      System.println("[GoPro] " + str);
    }
  }

  function sendCommand(command as Lang.String, args as Lang.ByteArray?) as Void {
    if (SIMULATION_MODE) {
      log("[SIM] sendCommand called, BLE logic skipped: " + command);
      // Optionally simulate command queueing/processing here if needed
    } else {
      if (command == "PRESET_ID" && (args == null || args.size() != 4)) {
        log("[ERROR] sendCommand PRESET_ID with invalid args: " + args);
        return;
      }
      // Enqueue the command. Type-erased Dictionary so Symbol values can be
      // mixed (String for :command, ByteArray? for :args).
      commandQueue.add({ :command => command, :args => args } as Lang.Dictionary<Lang.Symbol, Lang.Object>);
      startSendingCommands();
    }
  }

  function startSendingCommands() as Void {
    if (SIMULATION_MODE) {
      // In simulation mode, skip BLE logic
    } else {
      if (!sendingCommand && commandQueue.size() > 0) {
        var item = commandQueue[0];
        sendingCommand = true;
        var commandKey = item[:command] as Lang.String;
        var baseBytes = commands.get(commandKey) as Lang.ByteArray;
        var toSend = ([]b).addAll(baseBytes);
        var extraArgs = item[:args] as Lang.ByteArray?;
        if (extraArgs != null) {
          toSend = toSend.addAll(extraArgs);
        }
        var d = device;
        if (d != null) {
          var service = d.getService(CONTROL_AND_QUERY_SERVICE);
          if (service != null) {
            var ch = service.getCharacteristic(COMMAND_CHAR);
            if (ch != null) {
              try {
                ch.requestWrite(toSend, {
                  :writeType => Ble.WRITE_TYPE_DEFAULT,
                });
              } catch (ex) {
                log("[ERROR] Exception in ch.requestWrite: " + ex);
                // On error, clear sending flag and try next
                sendingCommand = false;
                commandQueue = commandQueue.slice(1, null);
                startSendingCommands();
              }
            }
          }
        }
      }
    }
  }

  function sendQuery(query as Lang.String) as Void {
    if (SIMULATION_MODE) {
      log("[SIM] sendQuery called, BLE logic skipped: " + query);
      return;
    }
    var d = device;
    if (d == null) {
      log("sendQuery: not connected");
      return;
    }
    var bytes = commands.get(query) as Lang.ByteArray;
    log("sendQuery " + bytes + "now !");
    var service = d.getService(CONTROL_AND_QUERY_SERVICE);
    if (service == null) { return; }
    var ch = service.getCharacteristic(QUERY_CHAR);
    if (ch == null) { return; }
    try {
      ch.requestWrite(bytes, {
        :writeType => Ble.WRITE_TYPE_DEFAULT,
      });
    } catch (ex) {
      log("can't send query " + bytes);
    }
  }

  function enableNotifications(characteristic as Ble.Uuid) as Void {
    if (SIMULATION_MODE) {
      log(
        "[SIM] enableNotifications called, BLE logic skipped: " + characteristic
      );
      return;
    }
    var d = device;
    if (d == null) {
      log("setNotifications: not connected");
      return;
    }
    log("setNotifications");
    var service = d.getService(CONTROL_AND_QUERY_SERVICE);
    if (service == null) { return; }
    var command = service.getCharacteristic(characteristic);
    if (command == null) { return; }
    var desc = command.getDescriptor(CONTROL_AND_QUERY_DESC);
    if (desc == null) { return; }
    desc.requestWrite([0x01, 0x00]b);
    log("Notifications requested for " + characteristic);
  }

  // Helpers to read scalars from a ByteArray slice. ByteArray.decodeNumber
  // returns Number|Float|Long|Double; we know the wire type and cast accordingly.
  private function readU8(b as Lang.ByteArray) as Lang.Number {
    return b.decodeNumber(Lang.NUMBER_FORMAT_UINT8, {:offset => 0, :endianness => Lang.ENDIAN_BIG}) as Lang.Number;
  }
  private function readU32(b as Lang.ByteArray) as Lang.Number {
    return b.decodeNumber(Lang.NUMBER_FORMAT_UINT32, {:offset => 0, :endianness => Lang.ENDIAN_BIG}) as Lang.Number;
  }

  function parseQueryResponse() as Void {
    if (SIMULATION_MODE) {
      log("[SIM] parseQueryResponse called, using hardcoded data");
      if (queryResponse.size() == 0 && presetGroups.data == null) {
        queryResponse = [245, 242]b;
        var simBytes = StringUtil.convertEncodedString(
          "CjcI6AcSLgiAgDwQDBg3KAAwNzoGCGwQABgBOgYIAhASGAE6BggDEAUYAToGCHkQBxgBQAEYACAFCicI6QcSHgiAgEAQEBg4KAAwODoGCH0QABgBOgYIehBkGAFAABgAIAYKqgEI6gcSJgiAgEQQGBg5KAAwOToGCAIQARgBOgYIbxAKGAE6Bgh5EAcYAUAAEicIgYBEEB0YWigAMFk6BggCEAEYAToHCCAQkRwYAToGCHkQABgBQAASJwiCgEQQHhhbKAAwWjoGCAIQARgBOgcIIBCRHBgBOgYIeRAAGAFAABInCIOARBAfGFwoADBbOgYIAhABGAE6BwggEJEcGAE6Bgh5EAAYAUAAGAAgBxIECBIQGRoECBIQGQ==",
          {
            :fromRepresentation => StringUtil.REPRESENTATION_STRING_BASE64,
            :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
          }
        ) as Lang.ByteArray;
        queryResponse = queryResponse.addAll(simBytes);
      }
      // Continue with the normal logic below, so simulation data is processed
    }
    if (queryResponse.size() > 0) {
      if (
        queryResponse[0] == FEATURE_TYPE_PRESET &&
        (queryResponse[1] == RESPONSE_TYPE_PRESET ||
          queryResponse[1] == NOTIFICATION_TYPE_PRESET)
      ) {
        var pgBytes = queryResponse.slice(2, null);
        presetGroups.data = pgBytes;
        if (!SIMULATION_MODE) {
          var base64 = StringUtil.convertEncodedString(pgBytes, {
            :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_BASE64,
          });
          log("[DEBUG] queryResponse (base64) for preset: " + base64);
        }
        Application.Storage.setValue(
          "lastPresetGroupResult",
          StringUtil.convertEncodedString(pgBytes, {
            :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_BASE64,
          })
        );
        Application.Storage.setValue("lastPresetGroupUploaded", false);
        queryResponse = new [0]b;
      } else {
        var currentByte = 2;
        var currentId = -1;
        var data = new [0]b;
        var size = 0;
        while (currentByte < queryResponse.size()) {
          currentId = queryResponse[currentByte];
          size = queryResponse[currentByte + 1].toNumber();
          data = queryResponse.slice(currentByte + 2, currentByte + 2 + size);
          log(Lang.format("$1$ $2$ $3$", [currentId, size, data]));
          currentByte = currentByte + 2 + size;
          if (
            queryResponse[0] == RESPONSE_TYPE_STATUS ||
            queryResponse[0] == NOTIFICATION_TYPE_STATUS
          ) {
            if (currentId == STATUS_DURATION) {
              recordingDuration = readU32(data);
            } else if (currentId == STATUS_REM_PHOTOS) {
              remainingPhotos = readU32(data);
            } else if (currentId == STATUS_REM_VIDEOS) {
              remainingTime = readU32(data);
            } else if (currentId == STATUS_REM_TIMELAPSE) {
              remainingTimelapse = readU32(data);
              remainingTimeDelta = 0;
            } else if (currentId == STATUS_BATTERY_PERCENT) {
              batteryLife = readU8(data);
            } else if (currentId == STATUS_PRESET_GROUP) {
              mode = readU32(data);
            } else if (currentId == STATUS_PRESET) {
              modeId = readU32(data);
            } else if (currentId == STATUS_RECORDING) {
              recording = readU8(data) == 1;
            }
          } else if (
            queryResponse[0] == RESPONSE_TYPE_SETTING ||
            queryResponse[0] == NOTIFICATION_TYPE_SETTING
          ) {
            if (currentId == STATUS_RES) {
              resolution = readU8(data);
            } else if (currentId == STATUS_FOV) {
              fov = readU8(data);
            } else if (currentId == STATUS_FPS) {
              fps = readU8(data);
            } else if (currentId == STATUS_FORMAT) {
              format = readU8(data);
            } else if (currentId == STATUS_LENS_121) {
              lens_121 = readU8(data);
            } else if (currentId == STATUS_LENS_122) {
              lens_122 = readU8(data);
            } else if (currentId == STATUS_LENS_123) {
              lens_123 = readU8(data);
            } else if (currentId == STATUS_BURST_FREQUENCY) {
              burstFrequency = readU8(data);
            } else if (currentId == STATUS_LIVE_BURST_FORMAT) {
              liveBurstFormat = readU8(data);
            } else if (currentId == STATUS_NIGHT_LAPSE_SPEED) {
              nightLapseSpeed = readU32(data);
              if (nightLapseSpeed > 3600) {
                nightLapseSpeed = 3601;
              }
            } else if (currentId == STATUS_NIGHT_PHOTO_SHUTTER) {
              nightPhotoShutter = readU8(data);
            } else if (currentId == STATUS_TIME_LAPSE_SPEED) {
              timeLapseSpeed = readU8(data);
            } else if (currentId == STATUS_TIMEWARP_SPEED) {
              timeWarpSpeed = readU8(data);
            }
          }
        }
      }
    }
  }

  function parseCommandResponse(data as Lang.ByteArray) as Void {
    if (data.size() == 3 && data[0].toNumber() == 2) {
      var commandId = data[1].toNumber();
      var status = data[2].toNumber();
      if (commandId == RESPONSE_TYPE_SLEEP && status == 0) {
        asleep = true;
        connectionStatus = STATUS_SLEEP;
      }
    }
  }

  // Wake the camera from either sleep state:
  //  - "low-power sleep" with the BLE link still up: any BLE write wakes
  //    the camera, so we send a KEEPALIVE and stay on the existing link.
  //  - "deep sleep" with BLE dropped: re-pair from the stored ScanResult;
  //    onConnectedStateChanged will drive the rest of the recovery.
  function wakeup() as Void {
    shouldConnect = true;
    if (!asleep) { return; }
    asleep = false;
    var linkUp = device != null
      && commandNotificationsEnabled
      && queryNotificationsEnabled
      && settingsNotificationsEnabled;
    if (linkUp) {
      connectionStatus = STATUS_CONNECTED;
      sendCommand("KEEPALIVE", null);
    } else {
      connectionStatus = STATUS_SEARCHING;
      var paired = Application.Storage.getValue($.PAIRED_SCAN_RESULT) as Ble.ScanResult?;
      if (paired != null) {
        Ble.pairDevice(paired);
      }
    }
  }

  function sleep() as Void {
    if (!asleep) {
      shouldConnect = false; // Prevent auto-reconnect after sleep
      sendCommand("SLEEP", null);
    }
  }

  function onCharacteristicWrite(ch as Ble.Characteristic, value as Ble.Status) as Void {
    log("char write " + ch.getUuid() + " " + value);
    if (!settingsSubscribed) {
      sendQuery("SETTINGS_UPDATES");
      settingsSubscribed = true;
    } else if (!presetListFetched) {
      sendQuery("PRESET_LIST");
      presetListFetched = true;
    }
    sendingCommand = false;
    if (commandQueue.size() > 0) {
      commandQueue = commandQueue.slice(1, null);
    }
    startSendingCommands();
  }

  function onCharacteristicChanged(ch as Ble.Characteristic, value as Lang.ByteArray) as Void {
    log("char changed " + ch.getUuid() + " " + value);
    if (ch.getUuid().equals(COMMAND_NOTIFICATION)) {
      if (value.size() == 3) {
        parseCommandResponse(value);
      } else {
        commandResponseQueue.add(value);
      }
    } else if (ch.getUuid().equals(QUERY_NOTIFICATION)) {
      queryResponsesQueue.add(value);
    }
  }

  function onScanResults(scanResults as Ble.Iterator) as Void {
    for (
      var next = scanResults.next();
      next != null;
      next = scanResults.next()
    ) {
      var result = next as Ble.ScanResult;
      var uuids = result.getServiceUuids();
      var matches = false;
      for (var u = uuids.next(); u != null; u = uuids.next()) {
        // Match both: FEA6 (paired/normal mode) and FE2C (pairing mode).
        // A camera being paired for the first time only advertises FE2C.
        if (u.equals(CONTROL_AND_QUERY_SERVICE) || u.equals(PAIR_SERVICE)) {
          matches = true;
          break;
        }
      }
      var cb = onScanResultCallback;
      if (matches && cb != null) {
        log("scan match: " + result.getDeviceName() + " uuids matched");
        cb.invoke(result);
      }
    }
  }

  function onDescriptorWrite(desc as Ble.Descriptor, value as Ble.Status) as Void {
    log("descriptor write " + desc.getUuid() + " " + value);
    if (!commandNotificationsEnabled) {
      commandNotificationsEnabled = true;
      log("command enabled, enabling notifications for QUERY");
      enableNotifications(QUERY_NOTIFICATION);
    } else if (!queryNotificationsEnabled) {
      queryNotificationsEnabled = true;
      log("query enabled, enabling notifications for SETTINGS");
      enableNotifications(SETTINGS_NOTIFICATION);
    } else if (!settingsNotificationsEnabled) {
      settingsNotificationsEnabled = true;
      log("all notifications enabled");
      connectionStatus = STATUS_CONNECTED;
      stopConnectingWatchdog();
      sendQuery("VALUES_UPDATES");
    }
  }

  function onProfileRegister(uuid as Ble.Uuid, status as Ble.Status) as Void {
    profileRegistered = true;
    log("registered: " + uuid + " " + status);
  }

  function registerProfiles() as Void {
    if (!profileRegistered) {
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
  }

  function onEncryptionStatus(device as Ble.Device, status as Ble.Status) as Void {
    log("device paired successfully !");
    log("bonded: " + device.getName() + " " + status);
    if (status == Ble.STATUS_SUCCESS) {
      enableNotifications(COMMAND_NOTIFICATION);
    }
  }

  function onConnectedStateChanged(device as Ble.Device, state as Ble.ConnectionState) as Void {
    if (device == null || state == null) {
      log(
        "[ERROR] onConnectedStateChanged: Not enough arguments (device=" +
          device +
          ", state=" +
          state +
          ")"
      );
      return;
    }
    if (device.getName() != null) {
      log("device connected: " + device.getName());
      log(device.getName() + " " + state);
      var devName = device.getName();
      if (
        cameraID == 0 &&
        devName != null &&
        devName.length() > 6 &&
        devName.find("GoPro ") == 0
      ) {
        var idStr = devName.substring(6, devName.length()) as Lang.String;
        var idNum = idStr.toNumber();
        if (idNum != null && idNum > 0) {
          cameraID = idNum;
        }
      }
    }
    if (state == Ble.CONNECTION_STATE_CONNECTED) {
      asleep = false;
      self.device = device;
      hasBeenConnected = true;
      // BLE link is up but we haven't yet enabled the COMMAND/QUERY/SETTINGS
      // notification descriptors. The watchdog will fire if that chain stalls.
      connectionStatus = STATUS_CONNECTING;
      startConnectingWatchdog();
    } else {
      // BLE link dropped. Reset to SEARCHING so the UI shows the right state
      // and the notification-enable flags don't leak into the next session.
      connectionStatus = STATUS_SEARCHING;
      commandNotificationsEnabled = false;
      queryNotificationsEnabled = false;
      settingsNotificationsEnabled = false;
      settingsSubscribed = false;
      presetListFetched = false;
      stopConnectingWatchdog();
      if (autoReconnect && !asleep) {
        log("Auto-reconnect enabled, attempting to reconnect...");
        shouldConnect = true;
      }
    }

    if (state == Ble.CONNECTION_STATE_CONNECTED && onConnectionCallback != null) {
      onConnectionCallback.invoke(device);
    }
  }

  function startConnectingWatchdog() as Void {
    connectingWatchdogTicks = 0;
  }

  function stopConnectingWatchdog() as Void {
    connectingWatchdogTicks = -1;
  }

  // Called from MainView.compute() once per second.
  function tickConnectingWatchdog() as Void {
    if (connectingWatchdogTicks < 0) { return; }
    connectingWatchdogTicks += 1;
    if (connectingWatchdogTicks >= WATCHDOG_TICKS) {
      connectingWatchdogTicks = -1;
      onConnectingTimeout();
    }
  }

  function onConnectingTimeout() as Void {
    var allEnabled = commandNotificationsEnabled
      && queryNotificationsEnabled
      && settingsNotificationsEnabled;
    if (connectionStatus == STATUS_CONNECTING ||
        (connectionStatus == STATUS_CONNECTED && !allEnabled)) {
      log("connecting watchdog fired — resetting and re-pairing");
      var paired = Application.Storage.getValue($.PAIRED_SCAN_RESULT) as Ble.ScanResult?;
      if (device != null) {
        Ble.unpairDevice(device);
        device = null;
      }
      commandNotificationsEnabled = false;
      queryNotificationsEnabled = false;
      settingsNotificationsEnabled = false;
      connectionStatus = STATUS_SEARCHING;
      if (paired != null) {
        Ble.pairDevice(paired);
      }
    }
  }

  function accumulateQueryResponses() as Void {
    while (queryResponsesQueue.size() > 0) {
      var buf = queryResponsesQueue[0] as Lang.ByteArray;
      queryResponsesQueue = queryResponsesQueue.slice(1, null);
      if ((buf[0] & CONT_MASK) != 0) {
        buf = buf.slice(1, null);
      } else {
        queryResponse = new [0]b;
        var hdr = (buf[0] & HDR_MASK) >> 5;
        if (hdr == GENERAL) {
          queryBytesRemaining = buf[0] & GEN_LEN_MASK;
          buf = buf.slice(1, null);
        } else if (hdr == EXT_13) {
          queryBytesRemaining = ((buf[0] & EXT_13_BYTE0_MASK) << 8) + buf[1];
          buf = buf.slice(2, null);
        } else if (hdr == EXT_16) {
          queryBytesRemaining = (buf[1] << 8) + buf[2];
          buf = buf.slice(3, null);
        }
      }
      queryResponse = queryResponse.addAll(buf);
      queryBytesRemaining -= buf.size();
      if (queryBytesRemaining < 0) {
        log("received too much data. parsing is in unknown state");
      } else if (queryBytesRemaining == 0) {
        parseQueryResponse();
      }
    }
  }

  function accumulateCommandResponses() as Void {
    while (commandResponseQueue.size() > 0) {
      var buf = commandResponseQueue[0] as Lang.ByteArray;
      commandResponseQueue = commandResponseQueue.slice(1, null);
      if ((buf[0] & CONT_MASK) != 0) {
        buf = buf.slice(1, null);
      } else {
        commandResponse = new [0]b;
        var hdr = (buf[0] & HDR_MASK) >> 5;
        if (hdr == GENERAL) {
          commandBytesRemaining = buf[0] & GEN_LEN_MASK;
          buf = buf.slice(1, null);
        } else if (hdr == EXT_13) {
          commandBytesRemaining = ((buf[0] & EXT_13_BYTE0_MASK) << 8) + buf[1];
          buf = buf.slice(2, null);
        } else if (hdr == EXT_16) {
          commandBytesRemaining = (buf[1] << 8) + buf[2];
          buf = buf.slice(3, null);
        }
      }
      commandResponse = commandResponse.addAll(buf);
      commandBytesRemaining -= buf.size();
      if (commandBytesRemaining < 0) {
        log("received too much data. parsing is in unknown state");
      } else if (commandBytesRemaining == 0) {
        parseCommandResponse(commandResponse);
      }
    }
  }

  function formatSettings() as Void {
    var modeKey = mode.toNumber();
    var presetMap = null;
    var presetIndexes = null;
    // Try to get presetMap and presetIndexes using [] notation for both maps and arrays
    if (presetGroups != null && presetGroups.presets != null) {
      if (presetGroups.presets[modeKey] != null) {
        presetMap = presetGroups.presets[modeKey];
      }
    }
    if (presetGroups != null && presetGroups.presetsIndexes != null) {
      if (presetGroups.presetsIndexes[modeKey] != null) {
        presetIndexes = presetGroups.presetsIndexes[modeKey];
      }
    }
    // Fallback: if modeId is not present, use first available
    if (
      presetMap != null &&
      (modeId == null || presetMap[modeId.toNumber()] == null)
    ) {
      var keys = presetMap.keys != null ? presetMap.keys() : null;
      if (keys != null && keys.size() > 0) {
        modeId = keys[0];
      }
    }
    // Now get the currentPreset
    if (
      presetMap != null &&
      modeId != null &&
      presetMap[modeId.toNumber()] != null
    ) {
      currentPreset = presetMap[modeId.toNumber()];
      var presetIndex =
        presetIndexes != null ? presetIndexes.indexOf(modeId.toNumber()) : -1;
      var presetCount = presetIndexes != null ? presetIndexes.size() : 0;
      if (presetCount <= 1) {
        firstPreset = true;
        lastPreset = true;
      } else if (presetIndex == 0) {
        firstPreset = true;
        lastPreset = false;
      } else if (presetIndex == presetCount - 1) {
        firstPreset = false;
        lastPreset = true;
      } else {
        firstPreset = false;
        lastPreset = false;
      }
      log(Lang.format("$1$,$2$", [presetIndex, mode]));
    } else {
      currentPreset = null;
      firstPreset = true;
      lastPreset = true;
    }
    var cp = currentPreset;
    if (cp != null) {
      flatModeId = cp.getMode();
      var titleName = PRESET_TITLES_IDS.get(cp.getTitleId()) as Lang.String?;
      if (titleName != null) {
        modeName = titleName;
      } else if (mode == GoPro.MODE_VIDEO) {
        modeName = "Video";
      } else if (mode == GoPro.MODE_PHOTO) {
        modeName = "Photo";
      } else if (mode == GoPro.MODE_TIMELAPSE) {
        modeName = "Time Lapse";
      } else {
        modeName = "Unknown";
      }
      var tn = cp.getTitleNumber();
      if (tn > 0) {
        modeName = modeName + " " + tn;
      }
    }
    var lFov = LENS_121_IDS.get(lens_121);
    if (lFov == null) { lFov = LENS_122_123_IDS.get(lens_122); }
    if (lFov == null) { lFov = LENS_122_123_IDS.get(lens_123); }
    if (lFov == null) { lFov = FOV_IDS.get(fov); }
    if (mode == GoPro.MODE_PHOTO) {
      if (flatModeId == 25) {
        settings = Lang.format("$1$ | $2$", [
          LIVEBURST_FORMAT.get(liveBurstFormat),
          lFov,
        ]);
      } else if (flatModeId == 18) {
        settings = Lang.format("$1$ | $2$", [
          NIGHT_PHOTO_SHUTTER.get(nightPhotoShutter),
          lFov,
        ]);
      } else if (flatModeId == 19) {
        settings = Lang.format("$1$ | $2$", [
          BURST_FREQUENCY.get(burstFrequency),
          lFov,
        ]);
      } else {
        settings = Lang.format("$1$", [lFov]);
      }
    } else if (mode == GoPro.MODE_TIMELAPSE) {
      if (flatModeId == 24) {
        settings = Lang.format("$1$ | $2$ | $3$", [
          RES_IDS.get(resolution),
          TIMEWARP_SPEED.get(timeWarpSpeed),
          lFov,
        ]);
      } else if (flatModeId == 13) {
        settings = Lang.format("$1$ | $2$ | $3$", [
          RES_IDS.get(resolution),
          TIME_LAPSE_SPEED.get(timeLapseSpeed),
          lFov,
        ]);
      } else if (flatModeId == 26) {
        settings = Lang.format("$1$ | $2$ | $3$", [
          RES_IDS.get(resolution),
          NIGHT_LAPSE_SPEED.get(nightLapseSpeed),
          lFov,
        ]);
      } else {
        settings = Lang.format("$1$ | $2$ | $3$", [
          RES_IDS.get(resolution),
          FPS_IDS.get(fps),
          lFov,
        ]);
      }
    } else {
      settings = Lang.format("$1$ | $2$ | $3$", [
        RES_IDS.get(resolution),
        FPS_IDS.get(fps),
        lFov,
      ]);
    }
  }

  function getPrevNextPresetID(next as Lang.Boolean) as Lang.Number {
    var pg = presetGroups;
    if (pg != null) {
      var presetIndexes = pg.presetsIndexes.get(mode.toNumber());
      if (presetIndexes != null && presetIndexes.size() > 0) {
        var factor = next ? 1 : presetIndexes.size() - 1;
        var presetIndex = presetIndexes.indexOf(modeId.toNumber());
        var newPresetIndex = (presetIndex + factor) % presetIndexes.size();
        return presetIndexes[newPresetIndex].toNumber();
      }
    }
    lastPreset = true;
    firstPreset = true;
    return -1;
  }

  function keepalive() as Void {
    // Send the keepalive command to the GoPro
    self.sendCommand("KEEPALIVE", null);
  }
}
