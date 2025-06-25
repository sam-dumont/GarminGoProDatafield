import Toybox.WatchUi;
import Toybox.Graphics;

class Layout {
  var layoutType;
  var fonts;
  var durationText;
  var remainingText;
  var batteryText;
  var modeText;
  var settingsText;

  function initialize(layoutType) {
    layoutType = layoutType;
    fonts = [
      Graphics.FONT_TINY,
      Graphics.FONT_SMALL,
      Graphics.FONT_MEDIUM,
      Graphics.FONT_LARGE,
      Graphics.FONT_NUMBER_HOT,
      Graphics.FONT_NUMBER_THAI_HOT,
    ];

    durationText = new WatchUi.TextArea({
      :text => "00:09",
      :color => Graphics.COLOR_WHITE,
      :font => [fonts[3], fonts[2], fonts[1], fonts[0]],
      :locX => 0,
      :locY => 0,
      :justification => Graphics.TEXT_JUSTIFY_CENTER |
      Graphics.TEXT_JUSTIFY_VCENTER,
      :width => 0,
      :height => 0,
      :visible => true,
    });

    remainingText = new WatchUi.TextArea({
      :text => "9H:59",
      :color => Graphics.COLOR_WHITE,
      :font => [fonts[1], fonts[0]],
      :locX => 0,
      :locY => 0,
      :justification => Graphics.TEXT_JUSTIFY_CENTER |
      Graphics.TEXT_JUSTIFY_VCENTER,
      :width => 0,
      :height => 0,
      :visible => true,
    });

    batteryText = new WatchUi.TextArea({
      :text => "100%",
      :color => Graphics.COLOR_WHITE,
      :font => [fonts[1], fonts[0]],
      :locX => 0,
      :locY => 0,
      :justification => Graphics.TEXT_JUSTIFY_CENTER |
      Graphics.TEXT_JUSTIFY_VCENTER,
      :width => 0,
      :height => 0,
      :visible => false,
    });

    modeText = new WatchUi.TextArea({
      :text => "Cinematic",
      :color => Graphics.COLOR_WHITE,
      :font => [fonts[1], fonts[0]],
      :locX => 0,
      :locY => 0,
      :justification => Graphics.TEXT_JUSTIFY_CENTER |
      Graphics.TEXT_JUSTIFY_VCENTER,
      :width => 0,
      :height => 0,
      :visible => true,
    });

    settingsText = new WatchUi.TextArea({
      :text => "4K | 30 | L+",
      :color => Graphics.COLOR_WHITE,
      :font => [fonts[1], fonts[0]],
      :locX => 0,
      :locY => 0,
      :justification => Graphics.TEXT_JUSTIFY_CENTER |
      Graphics.TEXT_JUSTIFY_VCENTER,
      :width => 0,
      :height => 0,
      :visible => true,
    });
  }

  function setLayout(dc, newLayoutType) {
    var width = dc.getWidth();
    var height = dc.getHeight();
    layoutType = newLayoutType;
    if (layoutType == -1) {
      durationText.initialize({
        :text => "CONNECT",
        :color => Graphics.COLOR_WHITE,
        :backgroundColor => Graphics.COLOR_BLACK,
        :font => [fonts[5], fonts[4], fonts[3], fonts[2], fonts[1], fonts[0]],
        :locX => width * 0.2,
        :locY => height * 0.3,
        :justification => Graphics.TEXT_JUSTIFY_CENTER |
        Graphics.TEXT_JUSTIFY_VCENTER,
        :width => width * 0.6,
        :height => height * 0.4,
        :visible => true,
      });
      remainingText.setVisible(false);
      batteryText.setVisible(false);
      modeText.setVisible(false);
      settingsText.setVisible(false);
    } else if (layoutType == 0) {
      durationText.initialize({
        :text => "00:09",
        :color => Graphics.COLOR_WHITE,
        :font => [fonts[5], fonts[4], fonts[3], fonts[2], fonts[1], fonts[0]],
        :locX => width * 0.1,
        :locY => height * 0.1,
        :justification => Graphics.TEXT_JUSTIFY_CENTER |
        Graphics.TEXT_JUSTIFY_VCENTER,
        :width => width * 0.8,
        :height => height * 0.6,
        :visible => true,
      });
      remainingText.initialize({
        :text => "00:09",
        :color => Graphics.COLOR_WHITE,
        :font => [fonts[5], fonts[4], fonts[3], fonts[2], fonts[1], fonts[0]],
        :locX => width * 0.1,
        :locY => height * 0.7,
        :justification => Graphics.TEXT_JUSTIFY_CENTER |
        Graphics.TEXT_JUSTIFY_VCENTER,
        :width => width * 0.8,
        :height => height * 0.3,
        :visible => true,
      });
      batteryText.setVisible(false);
      modeText.setVisible(false);
      settingsText.setVisible(false);
    } else if (layoutType == 1) {
      durationText.initialize({
        :text => "00:09",
        :color => Graphics.COLOR_WHITE,
        :font => [fonts[5], fonts[4], fonts[3], fonts[2], fonts[1], fonts[0]],
        :locX => 0,
        :locY => height * 0.15,
        :justification => Graphics.TEXT_JUSTIFY_CENTER |
        Graphics.TEXT_JUSTIFY_VCENTER,
        :width => width,
        :height => height * 0.45,
        :visible => true,
      });

      remainingText.initialize({
        :text => "9H:59",
        :color => Graphics.COLOR_WHITE,
        :font => [fonts[3], fonts[2], fonts[1], fonts[0]],
        :locX => width * 0.05,
        :locY => height * 0.05,
        :justification => Graphics.TEXT_JUSTIFY_LEFT,
        :width => width * 0.45,
        :height => height * 0.15,
        :visible => true,
      });

      batteryText.initialize({
        :text => "100%",
        :color => Graphics.COLOR_WHITE,
        :font => [fonts[3], fonts[2], fonts[1], fonts[0]],
        :locX => width * 0.5,
        :locY => height * 0.05,
        :justification => Graphics.TEXT_JUSTIFY_RIGHT,
        :width => width * 0.45,
        :height => height * 0.15,
        :visible => true,
      });

      modeText = new WatchUi.TextArea({
        :text => "Cinematic",
        :color => Graphics.COLOR_WHITE,
        :font => [fonts[3], fonts[2], fonts[1], fonts[0]],
        :locX => 0,
        :locY => height * 0.45,
        :justification => Graphics.TEXT_JUSTIFY_CENTER |
        Graphics.TEXT_JUSTIFY_VCENTER,
        :width => width,
        :height => height * 0.20,
        :visible => true,
      });

      settingsText.initialize({
        :text => "4K | 30 | L+",
        :color => Graphics.COLOR_WHITE,
        :font => [fonts[3], fonts[2], fonts[1], fonts[0]],
        :locX => 0,
        :locY => height * 0.6,
        :justification => Graphics.TEXT_JUSTIFY_CENTER |
        Graphics.TEXT_JUSTIFY_VCENTER,
        :width => width,
        :height => height * 0.15,
        :visible => true,
      });
    }
  }

  function draw(dc) {
    durationText.draw(dc);
    remainingText.draw(dc);
    batteryText.draw(dc);
    modeText.draw(dc);
    settingsText.draw(dc);
  }
}