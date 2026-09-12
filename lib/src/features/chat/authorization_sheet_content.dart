import 'package:flutter/material.dart';

class AuthorizationSheetContent extends StatelessWidget {
  const AuthorizationSheetContent({
    super.key,
    required this.title,
    required this.content,
    required this.allowLabel,
    required this.onAllow,
    required this.onDeny,
    required this.seconds,
  });

  final String title;
  final Widget content;
  final String allowLabel;
  final VoidCallback? onAllow;
  final VoidCallback onDeny;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: colors.onSurfaceVariant,
                    ),
                    child: content,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onAllow,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.onSurface,
                  foregroundColor: colors.surface,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(allowLabel),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: onDeny,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.onSurface,
                  minimumSize: const Size.fromHeight(52),
                  side: BorderSide(color: colors.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text('拒绝 · $seconds 秒后自动拒绝'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
