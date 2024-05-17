// vim: syntax=c

using Toybox.System;
using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Application;
using Toybox.Lang;
using Toybox.StringUtil;
using Toybox.Time;

class GoPro extends Ble.BleDelegate {
  const DEVICE_NAME = "GoPro Cam";
  const CONTROL_AND_QUERY_SERVICE = Ble.stringToUuid(
    "0000fea6-0000-1000-8000-00805f9b34fb"
  );
  const PAIR_SERVICE = Ble.stringToUuid("0000FE2C-0000-1000-8000-00805F9B34FB");
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
    58 => "Basic",
    59 => "Ultra SloMo",
    60 => "Standard Endurance",
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
    94 => "Used Defined",
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
  var commands = {
    "SHUTTER_ON" => [0x03, 0x01, 0x01, 0x01]b, // set shutter on
    "SHUTTER_OFF" => [0x03, 0x01, 0x01, 0x00]b, // set shutter off
    "HILIGHT" => [0x01, 0x18]b, // hilight video
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

  var batteryLife = 100;
  var burstFrequency = 0;
  var bytesRemaining = 0;
  var cameraID = Application.Properties.getValue("gopro_id");
  var commandNotificationsEnabled = false;
  var connectionStatus = STATUS_SEARCHING;
  var currentPreset = null;
  var device = null;
  var format = 0;
  var fov = 0;
  var fps = 5;
  var lens_121 = 0;
  var lens_122 = 0;
  var lens_123 = 0;
  var liveBurstFormat = 0;
  var logs = ["", "", ""];
  var debug_logs = ["", "", ""];
  var mode = GoPro.MODE_VIDEO;
  var modeId = 9;
  var modeName = "Standard";
  var nightLapseSpeed = 3601;
  var nightPhotoShutter = 0;
  var presetGroups = new PresetGroups(null);
  var presetListFetched = false;
  var profileRegistered = false;
  var queryNotificationsEnabled = false;
  var queryResponse = new [0]b;
  var queryResponsesQueue = [];
  var flatModeId = 0;
  var recording = false;
  var recordingDuration = 0;
  var remainingPhotos = 3600;
  var remainingTime = 3600;
  var remainingTimeDelta = 0;
  var remainingTimelapse = 3600;
  var resolution = 1;
  var scanning = false;
  var settings = "4K | 30 | L+";
  var settingsNotificationsEnabled = false;
  var settingsSubscribed = false;
  var shouldConnect = false;
  var timeLapseSpeed = 0;
  var timeWarpSpeed = 0;
  var lastPreset = false;
  var firstPreset = false;
  var foundCameraIDs = [];
  var seenDevices = [];
  var pairingDevice = null;

  function debug(str, writeToFile) {
    System.println("[ble debug] " + str);
    if (writeToFile) {
      Application.Storage.setValue(
        "logs",
        Application.Storage.getValue("logs").add(
          Time.now().value() + "%" + str.toString()
        )
      );
    }
    debug_logs.add(str);
    debug_logs = debug_logs.slice(1, null);
  }

  function info(str) {
    debug(str, true);
    System.println("[ble info] " + str);
    logs.add(str);
    logs = logs.slice(1, null);
  }

  function initialize() {
    BleDelegate.initialize();
    debug("initialize", true);
  }

  function getPrevNextPresetID(next) {
    if (
      presetGroups != null &&
      presetGroups.presetsIndexes.get(mode.toNumber()) != null &&
      presetGroups.presetsIndexes.get(mode.toNumber()).size() > 0
    ) {
      var presetIndexes = presetGroups.presetsIndexes.get(mode.toNumber());
      var factor = next ? 1 : presetIndexes.size() - 1;
      var presetIndex = presetIndexes.indexOf(modeId.toNumber());
      var newPresetIndex = (presetIndex + factor) % presetIndexes.size();
      return presetIndexes[newPresetIndex].toNumber();
    } else {
      lastPreset = true;
      firstPreset = true;
      return -1;
    }
  }

  function formatSettings() {
    if (
      presetGroups != null &&
      presetGroups.presets.get(mode.toNumber()) != null &&
      modeId != null
    ) {
      currentPreset = presetGroups.presets
        .get(mode.toNumber())
        .get(modeId.toNumber());

      var presetIndex = presetGroups.presetsIndexes
        .get(mode.toNumber())
        .indexOf(modeId.toNumber());

      if (presetIndex == 0) {
        firstPreset = true;
        lastPreset = false;
      } else if (
        presetIndex ==
        presetGroups.presetsIndexes.get(mode.toNumber()).size() - 1
      ) {
        lastPreset = true;
        firstPreset = false;
      } else {
        lastPreset = false;
        firstPreset = false;
      }

      debug(Lang.format("$1$,$2$", [presetIndex, mode]), false);
    }

    if (currentPreset != null) {
      flatModeId = currentPreset.get("flatMode").toNumber();
      modeName = PRESET_TITLES_IDS.get(currentPreset.get("title"));
      if (currentPreset.get("titleNumber") > 0) {
        modeName = modeName + " " + currentPreset.get("titleNumber");
      }
    }

    var lFov = null;
    if (LENS_121_IDS.get(lens_121)) {
      lFov = LENS_121_IDS.get(lens_121);
    } else if (LENS_122_123_IDS.get(lens_122)) {
      lFov = LENS_122_123_IDS.get(lens_122);
    } else if (LENS_122_123_IDS.get(lens_123)) {
      lFov = LENS_122_123_IDS.get(lens_123);
    } else {
      lFov = FOV_IDS.get(fov);
    }

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
        debug("received too much data. parsing is in unknown state", true);
      } else if (bytesRemaining == 0) {
        parseQueryResponse();
      }
    }
  }

  function parseQueryResponse() {
    /*if (queryResponse.size() == 0 && presetGroups.data == null) {
      queryResponse = [245, 242]b;
      queryResponse = queryResponse.addAll(
        StringUtil.convertEncodedString(
          "CrcCCOgHEiQICRAMGBUoATAVOgYIAhABGAE6BggDEAgYAToGCHkQAxgBQAASJggIEAwYFCABKAEwFDoGCAIQARgBOgYIAxAIGAE6Bgh5EAAYAUAAEiQIBxAMGBIoATASOgYIAhABGAE6BggDEAgYAToGCHkQAxgBQAASJAgGEAwYFCgBMBQ6BggCEAEYAToGCAMQCBgBOgYIeRAEGAFAABIkCAAQDBgBKAAwADoGCAIQCRgBOgYIAxAFGAE6Bgh5EAAYAUAAEiQIARAMGAAoADABOgYIAhABGAE6BggDEAgYAToGCHkQAhgBQAESJAgCEAwYAigAMAI6BggCEAEYAToGCAMQCBgBOgYIeRACGAFAARIkCAMQGxgLKAAwCjoGCAIQCRgBOgYIAxAAGAE6Bgh5EAAYAUAAGAEKfwjpBxIWCICABBARGAMoADADOgYIehBlGAFAARIfCIGABBAZGAQoADAEOgcIhQEQABgBOgYIeRAAGAFAABIfCIKABBATGAUoADAFOgcIkwEQBBgBOgYIexBlGAFAARIeCIOABBASGAYoADAGOgYIExAAGAE6Bgh6EGUYAUAAGAEKfgjqBxImCICACBAYGAcoADAHOgYIAhABGAE6BghvEAoYAToGCHkQCBgBQAESJgiBgAgQDRgIKAAwCDoGCAIQCRgBOgYIBRAAGAE6Bgh5EAAYAUAAEicIgoAIEBoYCSgAMAk6BggCEAkYAToHCCAQkRwYAToGCHkQABgBQAAYAQ==",
          {
            :fromRepresentation => StringUtil.REPRESENTATION_STRING_BASE64,
            :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
          }
        )
      );
    }*/
    if (queryResponse.size() > 0) {
      if (
        queryResponse[0] == FEATURE_TYPE_PRESET &&
        (queryResponse[1] == RESPONSE_TYPE_PRESET ||
          queryResponse[1] == NOTIFICATION_TYPE_PRESET)
      ) {
        presetGroups.data = queryResponse.slice(2, null);
        Application.Storage.setValue(
          "lastPresetGroupResult",
          StringUtil.convertEncodedString(presetGroups.data, {
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
          debug(Lang.format("$1$ $2$ $3$", [currentId, size, data]), false);
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
              remainingTimelapse = data.decodeNumber(
                Lang.NUMBER_FORMAT_UINT32,
                {
                  :offset => 0,
                  :endianness => Lang.ENDIAN_BIG,
                }
              );
              remainingTimeDelta = 0;
            } else if (currentId == STATUS_BATTERY_PERCENT) {
              batteryLife = data.decodeNumber(Lang.NUMBER_FORMAT_UINT8, {
                :offset => 0,
                :endianness => Lang.ENDIAN_BIG,
              });
            } else if (currentId == STATUS_PRESET_GROUP) {
              mode = data.decodeNumber(Lang.NUMBER_FORMAT_UINT32, {
                :offset => 0,
                :endianness => Lang.ENDIAN_BIG,
              });
            } else if (currentId == STATUS_PRESET) {
              modeId = data.decodeNumber(Lang.NUMBER_FORMAT_UINT32, {
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
            } else if (currentId == STATUS_FPS) {
              fps = data.decodeNumber(Lang.NUMBER_FORMAT_UINT8, {
                :offset => 0,
                :endianness => Lang.ENDIAN_BIG,
              });
            } else if (currentId == STATUS_FORMAT) {
              format = data.decodeNumber(Lang.NUMBER_FORMAT_UINT8, {
                :offset => 0,
                :endianness => Lang.ENDIAN_BIG,
              });
            } else if (currentId == STATUS_LENS_121) {
              lens_121 = data.decodeNumber(Lang.NUMBER_FORMAT_UINT8, {
                :offset => 0,
                :endianness => Lang.ENDIAN_BIG,
              });
            } else if (currentId == STATUS_LENS_122) {
              lens_122 = data.decodeNumber(Lang.NUMBER_FORMAT_UINT8, {
                :offset => 0,
                :endianness => Lang.ENDIAN_BIG,
              });
            } else if (currentId == STATUS_LENS_123) {
              lens_123 = data.decodeNumber(Lang.NUMBER_FORMAT_UINT8, {
                :offset => 0,
                :endianness => Lang.ENDIAN_BIG,
              });
            } else if (currentId == STATUS_BURST_FREQUENCY) {
              burstFrequency = data.decodeNumber(Lang.NUMBER_FORMAT_UINT8, {
                :offset => 0,
                :endianness => Lang.ENDIAN_BIG,
              });
            } else if (currentId == STATUS_LIVE_BURST_FORMAT) {
              liveBurstFormat = data.decodeNumber(Lang.NUMBER_FORMAT_UINT8, {
                :offset => 0,
                :endianness => Lang.ENDIAN_BIG,
              });
            } else if (currentId == STATUS_NIGHT_LAPSE_SPEED) {
              nightLapseSpeed = data.decodeNumber(Lang.NUMBER_FORMAT_UINT32, {
                :offset => 0,
                :endianness => Lang.ENDIAN_BIG,
              });
              if (nightLapseSpeed > 3600) {
                nightLapseSpeed = 3601;
              }
            } else if (currentId == STATUS_NIGHT_PHOTO_SHUTTER) {
              nightPhotoShutter = data.decodeNumber(Lang.NUMBER_FORMAT_UINT8, {
                :offset => 0,
                :endianness => Lang.ENDIAN_BIG,
              });
            } else if (currentId == STATUS_TIME_LAPSE_SPEED) {
              timeLapseSpeed = data.decodeNumber(Lang.NUMBER_FORMAT_UINT8, {
                :offset => 0,
                :endianness => Lang.ENDIAN_BIG,
              });
            } else if (currentId == STATUS_TIMEWARP_SPEED) {
              timeWarpSpeed = data.decodeNumber(Lang.NUMBER_FORMAT_UINT8, {
                :offset => 0,
                :endianness => Lang.ENDIAN_BIG,
              });
            }
          }
        }
      }
    }
  }

  function sendCommand(command, args) {
    var service;
    var ch;

    var finalCommand = []b.addAll(commands.get(command));

    if (args != null) {
      finalCommand = finalCommand.addAll(args);
    }

    if (device == null) {
      debug("sendCommand: not connected", true);
      return;
    }

    debug("sendCommand " + finalCommand + " now !", false);
    service = device.getService(CONTROL_AND_QUERY_SERVICE);
    ch = service.getCharacteristic(COMMAND_CHAR);
    try {
      ch.requestWrite(finalCommand, {
        :writeType => Ble.WRITE_TYPE_DEFAULT,
      });
    } catch (ex) {
      debug("can't send command " + finalCommand, false);
    }
  }

  function sendQuery(query) {
    var service;
    var ch;

    if (device == null) {
      debug("sendQuery: not connected", true);
      return;
    }

    debug("sendQuery " + commands.get(query) + "now !", false);
    service = device.getService(CONTROL_AND_QUERY_SERVICE);
    ch = service.getCharacteristic(QUERY_CHAR);
    try {
      ch.requestWrite(commands.get(query), {
        :writeType => Ble.WRITE_TYPE_DEFAULT,
      });
    } catch (ex) {
      debug("can't send query " + commands.get(query), false);
    }
  }

  function keepalive() {
    sendCommand("KEEPALIVE", null);
  }

  function onCharacteristicWrite(ch, value) {
    debug("char write " + ch.getUuid() + " " + value, false);
    if (!settingsSubscribed) {
      sendQuery("SETTINGS_UPDATES");
      settingsSubscribed = true;
    } else if (!presetListFetched) {
      sendQuery("PRESET_LIST");
      presetListFetched = true;
    }
  }

  function onCharacteristicChanged(ch, value) {
    debug("char changed " + ch.getUuid() + " " + value, false);
    if (ch.getUuid().equals(COMMAND_NOTIFICATION)) {
    } else if (ch.getUuid().equals(QUERY_NOTIFICATION)) {
      queryResponsesQueue.add(value);
    }
  }

  function onDescriptorWrite(desc, value) {
    debug("descriptor write " + desc.getUuid() + " " + value, false);
    if (!commandNotificationsEnabled) {
      commandNotificationsEnabled = true;
      info("command enabled, enabling notifications for QUERY");
      enableNotifications(QUERY_NOTIFICATION);
    } else if (!queryNotificationsEnabled) {
      queryNotificationsEnabled = true;
      info("query enabled, enabling notifications for SETTINGS");
      enableNotifications(SETTINGS_NOTIFICATION);
    } else if (!settingsNotificationsEnabled) {
      settingsNotificationsEnabled = true;
      info("all notifications enabled");
      connectionStatus = STATUS_CONNECTED;
      sendQuery("VALUES_UPDATES");
    }
  }

  function enableNotifications(characteristic) {
    var service;
    var command;
    var desc;

    if (device == null) {
      debug("setNotifications: not connected", true);
      return;
    }
    debug("setNotifications", true);

    service = device.getService(CONTROL_AND_QUERY_SERVICE);

    command = service.getCharacteristic(characteristic);
    desc = command.getDescriptor(CONTROL_AND_QUERY_DESC);
    desc.requestWrite([0x01, 0x00]b);
    debug("Notifications requested for " + characteristic, false);
  }

  function onProfileRegister(uuid, status) {
    profileRegistered = true;
    debug("registered: " + uuid + " " + status, true);
  }

  function registerProfiles() {
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

  function onScanStateChange(scanState, status) {
    debug("scanstate: " + scanState + " " + status, true);
    if (scanState == Ble.SCAN_STATE_SCANNING) {
      info("Starting scanning for GoPro");
      scanning = true;
    } else {
      scanning = false;
    }
  }

  function onEncryptionStatus(device, status) {
    info("device paired successfully !");
    debug("bonded: " + device.getName() + " " + status, true);
    if (status == Ble.STATUS_SUCCESS) {
      Application.Storage.setValue("paired", true);
      enableNotifications(COMMAND_NOTIFICATION);
    }
  }

  function onConnectedStateChanged(device, state) {
    if (device.getName() != null) {
      info("device connected: " + device.getName());
      debug(device.getName() + " " + state, true);
    }
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
    debug("connect", true);
    Ble.setScanState(Ble.SCAN_STATE_OFF);
    var ld = Ble.pairDevice(result);
    return ld;
  }

  private function dumpUuids(iter) {
    for (var x = iter.next(); x != null; x = iter.next()) {}
  }

  function onScanResults(scanResults) {
    //debug("scan results");
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
        var seenDevice = Lang.format("uuid: $1$, name: $2$", [x, name]);
        if (
          seenDevices.indexOf(seenDevice) == -1 &&
          x.equals(CONTROL_AND_QUERY_SERVICE)
        ) {
          seenDevices.add(seenDevice);
          debug(seenDevices, true);
        }

        if (
          pairingDevice == null &&
          x.equals(PAIR_SERVICE) &&
          name != null &&
          name.equals("GoPro Cam")
        ) {
          pairingDevice = result;
        }

        if (shouldConnect && x.equals(CONTROL_AND_QUERY_SERVICE)) {
          if (
            name != null &&
            name.find("GoPro") != null &&
            foundCameraIDs.indexOf(name) == -1
          ) {
            foundCameraIDs.add(name);
          }
          if (
            Application.Storage.getValue("paired") != null &&
            Application.Storage.getValue("paired") &&
            name != null
          ) {
            if (
              cameraID != null &&
              name.equals("GoPro " + cameraID.format("%04d"))
            ) {
              debug("found matching device. uuid: " + x, false);
              info("Found device with name: " + name);

              info("connecting to camera with id:" + cameraID.format("%04d"));
              connectionStatus = STATUS_CONNECTING;
              connect(result);
              return;
            }
          } else if (pairingDevice != null) {
            info("pairing camera for the first time");
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
    debug("close", true);
    if (scanning) {
      Ble.setScanState(Ble.SCAN_STATE_OFF);
    }
    if (device) {
      Ble.unpairDevice(device);
    }
  }
}
