class Util {
  static function format_duration(seconds) {
    var hh = seconds / 3600;
    var mm = (seconds / 60) % 60;
    var ss = seconds % 60;

    if (hh != 0) {
      return hh + "H:" + mm.format("%02d");
    } else {
      return mm + ":" + ss.format("%02d");
    }
  }
}