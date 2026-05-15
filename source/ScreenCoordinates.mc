using Toybox.Lang;

// Hit-region rectangles for the data field's tap targets. Each button is
// [[xMin, xMax], [yMin, yMax]] — RecordingDelegate.withinBoundaries checks
// the tap coordinate against this structure.
class ScreenCoordinates {
  var touchEnabled as Lang.Boolean = true;
  var modeButton as Lang.Array<Lang.Array<Lang.Numeric>> = [
    [0, 0],
    [0, 0],
  ];
  var recordButton as Lang.Array<Lang.Array<Lang.Numeric>> = [
    [0, 0],
    [0, 0],
  ];
  var connectButton as Lang.Array<Lang.Array<Lang.Numeric>> = [
    [0, 0],
    [0, 0],
  ];
  var nextPresetButton as Lang.Array<Lang.Array<Lang.Numeric>> = [
    [0, 0],
    [0, 0],
  ];
  var prevPresetButton as Lang.Array<Lang.Array<Lang.Numeric>> = [
    [0, 0],
    [0, 0],
  ];
  var onOffButton as Lang.Array<Lang.Array<Lang.Numeric>> = [
    [0, 0],
    [0, 0],
  ];
  function initialize() {}
}
