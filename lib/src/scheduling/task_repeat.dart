class TaskRepeat {
  TaskRepeat({
    required this.frequency,
    this.interval = 1,
    Set<int>? weekdays,
    this.monthDay = 1,
    this.ordinal,
    this.weekday = 1,
  }) : weekdays = weekdays ?? {1};
  String frequency;
  int interval;
  Set<int> weekdays;
  int monthDay;
  int? ordinal;
  int weekday;
  static const dayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
  static const dayNames = ['一', '二', '三', '四', '五', '六', '日'];
  TaskRepeat copy() => TaskRepeat(
    frequency: frequency,
    interval: interval,
    weekdays: Set.of(weekdays),
    monthDay: monthDay,
    ordinal: ordinal,
    weekday: weekday,
  );

  static TaskRepeat? parse(String rule, DateTime at) {
    if (rule.isEmpty) return null;
    final fields = {
      for (final part in rule.split(';'))
        part.split('=')[0]: part.split('=')[1],
    };
    if (fields.keys.any(
      (key) => ![
        'FREQ',
        'INTERVAL',
        'BYDAY',
        'BYMONTHDAY',
        'BYHOUR',
        'BYMINUTE',
        'BYSECOND',
        'BYSETPOS',
      ].contains(key),
    ))
      return null;
    // Keep schedules with several daily times outside the single-time editor.
    if (fields['BYHOUR'] != null && fields['BYHOUR'] != '${at.hour}')
      return null;
    if (fields['BYMINUTE'] != null && fields['BYMINUTE'] != '${at.minute}')
      return null;
    if (fields['BYSECOND'] != null && fields['BYSECOND'] != '0') return null;
    final freq = fields['FREQ'];
    if (fields['BYSETPOS'] != null &&
        (freq != 'MONTHLY' || !dayCodes.contains(fields['BYDAY'])))
      return null;
    if (!['HOURLY', 'DAILY', 'WEEKLY', 'MONTHLY'].contains(freq)) return null;
    final result = TaskRepeat(
      frequency: freq!,
      interval: int.parse(fields['INTERVAL'] ?? '1'),
      weekdays: {at.weekday},
      monthDay: at.day,
      weekday: at.weekday,
    );
    final byDay = fields['BYDAY'];
    if ((freq == 'WEEKLY' || (freq == 'DAILY' && result.interval == 1)) &&
        byDay != null) {
      result.frequency = 'WEEKLY';
      final codes = byDay.split(',');
      if (codes.any((code) => !dayCodes.contains(code))) return null;
      result.weekdays = codes.map((code) => dayCodes.indexOf(code) + 1).toSet();
    } else if (freq == 'MONTHLY' && byDay != null) {
      final monthlyDay = fields['BYSETPOS'] == null
          ? byDay
          : '${fields['BYSETPOS']}$byDay';
      final match = RegExp(
        r'^(-1|[1-5])(MO|TU|WE|TH|FR|SA|SU)$',
      ).firstMatch(monthlyDay);
      if (match == null) return null;
      result.ordinal = int.parse(match[1]!);
      result.weekday = dayCodes.indexOf(match[2]!) + 1;
    } else if (byDay != null) {
      return null;
    }
    if (fields['BYMONTHDAY'] != null) {
      if (freq != 'MONTHLY' ||
          byDay != null ||
          fields['BYMONTHDAY']!.contains(','))
        return null;
      result.monthDay = int.parse(fields['BYMONTHDAY']!);
      if (result.monthDay < 1 || result.monthDay > 31) return null;
    }
    return result;
  }

  String get rule => [
    'FREQ=$frequency',
    if (interval != 1) 'INTERVAL=$interval',
    if (frequency == 'WEEKLY')
      'BYDAY=${(weekdays.toList()..sort()).map((day) => dayCodes[day - 1]).join(',')}',
    if (frequency == 'MONTHLY')
      ordinal == null
          ? 'BYMONTHDAY=$monthDay'
          : 'BYDAY=$ordinal${dayCodes[weekday - 1]}',
  ].join(';');
  bool get workdays =>
      frequency == 'WEEKLY' &&
      interval == 1 &&
      weekdays.length == 5 &&
      weekdays.containsAll([1, 2, 3, 4, 5]);
  String get unit => switch (frequency) {
    'HOURLY' => '小时',
    'DAILY' => '天',
    'WEEKLY' => '周',
    _ => '月',
  };
  String get frequencyLabel => workdays
      ? '工作日'
      : interval > 1
      ? '每隔 $interval $unit'
      : '每$unit';
  String get daysLabel => switch (frequency) {
    'WEEKLY' =>
      workdays
          ? '周一至周五'
          : (weekdays.toList()..sort())
                .map((day) => '周${dayNames[day - 1]}')
                .join('、'),
    'MONTHLY' =>
      ordinal == null
          ? '每月 $monthDay 日'
          : '${ordinal == -1 ? '最后一个' : '第${['一', '二', '三', '四', '五'][ordinal! - 1]}个'}周${dayNames[weekday - 1]}',
    _ => frequencyLabel,
  };
  String get executionLabel => switch (frequency) {
    'HOURLY' || 'DAILY' => '$interval $unit',
    'WEEKLY' => interval == 1 ? daysLabel : '每 $interval 周 · $daysLabel',
    'MONTHLY' =>
      '${interval == 1 ? '' : '每 $interval 月 · '}${ordinal == null ? '$monthDay 日' : daysLabel}',
    _ => daysLabel,
  };
  String label(DateTime at) =>
      '${frequencyLabel}${['WEEKLY', 'MONTHLY'].contains(frequency) ? ' · $daysLabel' : ''} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

  DateTime firstStart(DateTime selected, DateTime now) {
    if (frequency == 'HOURLY') {
      if (selected.isAfter(now)) return selected;
      return selected.add(
        Duration(
          hours:
              ((now.difference(selected).inMinutes ~/ 60) ~/ interval + 1) *
              interval,
        ),
      );
    }
    final lower = selected.isAfter(now)
        ? selected
        : DateTime(
            now.year,
            now.month,
            now.day,
            selected.hour,
            selected.minute,
          );
    // A new schedule starts on the first future date matching its selected days.
    for (var offset = 0; offset <= 366; offset++) {
      final date = DateTime(
        lower.year,
        lower.month,
        lower.day + offset,
        selected.hour,
        selected.minute,
      );
      if (!date.isAfter(now)) continue;
      if (frequency == 'WEEKLY' && !weekdays.contains(date.weekday)) continue;
      if (frequency == 'MONTHLY') {
        if (ordinal == null && date.day != monthDay) continue;
        if (ordinal != null) {
          if (date.weekday != weekday) continue;
          if (ordinal == -1
              ? DateTime(date.year, date.month, date.day + 7).month ==
                    date.month
              : (date.day - 1) ~/ 7 + 1 != ordinal)
            continue;
        }
      }
      return date;
    }
    throw StateError('没有符合条件的执行日期');
  }
}
