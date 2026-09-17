import 'package:flutter/material.dart';
import '../../domain/response_preferences.dart';
import 'personalization_controls.dart';
import 'settings_appearance.dart';

class PersonalityTraitsPage extends StatefulWidget {
  const PersonalityTraitsPage({
    super.key,
    required this.initial,
    required this.onChanged,
  });
  final Map<ResponseTrait, TraitLevel> initial;
  final ValueChanged<Map<ResponseTrait, TraitLevel>> onChanged;
  @override
  State<PersonalityTraitsPage> createState() => _PersonalityTraitsPageState();
}

class _PersonalityTraitsPageState extends State<PersonalityTraitsPage> {
  late final _traits = Map<ResponseTrait, TraitLevel>.of(widget.initial);
  void _set(ResponseTrait trait, String value) {
    setState(() => _traits[trait] = TraitLevel.values.byName(value));
    widget.onChanged(Map.of(_traits));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      gradientBackground: true,
      title: '特征',
      onBack: () => Navigator.pop(context),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              View.of(context).padding.top / View.of(context).devicePixelRatio +
                  76 +
                  8,
              16,
              32,
            ),
            children: [
              for (final trait in ResponseTrait.values) ...[
                PersonalizationChoiceRow(
                  title: trait.label,
                  subtitle:
                      (_traits[trait] ?? TraitLevel.standard) ==
                          TraitLevel.standard
                      ? null
                      : _traits[trait] == TraitLevel.more
                      ? trait.more
                      : trait.less,
                  radius: BorderRadius.vertical(
                    top: Radius.circular(
                      trait == ResponseTrait.values.first ? 26 : 4,
                    ),
                    bottom: Radius.circular(
                      trait == ResponseTrait.values.last ? 26 : 4,
                    ),
                  ),
                  selected: (_traits[trait] ?? TraitLevel.standard).name,
                  choices: [
                    PersonalizationChoice('more', '增强', trait.more),
                    const PersonalizationChoice('standard', '默认', ''),
                    PersonalizationChoice('less', '减弱', trait.less),
                  ],
                  onChanged: (value) => _set(trait, value),
                ),
                const SizedBox(height: 2),
              ],
              const SizedBox(height: 30),
              Material(
                color: settingsFieldColor(context),
                borderRadius: BorderRadius.circular(26),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _traits.values.any((v) => v != TraitLevel.standard)
                      ? () {
                          setState(_traits.clear);
                          widget.onChanged(Map.of(_traits));
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      '重置特征',
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            _traits.values.any((v) => v != TraitLevel.standard)
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).disabledColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
