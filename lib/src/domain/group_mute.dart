class GroupMute {
  static const maxDuration = Duration(days: 30);
  const GroupMute({this.until});
  // No deadline means permanent; no GroupMute object means unrestricted.
  final DateTime? until;
  bool get isActive => until == null || until!.isAfter(DateTime.now());
  String get description {
    final deadline = until;
    if (deadline == null) return '永久禁言';
    return '禁言至 ${deadline.year}年${deadline.month}月${deadline.day}日 '
        '${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}';
  }

  static GroupMute? fromStored(int value) => value == 0
      ? null
      : GroupMute(
          until: value == -1
              ? null
              : DateTime.fromMicrosecondsSinceEpoch(value),
        );
}
