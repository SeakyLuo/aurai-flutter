enum SkillSort {
  createdDescending('创建时间：从新到旧', 'created', true),
  createdAscending('创建时间：从旧到新', 'created', false),
  updatedDescending('更新时间：从新到旧', 'updated', true),
  updatedAscending('更新时间：从旧到新', 'updated', false),
  usageDescending('使用次数：从多到少', 'uses', true),
  usageAscending('使用次数：从少到多', 'uses', false);

  const SkillSort(this.label, this.field, this.descending);
  final String label;
  final String field;
  final bool descending;
}
