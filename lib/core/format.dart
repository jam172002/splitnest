import 'package:intl/intl.dart';

class Fmt {
  static final _money = NumberFormat.currency(symbol: '', decimalDigits: 0);
  static String money(num v) => '${_money.format(v)}';
  static String date(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
}
