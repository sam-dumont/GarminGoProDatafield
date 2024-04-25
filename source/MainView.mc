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
  hidden var tick = 0;
  hidden var enableDebug = false;
  var gopro;
  hidden var altitude = 0;
  hidden var shouldConnect = false;

  function initialize(gopro as Ble.BleDelegate, screenCoordinates) {
    DataField.initialize();
    layout = new Layout(0);
    self.gopro = gopro;
    self.screenCoordinates = screenCoordinates;
    enableDebug = Util.replaceNull(
      Application.Properties.getValue("enable_debug"),
      false
    );
    gopro.parseQueryResponse();
  }

  function onLayout(dc as Dc) as Void {
    dc.setAntiAlias(true);
    narrowDc = dc.getWidth() <= System.getDeviceSettings().screenWidth / 2;
    shortDc = dc.getHeight() < System.getDeviceSettings().screenHeight / 2.5;
  }

  function onTimerStart() {}

  function onTimerResume() {
    gopro.open();
  }

  function onTimerReset() {
    gopro.close();
  }

  function onTimerStop() {
    gopro.close();
  }

  function onTimerPause() {
    gopro.close();
  }

  function compute(info as Activity.Info) as Void {
    shouldConnect = gopro.shouldConnect;
    gopro.accumulateQueryResponses();
    if (gopro.presetGroups != null) {
      gopro.presetGroups.parse();
    }
    tick = (tick + 1) % 15;
    if (gopro.connectionStatus == GoPro.STATUS_CONNECTED && tick == 0) {
      gopro.keepalive();
    }
    if (gopro.recording) {
      gopro.remainingTimeDelta += 1;
    } else {
      gopro.remainingTimeDelta = 0;
    }
  }

  // Display the value you computed here. This will be called
  // once a second when the data field is visible.
  function onUpdate(dc as Dc) as Void {
    backgroundColor = DataField.getBackgroundColor();
    foregroundColor = backgroundColor == 16777215 ? 0 : 16777215; //BLACK // WHITE
    var height = dc.getHeight();
    var width = dc.getWidth();

    if (!shouldConnect) {
      layout.setLayout(dc, -1);
      dc.setColor(foregroundColor, foregroundColor);
      dc.fillRectangle(width * 0.2, height * 0.3, width * 0.6, height * 0.4);
      dc.setColor(foregroundColor, backgroundColor);
      layout.durationText.setColor(backgroundColor);
      layout.durationText.setBackgroundColor(foregroundColor);
      layout.durationText.setText(
        Lang.format("CONNECT TO GOPRO ", [gopro.cameraID])
      );
      screenCoordinates.connectButton = [
        [width * 0.2, width * 0.8],
        [height * 0.3, height * 0.7],
      ];
    } else if (gopro.connectionStatus != GoPro.STATUS_CONNECTED) {
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
        enableDebug
          ? Lang.format("$1$\n$2$\n$3$", [
              gopro.logs[0],
              gopro.logs[1],
              gopro.logs[2],
            ])
          : ""
      );
    } else {
      layout.setLayout(dc, 1);

      layout.batteryText.setText(gopro.batteryLife + "%");
      layout.batteryText.setColor(foregroundColor);
      gopro.formatSettings();

      layout.modeText.setColor(foregroundColor);
      var modeText = gopro.modeName;
      if (enableDebug) {
        modeText = Lang.format("$2$\n$3$\n$4$", [
          gopro.logs[0],
          gopro.logs[1],
          gopro.logs[2],
        ]);
      }
      layout.modeText.setText(modeText);

      layout.settingsText.setText(gopro.settings);
      layout.settingsText.setColor(foregroundColor);

      var modeIcon;
      var statusIcon;

      if (gopro.mode == GoPro.MODE_PHOTO) {
        layout.durationText.setVisible(false);
      } else {
        layout.durationText.setVisible(true);
        layout.durationText.setText(
          Util.format_duration(gopro.recordingDuration)
        );
        if (gopro.recording) {
          dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
          dc.fillCircle(
            dc.getWidth() * 0.15,
            dc.getHeight() * 0.325,
            dc.getHeight() * 0.0875
          );
          dc.fillCircle(
            dc.getWidth() * 0.85,
            dc.getHeight() * 0.325,
            dc.getHeight() * 0.0875
          );
          dc.fillRectangle(
            dc.getWidth() * 0.15,
            dc.getHeight() * 0.2375,
            dc.getWidth() * 0.7,
            dc.getHeight() * 0.176
          );
          layout.durationText.setColor(Graphics.COLOR_WHITE);
          dc.setColor(foregroundColor, backgroundColor);
        } else {
          layout.durationText.setColor(foregroundColor);
        }
      }

      if (gopro.mode == GoPro.MODE_VIDEO) {
        if (gopro.recording) {
          if (backgroundColor == Graphics.COLOR_BLACK) {
            modeIcon = Application.loadResource($.Rez.Drawables.white_hilight);
          } else {
            modeIcon = Application.loadResource($.Rez.Drawables.black_hilight);
          }
        } else {
          if (backgroundColor == Graphics.COLOR_BLACK) {
            modeIcon = Application.loadResource($.Rez.Drawables.white_video);
          } else {
            modeIcon = Application.loadResource($.Rez.Drawables.black_video);
          }
        }
        layout.remainingText.setText(
          Util.format_duration(gopro.remainingTime - gopro.remainingTimeDelta)
        );
        layout.remainingText.setColor(foregroundColor);
      } else if (gopro.mode == GoPro.MODE_TIMELAPSE) {
        if (gopro.recording) {
          modeIcon = Application.loadResource($.Rez.Drawables.grey_timelapse);
        } else if (backgroundColor == Graphics.COLOR_BLACK) {
          modeIcon = Application.loadResource($.Rez.Drawables.white_timelapse);
        } else {
          modeIcon = Application.loadResource($.Rez.Drawables.black_timelapse);
        }
        layout.remainingText.setText(
          Util.format_duration(gopro.remainingTimelapse)
        );
        layout.remainingText.setColor(foregroundColor);
      } else if (gopro.mode == GoPro.MODE_PHOTO) {
        if (gopro.recording) {
          modeIcon = Application.loadResource($.Rez.Drawables.grey_photo);
        } else if (backgroundColor == Graphics.COLOR_BLACK) {
          modeIcon = Application.loadResource($.Rez.Drawables.white_photo);
        } else {
          modeIcon = Application.loadResource($.Rez.Drawables.black_photo);
        }
        layout.remainingText.setText(
          gopro.remainingPhotos > 999 ? ">999" : "" + gopro.remainingPhotos
        );
        layout.remainingText.setColor(foregroundColor);
      }

      if (gopro.recording) {
        statusIcon =
          backgroundColor == Graphics.COLOR_BLACK
            ? Application.loadResource($.Rez.Drawables.white_stop)
            : Application.loadResource($.Rez.Drawables.black_stop);
      } else {
        statusIcon =
          backgroundColor == Graphics.COLOR_BLACK
            ? Application.loadResource($.Rez.Drawables.white_record)
            : Application.loadResource($.Rez.Drawables.black_record);
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

  function handleSettingsChanged() {
    enableDebug = Util.replaceNull(
      Application.Properties.getValue("enable_debug"),
      false
    );
  }
}
