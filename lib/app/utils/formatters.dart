String formatMoney(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final parts = <String>[];

  for (var i = digits.length; i > 0; i -= 3) {
    final start = i - 3;
    parts.add(digits.substring(start < 0 ? 0 : start, i));
  }

  final formatted = parts.reversed.join('.');
  return '${negative ? '-' : ''}\$$formatted';
}

String formatDateTimeShort(DateTime value) {
  return '${_twoDigits(value.day)}/${_twoDigits(value.month)} '
      '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
}

String formatMovementDate(DateTime value, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final sameDay = _isSameDay(value, reference);
  final yesterday = _isSameDay(value, reference.subtract(const Duration(days: 1)));

  if (sameDay) {
    return 'Hoy, ${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
  }
  if (yesterday) {
    return 'Ayer, ${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
  }
  return formatDateTimeShort(value);
}

String formatShortDate(DateTime value) {
  return '${_twoDigits(value.day)}/${_twoDigits(value.month)}/${value.year}';
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
