import 'package:flutter/material.dart';
import '../features/chat/settings_appearance.dart';
import 'skill_editor.dart';
import 'skill_store.dart';

class SkillsPage extends StatelessWidget {
  const SkillsPage({super.key, required this.store});
  final SkillStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SettingsAppBar(
      title: '技能',
      onBack: () => Navigator.pop(context),
      actions: [
        SettingsGlassAction(
          label: '创建技能',
          icon: Icons.add_rounded,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final skills = store.skills;
              if (skills.isEmpty)
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('还没有技能'),
                      const SizedBox(height: 12),
                      const Text(
                        '把常用的操作方法交给 Aurai 保存，下次直接使用。',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('创建技能'),
                      ),
                    ],
                  ),
                );
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: skills.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final skill = skills[index];
                  return Material(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      title: Text(skill.name),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          skill.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: Text(
                        skill.enabled ? '已启用' : '已停用',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              SkillEditor(store: store, skill: skill),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    ),
  );
}
