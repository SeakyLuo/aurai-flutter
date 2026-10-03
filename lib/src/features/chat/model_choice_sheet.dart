import 'package:flutter/material.dart';
import '../../domain/model_provider.dart';
import 'choice_sheet.dart';
import 'model_provider_icon.dart';

Future<String?> showModelChoiceSheet(
  BuildContext context, {
  required ModelConfig config,
  required List<String> models,
  required String? selected,
  String title = '选择模型',
}) => showModelOptionsSheet(
  context,
  title: title,
  selected: selected,
  choices: [
    for (final model in models)
      (value: model, label: config.displayModel(model)),
  ],
  searchText: (model) => '$model ${config.apiModelFor(model)}',
);

Future<String?> showModelOptionsSheet(
  BuildContext context, {
  required String title,
  required String? selected,
  required List<Choice<String>> choices,
  String Function(String)? searchText,
}) => showChoiceSheet<String?>(
  context,
  title: '模型',
  selected: selected,
  choices: [
    ...choices.where((choice) => choice.value == selected),
    ...choices.where((choice) => choice.value != selected),
  ],
  alwaysShowSearch: true,
  searchHint: '搜索模型',
  emptyTitle: '没有匹配的模型',
  searchText: (value) => '$value ${searchText?.call(value!) ?? ''}',
);

Future<ModelService?> showProviderChoiceSheet(
  BuildContext context, {
  required String title,
  required ModelService? selected,
  required List<Choice<ModelService>> choices,
  required Map<ModelService, ModelConfig> profiles,
}) => showChoiceSheet<ModelService?>(
  context,
  title: title,
  selected: selected,
  choices: choices,
  alwaysShowSearch: true,
  searchHint: '搜索供应商',
  emptyTitle: '没有匹配的供应商',
  leadingBuilder: (service) => ModelProviderIcon(config: profiles[service]!),
);
