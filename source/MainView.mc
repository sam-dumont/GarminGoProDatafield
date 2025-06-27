import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.BluetoothLowEnergy as Ble;
import Toybox.System;

class MainView extends WatchUi.DataField {
  var layout as Layout;
  var narrowDc;
  var shortDc;
  var backgroundColor;
  var foregroundColor;
  var screenCoordinates;
  var tick = 0;
  var tapTick = 0;
  var enableDebug = false;
  var gopro;
  var altitude = 0;
  var shouldConnect = false;
  var drawTap = false;
  var tapCoordinates = [0, 0];
  var keepalive = false;
  var autoStop = false;
  var isSmallLayout = false;
  var reducedViewTick = 0;

  function initialize(gopro as Ble.BleDelegate, screenCoordinates) {
    DataField.initialize();
    layout = new Layout(0);
    self.gopro = gopro;
    self.screenCoordinates = screenCoordinates;
    keepalive = Util.replaceNull(
      Application.Properties.getValue("keepalive"),
      false
    );
    autoStop = Util.replaceNull(
      Application.Properties.getValue("auto_stop"),
      false
    );
    gopro.parseQueryResponse();
  }

  function onPeriodicUpdate() {
    WatchUi.requestUpdate();
  }

  function onHide() {
    DataField.onHide();
  }

  function onLayout(dc as Dc) as Void {
    dc.setAntiAlias(true);
    narrowDc = dc.getWidth() <= System.getDeviceSettings().screenWidth / 2;
    shortDc = dc.getHeight() < System.getDeviceSettings().screenHeight / 2.5;
  }

  function onTimerStart() {
    if (autoStop && !gopro.recording && gopro.mode != GoPro.MODE_PHOTO) {
      gopro.sendCommand("SHUTTER_ON", null);
    }
  }

  function onTimerResume() {
    gopro.open();
  }

  function onTimerReset() {
    gopro.close();
  }

  function onTimerStop() {
    if (autoStop && gopro.recording && gopro.mode != GoPro.MODE_PHOTO) {
      gopro.sendCommand("SHUTTER_OFF", null);
    }
    gopro.close();
  }

  function onTimerPause() {
    if (autoStop && gopro.recording && gopro.mode != GoPro.MODE_PHOTO) {
      gopro.sendCommand("SHUTTER_OFF", null);
    }
    gopro.close();
  }

  function setTapCoordinates(coordinates) {
    drawTap = true;
    tapCoordinates = coordinates;
    tapTick = tick;
  }

  function compute(info as Activity.Info) as Void {
    shouldConnect = gopro.shouldConnect;
    gopro.accumulateQueryResponses();
    gopro.accumulateCommandResponses();
    if (gopro.presetGroups != null) {
      gopro.presetGroups.parse();
    }
    tick = (tick + 1) % 15;
    if (
      gopro.connectionStatus == GoPro.STATUS_CONNECTED &&
      tick == 0 &&
      keepalive
    ) {
      gopro.keepalive();
    }
    if (gopro.recording) {
      gopro.remainingTimeDelta += 1;
    } else {
      gopro.remainingTimeDelta = 0;
    }
  }

  function onUpdate(dc as Dc) as Void {
    var height = dc.getHeight();
    var width = dc.getWidth();
    var screenHeight = System.getDeviceSettings().screenHeight;
    var screenWidth = System.getDeviceSettings().screenWidth;
    // At the top of onUpdate, increment reducedViewTick for blinking
    if (height < screenHeight) {
      reducedViewTick = (reducedViewTick + 1) % 6; // 6 seconds cycle
    }

    backgroundColor = DataField.getBackgroundColor();
    foregroundColor = backgroundColor == 16777215 ? 0 : 16777215; //BLACK // WHITE

    // Force connected state in simulation mode for UI testing
    if (gopro.SIMULATION_MODE) {
      gopro.connectionStatus = GoPro.STATUS_CONNECTED;
      if (gopro.cameraID == null || gopro.cameraID == 0) {
        gopro.cameraID = 1;
      }
      gopro.hasBeenConnected = true;
      // Remove fake preset injection: rely on real presetGroups
      // Fallback: if modeId is missing in video mode, use first available
      if (gopro.presetGroups != null && gopro.presetGroups.presets != null) {
        var videoPresets = gopro.presetGroups.presets[GoPro.MODE_VIDEO];
        if (videoPresets != null && videoPresets[gopro.modeId] == null) {
          // Use first available preset in video mode
          var keys = videoPresets.keys();
          if (keys.size() > 0) {
            gopro.modeId = keys[0];
          }
        }
      }
    }

    if (!shouldConnect) {
      layout.setLayout(dc, -1);
      dc.setColor(foregroundColor, foregroundColor);
      dc.fillRectangle(width * 0.2, height * 0.3, width * 0.6, height * 0.4);
      dc.setColor(foregroundColor, backgroundColor);
      layout.durationText.setColor(backgroundColor);
      layout.durationText.setBackgroundColor(foregroundColor);
      var connectText = gopro.asleep ? "RECONNECT" : "CONNECT";
      layout.durationText.setText(
        Lang.format("$1$ TO GOPRO $2$", [
          connectText,
          gopro.cameraID.format("%04d"),
        ])
      );
      screenCoordinates.connectButton = [
        [width * 0.2, width * 0.8],
        [height * 0.3, height * 0.7],
      ];
    } else if (gopro.connectionStatus != GoPro.STATUS_CONNECTED) {
      layout.setLayout(dc, 0);
      layout.durationText.setColor(foregroundColor);
      if (gopro.asleep) {
        layout.durationText.setText(
          Lang.format("GOPRO WITH ID $1$ IS ASLEEP", [
            gopro.cameraID.format("%04d"),
          ])
        );
      } else if (gopro.connectionStatus == GoPro.STATUS_SEARCHING) {
        if (gopro.cameraID == 0) {
          var cameraPrompt = "PLEASE SET THE CAMERA ID IN CONNECT IQ SETTINGS.";
          if (gopro.foundCameraIDs.size() > 0) {
            cameraPrompt = Lang.format("$1$\nFOUND IDS: $2$", [
              cameraPrompt,
              gopro.foundCameraIDs,
            ]);
          }
          // In simulation mode, skip the prompt and force connected UI
          if (gopro.SIMULATION_MODE) {
            gopro.connectionStatus = GoPro.STATUS_CONNECTED;
          } else {
            layout.durationText.setText(cameraPrompt);
          }
        } else {
          layout.durationText.setText(
            Lang.format("SEARCHING FOR GOPRO $1$", [
              gopro.cameraID.format("%04d"),
            ])
          );
        }
      } else {
        layout.durationText.setText(
          Lang.format("CONNECTING TO GOPRO $1$", [
            gopro.cameraID.format("%04d"),
          ])
        );
      }
      layout.remainingText.setColor(foregroundColor);
      layout.remainingText.setText(""); // Remove log display
    } else {
      if (height < screenHeight) {
        isSmallLayout = true;
        screenCoordinates.touchEnabled = false;

        if (width <= screenWidth / 2) {
          layout.setLayout(dc, 3);
        } else {
          layout.setLayout(dc, 2);
        }
        layout.batteryText.setText(gopro.batteryLife + "%");
        layout.batteryText.setColor(foregroundColor);
        layout.durationText.setColor(foregroundColor);
        layout.remainingText.setText("");
        layout.remainingText.setColor(foregroundColor);
        // Show remaining time

        if (gopro.mode == GoPro.MODE_PHOTO) {
          layout.durationText.setVisible(false);
        } else {
          layout.durationText.setVisible(true);
          layout.durationText.setText(
            Util.format_duration(gopro.recordingDuration, false)
          );
        }

        if (gopro.mode == GoPro.MODE_VIDEO) {
          layout.remainingText.setText(
            Util.format_duration(
              gopro.remainingTime - gopro.remainingTimeDelta,
              true
            )
          );
        } else if (gopro.mode == GoPro.MODE_TIMELAPSE) {
          layout.remainingText.setText(
            Util.format_duration(gopro.remainingTimelapse, true)
          );
        } else if (gopro.mode == GoPro.MODE_PHOTO) {
          layout.remainingText.setText(
            gopro.remainingPhotos > 999 ? ">999" : "" + gopro.remainingPhotos
          );
        }
        layout.remainingText.setColor(foregroundColor);
        // In reduced view, set color based on system timer, but only if recording
        if (height < screenHeight && gopro.recording) {
          var nowMs = System.getTimer(); // milliseconds since device boot
          var blinkColor =
            (nowMs / 1000).toNumber() % 4 < 2
              ? Graphics.COLOR_WHITE
              : Graphics.COLOR_RED;
          layout.durationText.setColor(blinkColor);
        } else {
          layout.durationText.setColor(foregroundColor);
        }
      } else {
        isSmallLayout = false;
        layout.setLayout(dc, 1);

        layout.batteryText.setText(gopro.batteryLife + "%");
        layout.batteryText.setColor(foregroundColor);
        gopro.formatSettings();

        layout.modeText.setColor(foregroundColor);
        layout.modeText.setText(gopro.modeName);

        layout.settingsText.setText(gopro.settings);
        layout.settingsText.setColor(foregroundColor);
        screenCoordinates.touchEnabled = true;

        var modeIcon;
        var statusIcon;

        if (gopro.mode == GoPro.MODE_PHOTO) {
          layout.durationText.setVisible(false);
        } else {
          layout.durationText.setVisible(true);
          layout.durationText.setText(
            Util.format_duration(gopro.recordingDuration, false)
          );
          if (gopro.recording) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(
              dc.getWidth() * 0.2,
              dc.getHeight() * 0.325,
              dc.getHeight() * 0.0875
            );
            dc.fillCircle(
              dc.getWidth() * 0.8,
              dc.getHeight() * 0.325,
              dc.getHeight() * 0.0875
            );
            dc.fillRectangle(
              dc.getWidth() * 0.2,
              dc.getHeight() * 0.2375,
              dc.getWidth() * 0.6,
              dc.getHeight() * 0.178
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
              modeIcon = Application.loadResource(
                $.Rez.Drawables.white_hilight
              );
            } else {
              modeIcon = Application.loadResource(
                $.Rez.Drawables.black_hilight
              );
            }
          } else {
            if (backgroundColor == Graphics.COLOR_BLACK) {
              modeIcon = Application.loadResource($.Rez.Drawables.white_video);
            } else {
              modeIcon = Application.loadResource($.Rez.Drawables.black_video);
            }
          }
          layout.remainingText.setText(
            Util.format_duration(
              gopro.remainingTime - gopro.remainingTimeDelta,
              true
            )
          );
          layout.remainingText.setColor(foregroundColor);
        } else if (gopro.mode == GoPro.MODE_TIMELAPSE) {
          if (gopro.recording) {
            modeIcon = Application.loadResource($.Rez.Drawables.grey_timelapse);
          } else if (backgroundColor == Graphics.COLOR_BLACK) {
            modeIcon = Application.loadResource(
              $.Rez.Drawables.white_timelapse
            );
          } else {
            modeIcon = Application.loadResource(
              $.Rez.Drawables.black_timelapse
            );
          }
          layout.remainingText.setText(
            Util.format_duration(gopro.remainingTimelapse, true)
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
          layout.durationText.setText(gopro.recordingDuration);
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
        self.drawDeviceSpecificUI(
          dc,
          width,
          height,
          gopro,
          screenCoordinates,
          modeIcon,
          statusIcon
        );

        if (!gopro.recording) {
          if (!gopro.firstPreset || gopro.SIMULATION_MODE) {
            screenCoordinates.prevPresetButton = [
              [width * 0.02, width * 0.13],
              [height * 0.47, height * 0.58],
            ];

            dc.fillPolygon([
              [width * 0.1, height * 0.5],
              [width * 0.1, height * 0.55],
              [width * 0.05, height * 0.525],
            ]);
          } else {
            screenCoordinates.prevPresetButton = [
              [0, 0],
              [0, 0],
            ];
          }
          if (!gopro.lastPreset || gopro.SIMULATION_MODE) {
            screenCoordinates.nextPresetButton = [
              [width * 0.87, width * 0.98],
              [height * 0.47, height * 0.58],
            ];
            dc.fillPolygon([
              [width * 0.9, height * 0.5],
              [width * 0.9, height * 0.55],
              [width * 0.95, height * 0.525],
            ]);
          }
        } else {
          screenCoordinates.nextPresetButton = [
            [0, 0],
            [0, 0],
          ];
        }

        var onOffIcon = null;
        if (gopro.asleep) {
          onOffIcon = Application.loadResource($.Rez.Drawables.on);
        } else {
          onOffIcon = Application.loadResource($.Rez.Drawables.off);
        }

        if (gopro.hasBeenConnected) {
          if (onOffIcon != null) {
            dc.drawBitmap(
              width * 0.5 - onOffIcon.getWidth() / 2,
              height * 0.02,
              onOffIcon
            );
          }
          screenCoordinates.onOffButton = [
            [
              width * 0.5 - onOffIcon.getWidth() / 2,
              width * 0.5 + onOffIcon.getWidth() / 2,
            ],
            [height * 0.02, height * 0.02 + onOffIcon.getHeight()],
          ];
        } else {
          screenCoordinates.onOffButton = [
            [0, 0],
            [0, 0],
          ];
        }
      }
    }
    layout.draw(dc);
    if (!isSmallLayout) {
      if (drawTap) {
        if (tick - tapTick > 0) {
          drawTap = false;
        }
        dc.setPenWidth(3);
        dc.setColor(backgroundColor, foregroundColor);
        dc.fillCircle(
          tapCoordinates[0],
          tapCoordinates[1],
          dc.getWidth() * 0.07
        );
        dc.setColor(foregroundColor, backgroundColor);
        dc.drawCircle(
          tapCoordinates[0],
          tapCoordinates[1],
          dc.getWidth() * 0.02
        );
        dc.drawCircle(
          tapCoordinates[0],
          tapCoordinates[1],
          dc.getWidth() * 0.07
        );
      }
    }
  }

  function handleSettingsChanged() {}

  (:square)
  function drawDeviceSpecificUI(
    dc,
    width,
    height,
    gopro,
    screenCoordinates,
    modeIcon,
    statusIcon
  ) {
    if (modeIcon != null) {
      dc.drawBitmap(
        width * 0.25 - modeIcon.getWidth() / 2,
        height * 0.75,
        modeIcon
      );
    }
    if (statusIcon != null) {
      dc.drawBitmap(
        width * 0.75 - statusIcon.getWidth() / 2,
        height * 0.75,
        statusIcon
      );
    }
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
    if (!gopro.recording) {
      if (!gopro.firstPreset) {
        screenCoordinates.prevPresetButton = [
          [width * 0.02, width * 0.13],
          [height * 0.47, height * 0.58],
        ];
        dc.fillPolygon([
          [width * 0.1, height * 0.5],
          [width * 0.1, height * 0.55],
          [width * 0.05, height * 0.525],
        ]);
      } else {
        screenCoordinates.prevPresetButton = [
          [0, 0],
          [0, 0],
        ];
      }
      if (!gopro.lastPreset) {
        screenCoordinates.nextPresetButton = [
          [width * 0.87, width * 0.98],
          [height * 0.47, height * 0.58],
        ];
        dc.fillPolygon([
          [width * 0.9, height * 0.5],
          [width * 0.9, height * 0.55],
          [width * 0.95, height * 0.525],
        ]);
      }
    } else {
      screenCoordinates.nextPresetButton = [
        [0, 0],
        [0, 0],
      ];
    }
    var onOffIcon = null;
    if (gopro.asleep) {
      onOffIcon = Application.loadResource($.Rez.Drawables.on);
    } else {
      onOffIcon = Application.loadResource($.Rez.Drawables.off);
    }
    if (gopro.hasBeenConnected) {
      if (onOffIcon != null) {
        dc.drawBitmap(
          width * 0.5 - onOffIcon.getWidth() / 2,
          height * 0.02,
          onOffIcon
        );
      }
      screenCoordinates.onOffButton = [
        [
          width * 0.5 - onOffIcon.getWidth() / 2,
          width * 0.5 + onOffIcon.getWidth() / 2,
        ],
        [height * 0.02, height * 0.02 + onOffIcon.getHeight()],
      ];
    } else {
      screenCoordinates.onOffButton = [
        [0, 0],
        [0, 0],
      ];
    }
  }

  (:round)
  function drawDeviceSpecificUI(
    dc,
    width,
    height,
    gopro,
    screenCoordinates,
    modeIcon,
    statusIcon
  ) {
    if (modeIcon != null) {
      dc.drawBitmap(
        width * 0.35 - modeIcon.getWidth() / 2,
        height * 0.73,
        modeIcon
      );
    }
    if (statusIcon != null) {
      dc.drawBitmap(
        width * 0.65 - statusIcon.getWidth() / 2,
        height * 0.73,
        statusIcon
      );
    }
    screenCoordinates.modeButton = [
      [
        width * 0.35 - modeIcon.getWidth() / 2,
        width * 0.35 + modeIcon.getWidth() / 2,
      ],
      [height * 0.73, height * 0.73 + modeIcon.getHeight()],
    ];
    screenCoordinates.recordButton = [
      [
        width * 0.65 - statusIcon.getWidth() / 2,
        width * 0.65 + statusIcon.getWidth() / 2,
      ],
      [height * 0.73, height * 0.73 + statusIcon.getHeight()],
    ];
    if (!gopro.recording) {
      if (!gopro.firstPreset) {
        screenCoordinates.prevPresetButton = [
          [width * 0.02, width * 0.13],
          [height * 0.47, height * 0.58],
        ];
        dc.fillPolygon([
          [width * 0.1, height * 0.5],
          [width * 0.1, height * 0.55],
          [width * 0.05, height * 0.525],
        ]);
      } else {
        screenCoordinates.prevPresetButton = [
          [0, 0],
          [0, 0],
        ];
      }
      if (!gopro.lastPreset) {
        screenCoordinates.nextPresetButton = [
          [width * 0.87, width * 0.98],
          [height * 0.47, height * 0.58],
        ];
        dc.fillPolygon([
          [width * 0.9, height * 0.5],
          [width * 0.9, height * 0.55],
          [width * 0.95, height * 0.525],
        ]);
      }
    } else {
      screenCoordinates.nextPresetButton = [
        [0, 0],
        [0, 0],
      ];
    }
    var onOffIcon = null;
    if (gopro.asleep) {
      onOffIcon = Application.loadResource($.Rez.Drawables.on);
    } else {
      onOffIcon = Application.loadResource($.Rez.Drawables.off);
    }
    if (gopro.hasBeenConnected) {
      if (onOffIcon != null) {
        dc.drawBitmap(
          width * 0.5 - onOffIcon.getWidth() / 2,
          height * 0.02,
          onOffIcon
        );
      }
      screenCoordinates.onOffButton = [
        [
          width * 0.5 - onOffIcon.getWidth() / 2,
          width * 0.5 + onOffIcon.getWidth() / 2,
        ],
        [height * 0.02, height * 0.02 + onOffIcon.getHeight()],
      ];
    } else {
      screenCoordinates.onOffButton = [
        [0, 0],
        [0, 0],
      ];
    }
  }
}
