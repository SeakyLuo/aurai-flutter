class SourceDate {
  const SourceDate(this.value, this.hasTime, this.hasSeconds);
  final DateTime value;
  final bool hasTime;
  final bool hasSeconds;

  static SourceDate? tryParse(String input) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)?$',
    ).firstMatch(input.trim());
    if (match == null) return null;
    if (match[4] != null &&
        (int.parse(match[4]!) > 23 ||
            int.parse(match[5]!) > 59 ||
            (match[6] != null && int.parse(match[6]!) > 59)))
      return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final calendar = DateTime(year, month, day);
    if (calendar.year != year || calendar.month != month || calendar.day != day)
      return null;
    final date = DateTime.tryParse(input.trim());
    if (date == null) return null;
    return SourceDate(
      date.toLocal(),
      input.trim().length > 10,
      match[6] != null,
    );
  }

  String get label {
    String pad(int value) => value.toString().padLeft(2, '0');
    final year = value.year == DateTime.now().year ? '' : '${value.year}年';
    final date = '$year${pad(value.month)}月${pad(value.day)}日';
    if (!hasTime) return date;
    final seconds = hasSeconds ? ':${pad(value.second)}' : '';
    return '$date ${pad(value.hour)}:${pad(value.minute)}$seconds';
  }
}
