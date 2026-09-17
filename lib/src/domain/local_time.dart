/// Uses the device timezone at this instant, including daylight-saving rules.
String localIsoTime(DateTime instant) {
  final local = instant.toLocal();
  final offset = local.timeZoneOffset;
  final minutes = offset.inMinutes.abs();
  final zone = '${offset.isNegative ? '-' : '+'}'
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';
  return '${local.toIso8601String()}$zone';
}
