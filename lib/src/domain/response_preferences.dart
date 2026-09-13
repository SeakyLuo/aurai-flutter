enum ResponseStyle {
  standard('默认', '预设风格和语调'),
  professional('专业可靠', '精雕细琢'),
  friendly('亲和友善', '温和健谈'),
  candid('直言不讳', '直率乐观'),
  quirky('天马行空', '趣味幻想'),
  efficient('高效务实', '简练直白'),
  cynical('吐槽达人', '犀利毒舌');

  const ResponseStyle(this.label, this.description);
  final String label;
  final String description;
}

enum ResponseTrait {
  warmth('温和体贴', '更友好、更亲近', '更专业，事实性更强'),
  enthusiasm('热情洋溢', '更加活力充沛', '更加冷静中立'),
  formatting('标题和列表', '采用清晰格式与列表结构', '更多段落文本，而非列表结构'),
  emoji('表情符号', '使用更多表情符号', '使用更少表情符号');

  const ResponseTrait(this.label, this.more, this.less);
  final String label;
  final String more;
  final String less;
}

enum TraitLevel {
  more('增强'),
  standard('默认'),
  less('减弱');

  const TraitLevel(this.label);
  final String label;
}

class ResponsePreferences {
  const ResponsePreferences({
    this.style = ResponseStyle.standard,
    this.traits = const {},
  });

  final ResponseStyle style;
  final Map<ResponseTrait, TraitLevel> traits;
  TraitLevel level(ResponseTrait trait) => traits[trait] ?? TraitLevel.standard;

  String get instructions => [
    '回复风格偏好：根据当前任务应用以下偏好；用户当前明确要求优先，风格不改变事实、能力或权限。',
    if (style != ResponseStyle.standard)
      '基础风格：${style.label}，${style.description}。',
    for (final trait in ResponseTrait.values)
      if (level(trait) != TraitLevel.standard)
        '${trait.label}：${level(trait) == TraitLevel.more ? trait.more : trait.less}。',
  ].join('\n');

  bool sameAs(ResponsePreferences other) =>
      style == other.style &&
      ResponseTrait.values.every((trait) => level(trait) == other.level(trait));

  Map<String, Object?> toJson() => {
    'style': style.name,
    'traits': {
      for (final entry in traits.entries) entry.key.name: entry.value.name,
    },
  };

  factory ResponsePreferences.fromJson(Map<String, dynamic> json) =>
      ResponsePreferences(
        style: ResponseStyle.values.byName(json['style'] as String),
        traits: {
          for (final entry in (json['traits'] as Map<String, dynamic>).entries)
            ResponseTrait.values.byName(entry.key): TraitLevel.values.byName(
              entry.value as String,
            ),
        },
      );
}
