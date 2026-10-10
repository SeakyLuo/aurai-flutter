/// Time is supplied by the presentation host. These operations remain pure.
const interactiveTimeOperations = {
  'multiply',
  'divide',
  'modulo',
  'min',
  'max',
  'floor',
  'ceil',
  'round',
  'formatDuration',
  'formatDateTime',
  'nextTimeOfDay',
  'append',
  'slice',
};

Object? evaluateInteractiveTime(String op, List<Object?> values) {
  num number(int index) {
    final value = values[index];
    if (value is! num || !value.isFinite) throw ArgumentError('$op 需要有限数值');
    return value;
  }

  switch (op) {
    case 'multiply':
      return number(0) * number(1);
    case 'divide':
      if (number(1) == 0) throw ArgumentError('除数不能为零');
      return number(0) / number(1);
    case 'modulo':
      if (number(1) == 0) throw ArgumentError('除数不能为零');
      return number(0) % number(1);
    case 'min':
      return number(0) < number(1) ? number(0) : number(1);
    case 'max':
      return number(0) > number(1) ? number(0) : number(1);
    case 'floor':
      return number(0).floor();
    case 'ceil':
      return number(0).ceil();
    case 'round':
      return number(0).round();
    case 'append':
      final list = values[0] as List;
      if (list.length >= 200) throw ArgumentError('本地列表最多 200 项');
      return [...list, values[1]];
    case 'slice':
      final start = number(1).toInt(), count = number(2).toInt();
      if (start < 0 || count < 0) throw ArgumentError('slice 的位置与数量不能为负数');
      return (values[0] as List).skip(start).take(count).toList();
    case 'formatDuration':
      final milliseconds = number(0).round();
      final format = values[1] as String;
      if (!['mm:ss', 'HH:mm:ss', 'HH:mm:ss.SSS'].contains(format)) {
        throw ArgumentError('不支持的时长格式');
      }
      final absolute = milliseconds.abs();
      String pad(int n, [int width = 2]) => n.toString().padLeft(width, '0');
      final seconds = absolute ~/ 1000;
      final text = format == 'mm:ss'
          ? '${pad(seconds ~/ 60)}:${pad(seconds % 60)}'
          : '${pad(seconds ~/ 3600)}:${pad(seconds ~/ 60 % 60)}:${pad(seconds % 60)}';
      return '${milliseconds < 0 ? '-' : ''}$text${format.endsWith('.SSS') ? '.${pad(absolute % 1000, 3)}' : ''}';
    case 'formatDateTime':
      final offset = values.length == 3 ? number(2).toInt() : null;
      if (offset != null && (offset < -840 || offset > 840))
        throw ArgumentError('时区偏移需要 -840–840 分钟');
      final date = offset == null
          ? DateTime.fromMillisecondsSinceEpoch(number(0).toInt())
          : DateTime.fromMillisecondsSinceEpoch(
              number(0).toInt(),
              isUtc: true,
            ).add(Duration(minutes: offset));
      final format = values[1] as String;
      if (![
        'HH:mm',
        'HH:mm:ss',
        'yyyy-MM-dd',
        'yyyy-MM-dd HH:mm:ss',
      ].contains(format))
        throw ArgumentError('不支持的日期格式');
      String pad(int n) => n.toString().padLeft(2, '0');
      return format
          .replaceAll('yyyy', date.year.toString().padLeft(4, '0'))
          .replaceAll('MM', pad(date.month))
          .replaceAll('dd', pad(date.day))
          .replaceAll('HH', pad(date.hour))
          .replaceAll('mm', pad(date.minute))
          .replaceAll('ss', pad(date.second));
    case 'nextTimeOfDay':
      final now = DateTime.fromMillisecondsSinceEpoch(number(0).toInt());
      final hour = number(1), minute = number(2);
      if (hour != hour.toInt() ||
          hour < 0 ||
          hour > 23 ||
          minute != minute.toInt() ||
          minute < 0 ||
          minute > 59)
        throw ArgumentError('时刻需要 0–23 小时和 0–59 分钟');
      final days = values.length == 4 ? values[3] : const [1, 2, 3, 4, 5, 6, 7];
      if (days is! List ||
          days.isEmpty ||
          days.length > 7 ||
          days.toSet().length != days.length ||
          days.any((day) => day is! int || day < 1 || day > 7))
        throw ArgumentError('重复星期需要不重复的 1–7');
      for (var offset = 0; offset <= 7; offset++) {
        final target = DateTime(
          now.year,
          now.month,
          now.day + offset,
          hour.toInt(),
          minute.toInt(),
        );
        if (target.isAfter(now) && days.contains(target.weekday))
          return target.millisecondsSinceEpoch;
      }
      throw StateError('无法计算下一次时刻');
    default:
      throw ArgumentError('不支持的时间表达式 $op');
  }
}

bool validInteractiveLocalValue(Object? value) =>
    value is String ||
    value is bool ||
    value is num && value.isFinite ||
    value is List &&
        value.length <= 200 &&
        value.every(
          (item) =>
              item is String || item is bool || item is num && item.isFinite,
        );
