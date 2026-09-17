enum ModelReasoning {
  inherit('跟随供应商'),
  automatic('由模型决定'),
  none('关闭'),
  enabled('开启'),
  minimal('极低'),
  low('低'),
  medium('中'),
  high('高'),
  xhigh('极高'),
  max('最高');

  const ModelReasoning(this.label);
  final String label;
}
