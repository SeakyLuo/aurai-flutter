import 'package:flutter/material.dart';
import 'glass_surface.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class PersonalizationChoice {
  const PersonalizationChoice(this.value, this.label, this.description);
  final String value;
  final String label;
  final String description;
}

class PersonalizationChoiceRow extends StatefulWidget {
  const PersonalizationChoiceRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.choices,
    required this.onChanged,
    this.radius = const BorderRadius.all(Radius.circular(26)),
  });
  final String title;
  final String? subtitle;
  final String selected;
  final List<PersonalizationChoice> choices;
  final ValueChanged<String>? onChanged;
  final BorderRadius radius;
  @override
  State<PersonalizationChoiceRow> createState() =>
      _PersonalizationChoiceRowState();
}

class _PersonalizationChoiceRowState extends State<PersonalizationChoiceRow> {
  final _anchor = GlobalKey();
  bool _open = false;

  Future<void> _choose() async {
    final box = _anchor.currentContext!.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
      Offset.zero & overlay.size,
    );
    setState(() => _open = true);
    final selected = await showMenu<String>(
      context: context,
      position: position,
      initialValue: widget.selected,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      menuPadding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 310),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: GlassSurface(
            radius: 26,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final choice in widget.choices)
                    Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.pop(context, choice.value),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      choice.label,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                    if (choice.description.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        choice.description,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox.square(
                                dimension: 24,
                                child: choice.value == widget.selected
                                    ? const SettingsIcon(
                                        type: SettingsIconType.check,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (selected != null) widget.onChanged!(selected);
  }

  @override
  Widget build(BuildContext context) => Material(
    key: _anchor,
    color: settingsFieldColor(context),
    borderRadius: widget.radius,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: widget.onChanged == null ? null : _choose,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: const TextStyle(fontSize: 16)),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedRotation(
              turns: _open ? -.25 : .25,
              duration: const Duration(milliseconds: 180),
              child: const SettingsIcon(type: SettingsIconType.chevron),
            ),
          ],
        ),
      ),
    ),
  );
}
