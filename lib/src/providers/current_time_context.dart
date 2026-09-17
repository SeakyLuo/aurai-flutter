import '../domain/local_time.dart';

String currentTimeContext() {
  final now = DateTime.now();
  return '当前设备本地时间：${localIsoTime(now)}（${now.timeZoneName}）。'
      '默认使用设备本地时区理解和表达时间，包括今天、明天、日期和提醒；用户明确指定其他时区时按其要求。'
      '工具或原始日志中的 Z、UTC、+00:00 时间表示 UTC，向用户说明前转换到设备本地时区，注意跨日；不要直接照抄为本地时间。'
      '保留接口要求的时区格式，只有用户询问时区或对照时间时才额外展示 UTC。';
}
