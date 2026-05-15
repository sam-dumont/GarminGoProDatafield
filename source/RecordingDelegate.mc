using Toybox.WatchUi;
using Toybox.System;
using Toybox.Lang;
using Toybox.Application;
using Toybox.BluetoothLowEnergy as Ble;

class RecordingDelegate extends WatchUi.InputDelegate {
  var screenCoordinates as ScreenCoordinates;
  var gopro as GoPro;
  var mainView as MainView;

  function initialize(gopro as GoPro, screenCoordinates as ScreenCoordinates, mainView as MainView) {
    InputDelegate.initialize();
    self.screenCoordinates = screenCoordinates;
    self.gopro = gopro;
    self.mainView = mainView;
  }

  // buttonCoordinates is [[xMin, xMax], [yMin, yMax]] — see ScreenCoordinates.
  function withinBoundaries(coordinates as Lang.Array<Lang.Number>, buttonCoordinates as Lang.Array<Lang.Array<Lang.Numeric>>) as Lang.Boolean {
    return (
      coordinates[0] > buttonCoordinates[0][0] &&
      coordinates[0] < buttonCoordinates[0][1] &&
      coordinates[1] > buttonCoordinates[1][0] &&
      coordinates[1] < buttonCoordinates[1][1]
    );
  }

  function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
    if (screenCoordinates.touchEnabled == false) {
      return true; // Ignore tap if touch is disabled
    }
    var coordinates = clickEvent.getCoordinates() as Lang.Array<Lang.Number>;
    mainView.setTapCoordinates(coordinates);
    if (
      withinBoundaries(coordinates, screenCoordinates.connectButton) &&
      !gopro.shouldConnect
    ) {
      gopro.shouldConnect = true;
      var paired = Application.Storage.getValue($.PAIRED_SCAN_RESULT) as Ble.ScanResult?;
      if (paired != null) {
        Ble.pairDevice(paired);
      }
      if (gopro.asleep) {
        gopro.wakeup();
      }
    } else if (
      withinBoundaries(coordinates, screenCoordinates.modeButton) &&
      !gopro.recording
    ) {
      if (gopro.mode == GoPro.MODE_VIDEO) {
        gopro.sendCommand("PRESET_PHOTO", null);
      } else if (gopro.mode == GoPro.MODE_PHOTO) {
        gopro.sendCommand("PRESET_TIMELAPSE", null);
      } else {
        gopro.sendCommand("PRESET_VIDEO", null);
      }
    } else if (
      withinBoundaries(coordinates, screenCoordinates.modeButton) &&
      gopro.recording &&
      gopro.mode == GoPro.MODE_VIDEO
    ) {
      gopro.sendCommand("HILIGHT", null);
    } else if (withinBoundaries(coordinates, screenCoordinates.recordButton)) {
      if (gopro.recording) {
        gopro.sendCommand("SHUTTER_OFF", null);
      } else {
        gopro.sendCommand("SHUTTER_ON", null);
      }
    } else if (
      withinBoundaries(coordinates, screenCoordinates.nextPresetButton) &&
      !gopro.recording
    ) {
      var newPreset = gopro.getPrevNextPresetID(true) as Lang.Number;
      System.println("Will send preset " + newPreset);
      if (newPreset != -1) {
        var args = ([0, 0, 0, 0]b).encodeNumber(
          newPreset,
          Lang.NUMBER_FORMAT_UINT32,
          { :offset => 0, :endianness => Lang.ENDIAN_BIG }
        );
        System.println(args);
        gopro.sendCommand("PRESET_ID", args);
      }
    } else if (
      withinBoundaries(coordinates, screenCoordinates.prevPresetButton) &&
      !gopro.recording
    ) {
      var newPreset = gopro.getPrevNextPresetID(false) as Lang.Number;
      System.println("Will send preset " + newPreset);
      if (newPreset != -1) {
        var args = ([0, 0, 0, 0]b).encodeNumber(newPreset, Lang.NUMBER_FORMAT_UINT32, {
          :offset => 0,
          :endianness => Lang.ENDIAN_BIG,
        });
        System.println(args);
        gopro.sendCommand("PRESET_ID", args);
      }
    } else if (withinBoundaries(coordinates, screenCoordinates.onOffButton)) {
      if (gopro.asleep) {
        gopro.wakeup();
      } else {
        gopro.sleep();
      }
    }
    return true;
  }
}
