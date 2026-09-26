import 'package:flutter/material.dart';
import '../../domain/model_provider.dart';
import '../../providers/model_reasoning_options.dart';
import 'choice_sheet.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ModelReasoningField extends StatelessWidget {
  const ModelReasoningField({
    super.key,
    required this.service,
    required this.model,
    required this.baseUrl,
    required this.value,
    required this.onChanged,
    this.providerDefault = false,
    this.inheritedValue,
  });

  final ModelService service;
  final String model, baseUrl;
  final ModelReasoning value;
  final ValueChanged<ModelReasoning>? onChanged;
  final bool providerDefault;
  final ModelReasoning? inheritedValue;

  @override
  Widget build(BuildContext context) {
    final supported = providerDefault
        ? providerReasoningOptions(service)
        : modelReasoningOptions(service, model, baseUrl);
    final options = [
      if (!providerDefault) ModelReasoning.inherit,
      ...supported,
    ];
    final title = providerDefault
        ? '供应商默认思考强度'
        : options.contains(ModelReasoning.enabled)
        ? '深度思考'
        : '思考强度';
    String label(ModelReasoning option) =>
        option == ModelReasoning.inherit && inheritedValue != null
        ? '跟随供应商（${inheritedValue!.label}）'
        : option.label;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Material(
            color: settingsFieldColor(context),
            borderRadius: BorderRadius.circular(26),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              title: Text(label(value)),
              trailing: const SettingsIcon(type: SettingsIconType.chevron),
              onTap: onChanged == null
                  ? null
                  : () async {
                      final selected = await showChoiceSheet<ModelReasoning>(
                        context,
                        title: title,
                        selected: value,
                        choices: [
                          for (final option in options)
                            (value: option, label: label(option)),
                        ],
                      );
                      if (context.mounted &&
                          selected != null &&
                          selected != value) {
                        onChanged!(selected);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}
