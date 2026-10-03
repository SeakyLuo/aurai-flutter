import 'package:flutter/material.dart';
import '../../app/global_ui.dart';
import '../../domain/profile_gender.dart';
import '../../domain/speech_voice.dart';
import 'speech_voice_avatar.dart';
import 'settings_icon.dart';
import 'speech_voice_details_sheet.dart';

class SpeechVoiceRow extends StatelessWidget {
  const SpeechVoiceRow({
    super.key,
    required this.voice,
    required this.selected,
    required this.preview,
    required this.onTap,
    this.onRename,
    this.detailsOnLongPress = false,
  });
  final SpeechVoice voice;
  final bool selected;
  final bool detailsOnLongPress;
  final Widget preview;
  final VoidCallback? onTap;
  final Future<bool> Function(SpeechVoice)? onRename;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final details = voice.details;
    final gender = switch (details?.gender) {
      'male' => ProfileGender.male,
      'female' => ProfileGender.female,
      _ => ProfileGender.unknown,
    };
    return Semantics(
      selected: selected,
      child: Material(
        color: selected
            ? (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xff292a2e)
                  : const Color(0xfff1f2f4))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          onLongPress: detailsOnLongPress
              ? () => showSpeechVoiceDetails(context, voice, onRename: onRename)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SpeechVoiceAvatar(
                      name: voice.name,
                      avatarUrl: voice.avatarUrl,
                    ),
                    if (selected)
                      Positioned(
                        left: -3,
                        top: -4,
                        child: Container(
                          width: 21,
                          height: 21,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.onSurface,
                            border: Border.all(
                              color: colors.surface,
                              width: 1.5,
                            ),
                          ),
                          child: SettingsIcon(
                            type: SettingsIconType.check,
                            color: colors.surface,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              voice.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (gender != ProfileGender.unknown) ...[
                            const SizedBox(width: 6),
                            Text(
                              gender == ProfileGender.male ? '♂' : '♀',
                              semanticsLabel: gender.label,
                              style: TextStyle(
                                fontSize: 16,
                                color: gender == ProfileGender.male
                                    ? GlobalUI.maleColor
                                    : GlobalUI.femaleColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (details != null && details.tags.isNotEmpty)
                        Text(
                          details.tags.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      if (details != null && details.description.isNotEmpty)
                        Text(
                          details.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                preview,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
