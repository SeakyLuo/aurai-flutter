String currentTimeContext() {
  final now = DateTime.now();
  final offset = now.timeZoneOffset;
  final minutes = offset.inMinutes.abs();
  final zone =
      '${offset.isNegative ? '-' : '+'}'
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';
  return 'Current device local time: ${now.toIso8601String()} '
      '(UTC$zone, ${now.timeZoneName}).';
}
