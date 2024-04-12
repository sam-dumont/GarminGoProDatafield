import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.BluetoothLowEnergy as Ble;

class GarminGoProWidgetApp extends Application.AppBase {
  hidden var gopro;
  hidden var screenCoordinates;

  function initialize() {
    AppBase.initialize();
  }

  // onStart() is called on application start up
  function onStart(state as Dictionary?) as Void {
    gopro = new GoPro();
    screenCoordinates = new ScreenCoordinates();
    Ble.setDelegate(gopro);
    gopro.open();
  }

  // onStop() is called when your application is exiting
  function onStop(state as Dictionary?) as Void {
    if (gopro.device != null) {
      gopro.close();
      Ble.unpairDevice(gopro.device);
    }
  }

  // Return the initial view of your application here
  function getInitialView() as Array<Views or InputDelegates>? {
    return (
      [new MainView(gopro,screenCoordinates),new RecordingDelegate(gopro,screenCoordinates)] as Array<Views or InputDelegates>
    );
  }
}
