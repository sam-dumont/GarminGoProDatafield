class Util {
  static function format_duration(seconds) {
    var hh = seconds / 3600;
    var mm = (seconds / 60) % 60;
    var ss = seconds % 60;

    if (hh != 0) {
      return hh + ":" + mm.format("%02d") + ":" + ss.format("%02d");
    } else {
      return mm + ":" + ss.format("%02d");
    }
  }
}