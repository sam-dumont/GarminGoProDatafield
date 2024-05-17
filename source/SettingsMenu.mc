import Toybox.WatchUi;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Application.Storage;

class SettingsMenu extends WatchUi.Menu2 {
  function initialize() {
    Menu2.initialize(null);
    Menu2.setTitle("Settings");

    Menu2.addItem(
      new WatchUi.ToggleMenuItem(
        "Enable Debug",
        null,
        "debug",
        Util.replaceNull(
          Application.Properties.getValue("enable_debug"),
          false
        ),
        null
      )
    );

    Menu2.addItem(
      new WatchUi.ToggleMenuItem(
        "Send Debug Logs",
        null,
        "send_logs",
        Util.replaceNull(Application.Properties.getValue("send_logs"), false),
        null
      )
    );
  }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
  function initialize() {
    Menu2InputDelegate.initialize();
  }

  function onSelect(item) {
    var id = item.getId();
    if (id.equals("debug")) {
      Application.Properties.setValue(
        "enable_debug",
        !Util.replaceNull(
          Application.Properties.getValue("enable_debug"),
          false
        )
      );
    } else if (id.equals("send_logs")) {
      Application.Properties.setValue(
        "send_logs",
        !Util.replaceNull(Application.Properties.getValue("send_logs"), false)
      );
    }
  }

  function onBack() {
    WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    return false;
  }
}
