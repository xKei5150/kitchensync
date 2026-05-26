class QuantityFormatter {
  const QuantityFormatter._();

  static String format(double value) {
    if (value == value.truncate()) {
      return value.truncate().toString();
    }
    var s = value.toStringAsFixed(2);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }
}
