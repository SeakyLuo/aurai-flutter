import 'package:flutter/material.dart';
import '../../domain/profile_gender.dart';
import 'personalization_controls.dart';

class ProfileGenderField extends StatelessWidget {
  const ProfileGenderField({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final ProfileGender value;
  final ValueChanged<ProfileGender>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: Text(
          '性别',
          style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      PersonalizationChoiceRow(
        title: value.label,
        selected: value.name,
        choices: [
          for (final gender in ProfileGender.values)
            PersonalizationChoice(gender.name, gender.label, ''),
        ],
        onChanged: onChanged == null
            ? null
            : (value) => onChanged!(ProfileGender.values.byName(value)),
      ),
    ],
  );
}
