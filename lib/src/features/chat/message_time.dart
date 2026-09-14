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

String conversationMessageTime(DateTime value) {
  final date = value.toLocal();
  final now = DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  if (day == DateTime(now.year, now.month, now.day - 1)) return '昨天';
  final monthDay =
      '${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日';
  return date.year == now.year ? monthDay : '${date.year}年$monthDay';
}
