import 'package:intl/intl.dart';

final _moneyFormat = NumberFormat.currency(
  locale: 'es_MX',
  symbol: r'$',
  decimalDigits: 2,
);

String formatCents(int cents) {
  return _moneyFormat.format(cents / 100);
}