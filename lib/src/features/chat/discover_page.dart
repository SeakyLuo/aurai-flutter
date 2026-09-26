import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../html_games/miniapp_library_page.dart';
import '../../skills/skills_page.dart';
import 'chat_controller.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'tools_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key, required this.controller});
  final ChatController controller;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  bool _openingSkills = false;

  Future<void> _skills() async {
    if (_openingSkills) return;
    setState(() => _openingSkills = true);
    try {
      final store = await widget.controller.aiSkills('user:local');
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => SkillsPage(
            store: store,
            controller: widget.controller,
            library: true,
          ),
        ),
      );
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
    } finally {
      if (mounted) setState(() => _openingSkills = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: const SettingsAppBar(title: '发现', root: true, onBack: null),
    body: SettingsPageBody(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: settingsPagePadding(
              context,
              EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.paddingOf(context).bottom + 16,
              ),
            ),
            children: [
              _entry(
                '小程序',
                SettingsIconType.miniapps,
                () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MiniappLibraryPage(controller: widget.controller),
                  ),
                ),
              ),
              _entry(
                '技能',
                SettingsIconType.skills,
                _openingSkills ? null : _skills,
              ),
              _entry(
                '工具',
                SettingsIconType.tools,
                () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ToolsPage(controller: widget.controller),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _entry(String title, SettingsIconType icon, VoidCallback? onTap) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: settingsFieldColor(context),
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18),
            minVerticalPadding: 18,
            leading: SettingsIcon(type: icon),
            title: Text(title),
            trailing: onTap == null
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const SettingsIcon(type: SettingsIconType.chevron),
            onTap: onTap,
          ),
        ),
      );
}
