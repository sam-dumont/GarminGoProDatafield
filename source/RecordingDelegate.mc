using Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;

class RecordingDelegate extends WatchUi.BehaviorDelegate {
  var screenCoordinates;
  var gopro;
  var mainView;

  function initialize(gopro, screenCoordinates, mainView) {
    BehaviorDelegate.initialize();
    self.screenCoordinates = screenCoordinates;
    self.gopro = gopro;
    self.mainView = mainView;
  }

  function withinBoundaries(coordinates, buttonCoordinates) {
    return (
      coordinates[0] > buttonCoordinates[0][0] &&
      coordinates[0] < buttonCoordinates[0][1] &&
      coordinates[1] > buttonCoordinates[1][0] &&
      coordinates[1] < buttonCoordinates[1][1]
    );
  }

  function onTap(clickEvent) {
    var coordinates = clickEvent.getCoordinates();
    mainView.setTapCoordinates(coordinates);
    if (
      withinBoundaries(coordinates, screenCoordinates.connectButton) &&
      !gopro.shouldConnect
    ) {
      gopro.shouldConnect = true;
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
      var newPreset = gopro.getPrevNextPresetID(true);
      System.println("Will send preset " + newPreset);
      if (newPreset != -1) {
        var args = [0, 0, 0, 0]b.encodeNumber(
          gopro.getPrevNextPresetID(true),
          NUMBER_FORMAT_UINT32,
          { :offset => 0, :endianness => ENDIAN_BIG }
        );
        System.println(args);
        gopro.sendCommand("PRESET_ID", args);
      }
    } else if (
      withinBoundaries(coordinates, screenCoordinates.prevPresetButton) &&
      !gopro.recording
    ) {
      var newPreset = gopro.getPrevNextPresetID(false);
      System.println("Will send preset " + newPreset);
      if (newPreset != -1) {
        var args = [0, 0, 0, 0]b.encodeNumber(newPreset, NUMBER_FORMAT_UINT32, {
          :offset => 0,
          :endianness => ENDIAN_BIG,
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
