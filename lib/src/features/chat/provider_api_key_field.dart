import 'package:flutter/material.dart';
import 'settings_icon.dart';

/// Each credential has its own visibility state, using the supplier form style.
class ProviderApiKeyField extends StatefulWidget {
  const ProviderApiKeyField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.decoration,
  });
  final TextEditingController controller;
  final bool enabled;
  final InputDecoration decoration;
  @override
  State<ProviderApiKeyField> createState() => _ProviderApiKeyFieldState();
}

class _ProviderApiKeyFieldState extends State<ProviderApiKeyField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: _obscure,
    autocorrect: false,
    enableSuggestions: false,
    style: const TextStyle(fontSize: 16),
    decoration: widget.decoration.copyWith(
      suffixIcon: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: SizedBox.square(
            dimension: 40,
            child: IconButton(
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(8),
              ),
              onPressed: widget.enabled
                  ? () => setState(() => _obscure = !_obscure)
                  : null,
              tooltip: _obscure ? '显示密钥' : '隐藏密钥',
              icon: SettingsIcon(
                type: _obscure ? SettingsIconType.eye : SettingsIconType.eyeOff,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
