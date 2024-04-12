import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.BluetoothLowEnergy as Ble;
import Toybox.System;

class MainView extends WatchUi.DataField {
  hidden var layout as Layout;
  hidden var narrowDc;
  hidden var shortDc;
  hidden var backgroundColor;
  hidden var foregroundColor;
  hidden var screenCoordinates;

  var gopro;
  hidden var altitude = 0;

  function initialize(gopro as Ble.BleDelegate, screenCoordinates) {
    DataField.initialize();
    layout = new Layout(0);
    self.gopro = gopro;
    self.screenCoordinates = screenCoordinates;
  }

  function onLayout(dc as Dc) as Void {
    dc.setAntiAlias(true);
    narrowDc = dc.getWidth() <= System.getDeviceSettings().screenWidth / 2;
    shortDc = dc.getHeight() < System.getDeviceSettings().screenHeight / 2.5;
  }

  function onTimerStart() {}

  function onTimerResume() {}

  function compute(info as Activity.Info) as Void {
    altitude = info.altitude;
  }

  // Display the value you computed here. This will be called
  // once a second when the data field is visible.
  function onUpdate(dc as Dc) as Void {
    backgroundColor = DataField.getBackgroundColor();
    foregroundColor = backgroundColor == 16777215 ? 0 : 16777215; //BLACK // WHITE
    var height = dc.getHeight();
    var width = dc.getWidth();

    if (gopro.connectionStatus != GoPro.STATUS_CONNECTED) {
      layout.setLayout(dc, 0);
      layout.durationText.setColor(foregroundColor);
      if (gopro.connectionStatus == GoPro.STATUS_SEARCHING) {
        layout.durationText.setText(
          Lang.format("SEARCHING FOR GOPRO $1$", [gopro.cameraID])
        );
      } else {
        layout.durationText.setText(
          Lang.format("CONNECTING TO GOPRO $1$", [gopro.cameraID])
        );
      }
      layout.remainingText.setColor(foregroundColor);
      layout.remainingText.setText(
        Lang.format("$1$\n$2$\n$3$", [
          gopro.logs[0],
          gopro.logs[1],
          gopro.logs[2],
        ])
      );
    } else {
      layout.setLayout(dc, 1);
      layout.durationText.setText(
        Util.format_duration(gopro.recordingDuration)
      );
      layout.durationText.setColor(foregroundColor);
      layout.remainingText.setText(Util.format_duration(gopro.remainingTime));
      layout.remainingText.setColor(foregroundColor);
      layout.batteryText.setText(gopro.batteryLife + "%");
      layout.batteryText.setColor(foregroundColor);
      layout.modeText.setText(gopro.modeName);
      layout.modeText.setColor(foregroundColor);
      layout.settingsText.setText(gopro.settings);
      layout.settingsText.setColor(foregroundColor);

      var modeIcon;
      var statusIcon;
      if (gopro.mode == GoPro.MODE_VIDEO) {
        modeIcon = Application.loadResource($.Rez.Drawables.video);
      } else if (gopro.mode == GoPro.MODE_PHOTO) {
        modeIcon = Application.loadResource($.Rez.Drawables.photo);
      } else if (gopro.mode == GoPro.MODE_TIMELAPSE) {
        modeIcon = Application.loadResource($.Rez.Drawables.timelapse);
      }

      if (gopro.recording) {
        statusIcon = Application.loadResource($.Rez.Drawables.stop);
      } else {
        statusIcon = Application.loadResource($.Rez.Drawables.record);
      }

      dc.drawBitmap(
        width * 0.25 - modeIcon.getWidth() / 2,
        height * 0.75,
        modeIcon
      );
      dc.drawBitmap(
        width * 0.75 - statusIcon.getWidth() / 2,
        height * 0.75,
        statusIcon
      );

      screenCoordinates.modeButton = [
        [
          width * 0.25 - modeIcon.getWidth() / 2,
          width * 0.25 + modeIcon.getWidth() / 2,
        ],
        [height * 0.75, height * 0.75 + modeIcon.getHeight()],
      ];

      screenCoordinates.recordButton = [
        [
          width * 0.75 - statusIcon.getWidth() / 2,
          width * 0.75 + statusIcon.getWidth() / 2,
        ],
        [height * 0.75, height * 0.75 + statusIcon.getHeight()],
      ];
    }
    layout.draw(dc);
  }
}
