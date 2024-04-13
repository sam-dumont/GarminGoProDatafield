using Toybox.WatchUi;
import Toybox.System;

class RecordingDelegate extends WatchUi.BehaviorDelegate {
  var screenCoordinates;
  var gopro;

  function initialize(gopro, screenCoordinates) {
    BehaviorDelegate.initialize();
    self.screenCoordinates = screenCoordinates;
    self.gopro = gopro;
  }

  function withinBoundaries(coordinates, buttonCoordinates) {
    if (
      coordinates[0] > buttonCoordinates[0][0] &&
      coordinates[0] < buttonCoordinates[0][1] &&
      coordinates[1] > buttonCoordinates[1][0] &&
      coordinates[0] < buttonCoordinates[1][1]
    ) {
      return true;
    } else {
      return false;
    }
  }

  function onTap(clickEvent) {
    var coordinates = clickEvent.getCoordinates();

    if (
      withinBoundaries(coordinates, screenCoordinates.modeButton) &&
      !gopro.recording
    ) {
      System.println("MODE BUTTON");
      if (gopro.mode == GoPro.MODE_VIDEO) {
        gopro.sendCommand("PRESET_PHOTO");
      } else if (gopro.mode == GoPro.MODE_PHOTO) {
        gopro.sendCommand("PRESET_TIMELAPSE");
      } else {
        gopro.sendCommand("PRESET_VIDEO");
      }
    } else if (withinBoundaries(coordinates, screenCoordinates.recordButton)) {
      System.println("RECORD BUTTON");
      if (gopro.recording) {
        gopro.sendCommand("SHUTTER_OFF");
      } else {
        gopro.sendCommand("SHUTTER_ON");
      }
    } else {
      "NO BUTTON";
    }

    return true;
  }
}
