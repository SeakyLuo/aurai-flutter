import '../domain/tool_models.dart';

enum SkillPermission {
  alwaysAsk('始终询问', '读取技能内容或执行技能前都询问。'),
  readOnly('允许读取操作', '读取技能内容无需询问，执行脚本前仍会询问。'),
  lowRisk('允许低风险操作', '自动允许读取和低风险操作，高风险操作仍会询问。'),
  all('允许所有操作', '允许此技能的读取与执行，依赖技能仍遵循各自权限。');

  const SkillPermission(this.label, this.description);
  final String label;
  final String description;

  bool requiresConfirmation(ToolSafety safety) => switch (this) {
    alwaysAsk => true,
    readOnly => safety != ToolSafety.readOnly,
    lowRisk =>
      safety == ToolSafety.sensitive || safety == ToolSafety.destructive,
    all => false,
  };
}
