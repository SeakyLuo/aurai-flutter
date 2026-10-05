import 'package:flutter/material.dart';
import 'chat_widgets.dart';
import 'settings_icon.dart';
import 'temporary_memory_sheet.dart';

class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    super.key,
    required this.showWelcome,
    required this.temporary,
    required this.personalized,
    required this.onPersonalizationChanged,
    required this.top,
    required this.bottom,
    required this.onUseExample,
  });

  final bool showWelcome;
  final bool temporary;
  final bool personalized;
  final ValueChanged<bool> onPersonalizationChanged;
  final double top;
  final double bottom;
  final ValueChanged<String> onUseExample;

  Future<void> _chooseMemory(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final result = await showTemporaryMemorySheet(
      context,
      personalized: personalized,
    );
    if (context.mounted && result != null) onPersonalizationChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    if (showWelcome) {
      return RepaintBoundary(
        child: EmptyConversation(
          contentPadding: EdgeInsets.only(top: top),
          onUseExample: onUseExample,
        ),
      );
    }
    if (!temporary) return const SizedBox.expand();
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.only(
        top: top,
        bottom: bottom + 88,
      ).add(const EdgeInsets.symmetric(horizontal: 32, vertical: 24)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '临时聊天',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '不写入新记忆，退出后自动归档。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: color.withValues(alpha: .65),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => _chooseMemory(context),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    personalized ? '使用记忆' : '不使用记忆',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox.square(
                    dimension: 16,
                    child: SettingsIcon(
                      type: SettingsIconType.chevronDown,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
