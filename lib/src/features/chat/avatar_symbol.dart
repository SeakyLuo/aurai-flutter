import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'settings_icon.dart';
import '../../domain/avatar_portraits.dart';
import '../../html_games/html_game_icon.dart';
import '../../skills/extra_skill_icon.dart';

const avatarSymbols = <String, String>{
  'app_logo_white': 'App Logo',
  'initial': '首字',
  'portrait:dark_hair_boy': '棕发小哥',
  'portrait:brown_hair_boy': '皮衣墨镜男生',
  'portrait:basketball_boy': '篮球男生',
  'portrait:navy_suit_man': '西装眼镜男生',
  'portrait:white_robed_swordsman': '白衣剑客',
  'portrait:brown_hair_girl': '棕发女生',
  'portrait:pink_hair_girl': '粉发女孩',
  'portrait:blonde_ponytail_girl': '金发马尾女生',
  'portrait:silver_hair_girl': '银发女生',
  'portrait:golden_princess': '古风公主',
  'portrait:blue_cat': '蓝帽猫咪',
  'portrait:shiba_inu': '柴犬',
  'portrait:fox': '小狐狸',
  'portrait:lynx': '猞猁',
  'portrait:raccoon': '浣熊',
  'portrait:skunk': '臭鼬',
  'portrait:panda': '大熊猫',
  'portrait:polar_bear': '白熊',
  'portrait:lion': '小狮子',
  'portrait:baby_tiger': '小老虎',
  'portrait:schnauzer': '雪纳瑞',
  'portrait:capybara': '水豚',
  'portrait:lizard': '树袋熊',
  'portrait:kangaroo': '袋鼠',
  'portrait:monkey': '猴子',
  'portrait:hippo': '河马',
  'portrait:rhino': '犀牛',
  'portrait:buffalo': '美洲野牛',
  'portrait:camel': '骆驼',
  'portrait:moose': '驼鹿',
  'portrait:alpaca': '羊驼',
  'portrait:baby_elephant': '小象',
  'portrait:goat': '山羊',
  'portrait:hedgehog': '刺猬',
  'portrait:hamster': '仓鼠',
  'portrait:wild_rabbit': '坏野兔',
  'portrait:chitu_horse': '赤兔马',
  'portrait:giraffe': '长颈鹿',
  'portrait:magician_pig': '魔术师小猪',
  'portrait:duck': '小鸭子',
  'portrait:penguin': '企鹅',
  'portrait:turkey': '火鸡',
  'portrait:toucan': '巨嘴鸟',
  'portrait:owl': '猫头鹰',
  'portrait:owl_turned': '转头猫头鹰',
  'portrait:parrot': '鹦鹉',
  'portrait:frog': '小青蛙',
  'portrait:turtle': '海龟',
  'portrait:yellow_gecko': '鹅黄色守宫',
  'portrait:frilled_lizard': '伞蜥',
  'portrait:snail': '蜗牛',
  'portrait:baby_trex': '小霸王龙',
  'portrait:crocodile': '鳄鱼',
  'portrait:seal': '小海豹',
  'portrait:pink_dolphin': '粉色海豚',
  'portrait:shark': '鲨鱼',
  'portrait:pufferfish': '河豚',
  'portrait:octopus': '比心章鱼',
  'portrait:sunflower': '向日葵',
  'portrait:cactus': '小仙人掌',
  'portrait:eggplant': '茄子',
  'portrait:tomato': '番茄',
  'portrait:avocado': '牛油果',
  'portrait:shiitake': '香菇',
  'portrait:toast': '吐司',
  'portrait:dumpling': '饺子',
  'portrait:double_scoop_ice_cream': '双球冰淇淋',
  'portrait:lollipop': '棒棒糖',
  'portrait:red_dragon_fruit': '红心火龙果',
  'portrait:pumpkin': '南瓜头',
  'portrait:ghost': '幽灵',
  'portrait:little_robot': '小机器人',
  'portrait:saturn': '土星',
  'portrait:sunglasses_bee': '墨镜蜜蜂',
  'person': '人物',
  'spark': '灵感',
  'puzzle': '拼图',
  'memory': '记忆',
  'smile': '笑脸',
  'cat': '猫咪',
  'robot': '机器人',
  'game': '手柄',
  'flower': '花朵',
  'sun': '太阳',
  'moon': '月亮',
  'star': '星星',
  'mountain': '山峦',
  'leaf': '叶子',
  'heart': '爱心',
  'planet': '星球',
  'bolt': '闪电',
  'diamond': '晶石',
  'rings': '圆环',
  'waves': '波纹',
  'music': '音乐',
  'photo': '图片',
  'camera': '相机',
  'palette': '画板',
  'food': '美食',
  'shopping': '购物',
  'travel': '旅行',
  'location': '地点',
  'health': '健康',
  'science': '实验',
  'brain': '思考',
  'cloud': '云朵',
  'clock': '时钟',
  'calendar': '日历',
  'mail': '邮件',
  'news': '新闻',
  'checklist': '清单',
  'chart': '统计',
  'translate': '翻译',
  'phone': '手机',
  'browser': '浏览器',
  'window': '窗口',
  'clipboard': '剪贴板',
  'calculator': '计算器',
  'battery': '电池',
  'download': '下载',
  'terminal': '终端',
  'database': '数据库',
  'api': '接口',
  'link': '链接',
  'lock': '安全',
  'key': '密钥',
  'bug': '调试',
  'automation': '自动化',
};

class AvatarSymbol extends StatelessWidget {
  const AvatarSymbol({super.key, required this.symbol, required this.color});
  final String symbol;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final portrait = avatarPortraits[symbol];
    if (portrait != null) {
      return Image.asset(
        portrait.asset,
        width: 24,
        height: 24,
        cacheWidth: (24 * MediaQuery.devicePixelRatioOf(context)).ceil(),
      );
    }
    if (symbol.startsWith('emoji:')) {
      return Text(
        symbol.substring(6),
        textScaler: TextScaler.noScaling,
        style: const TextStyle(fontSize: 24, height: 1),
      );
    }
    if (symbol == 'game')
      return HtmlGameIcon(HtmlGameIconType.game, color: color);
    if (symbol == 'app_logo_white') {
      return Image.asset(
        'assets/branding/symbol_white.png',
        color: color,
        colorBlendMode: BlendMode.srcIn,
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      );
    }
    if (ExtraSkillIcon.names.contains(symbol) && symbol != 'robot') {
      return ExtraSkillIcon(symbol, color: color);
    }
    const shared = {
      'person': SettingsIconType.personalInfo,
      'spark': SettingsIconType.personalization,
      'puzzle': SettingsIconType.skills,
      'memory': SettingsIconType.memory,
    };
    final type = shared[symbol];
    return type != null
        ? SettingsIcon(type: type, color: color)
        : CustomPaint(
            size: const Size.square(24),
            painter: _SymbolPainter(symbol, color),
          );
  }
}

class _SymbolPainter extends CustomPainter {
  const _SymbolPainter(this.symbol, this.color);
  final String symbol;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double x, double y, double a, double b) =>
        canvas.drawLine(Offset(x, y), Offset(a, b), pen);
    void circle(double x, double y, double r) =>
        canvas.drawCircle(Offset(x, y), r, pen);
    void path(List<Offset> points, {bool close = false}) {
      final p = Path()..addPolygon(points, close);
      canvas.drawPath(p, pen);
    }

    switch (symbol) {
      case 'smile':
        circle(12, 12, 8);
        circle(9, 10, .4);
        circle(15, 10, .4);
        canvas.drawArc(
          const Rect.fromLTWH(8, 10, 8, 7),
          .2,
          math.pi - .4,
          false,
          pen,
        );
      case 'cat':
        canvas.drawPath(
          Path()
            ..moveTo(5, 10)
            ..lineTo(4, 4)
            ..lineTo(9, 7)
            ..quadraticBezierTo(12, 6, 15, 7)
            ..lineTo(20, 4)
            ..lineTo(19, 10)
            ..cubicTo(23, 23, 1, 23, 5, 10),
          pen,
        );
        circle(9, 12, .4);
        circle(15, 12, .4);
        line(11, 15, 13, 15);
      case 'robot':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 7, 14, 13),
            const Radius.circular(4),
          ),
          pen,
        );
        line(12, 7, 12, 4);
        circle(12, 3, 1);
        line(8, 12, 8, 14);
        line(16, 12, 16, 14);
        line(10, 17, 14, 17);
      case 'flower':
        for (var i = 0; i < 5; i++) {
          final a = i * math.pi * 2 / 5 - math.pi / 2;
          circle(12 + 5 * math.cos(a), 12 + 5 * math.sin(a), 3.6);
        }
        circle(12, 12, 2);
      case 'sun':
        circle(12, 12, 4);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          line(
            12 + 7 * math.cos(a),
            12 + 7 * math.sin(a),
            12 + 9 * math.cos(a),
            12 + 9 * math.sin(a),
          );
        }
      case 'moon':
        canvas.drawPath(
          Path()
            ..moveTo(15, 4)
            ..cubicTo(4, 1, 0, 17, 11, 20)
            ..quadraticBezierTo(18, 22, 21, 14)
            ..cubicTo(12, 18, 8, 9, 15, 4),
          pen,
        );
      case 'star':
        path([
          for (var i = 0; i < 10; i++)
            Offset(
              12 + (i.isEven ? 9 : 4) * math.cos(i * math.pi / 5 - math.pi / 2),
              12 + (i.isEven ? 9 : 4) * math.sin(i * math.pi / 5 - math.pi / 2),
            ),
        ], close: true);
      case 'mountain':
        path(const [
          Offset(3, 19),
          Offset(10, 5),
          Offset(15, 14),
          Offset(18, 9),
          Offset(22, 19),
        ], close: true);
        path(const [Offset(7, 11), Offset(10, 13), Offset(12, 10)]);
      case 'leaf':
        canvas.drawPath(
          Path()
            ..moveTo(5, 19)
            ..cubicTo(0, 8, 11, 5, 20, 4)
            ..cubicTo(20, 15, 16, 23, 5, 19)
            ..moveTo(4, 21)
            ..lineTo(15, 10),
          pen,
        );
      case 'heart':
        canvas.drawPath(
          Path()
            ..moveTo(12, 20)
            ..cubicTo(-6, 10, 6, -1, 12, 8)
            ..cubicTo(18, -1, 30, 10, 12, 20),
          pen,
        );
      case 'planet':
        circle(12, 12, 6);
        canvas.save();
        canvas.translate(12, 12);
        canvas.rotate(-.5);
        canvas.drawOval(const Rect.fromLTWH(-10, -3.5, 20, 7), pen);
        canvas.restore();
      case 'bolt':
        path(const [
          Offset(14, 3),
          Offset(5, 14),
          Offset(11, 14),
          Offset(10, 21),
          Offset(19, 10),
          Offset(13, 10),
        ], close: true);
      case 'diamond':
        path(const [
          Offset(12, 3),
          Offset(21, 12),
          Offset(12, 21),
          Offset(3, 12),
        ], close: true);
        path(const [
          Offset(12, 7),
          Offset(17, 12),
          Offset(12, 17),
          Offset(7, 12),
        ], close: true);
      case 'rings':
        circle(9, 12, 6);
        circle(15, 12, 6);
      case 'waves':
        for (final y in [7.0, 12.0, 17.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(3, y)
              ..cubicTo(9, y - 7, 15, y + 7, 21, y),
            pen,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_SymbolPainter oldDelegate) =>
      symbol != oldDelegate.symbol || color != oldDelegate.color;
}
