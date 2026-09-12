String messageTime(DateTime value) {
  final date = value.toLocal();
  final now = DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final time =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  if (day == today) return time;
  if (day == yesterday) return '昨天 $time';
  return '${date.month}月${date.day}日 $time';
}
