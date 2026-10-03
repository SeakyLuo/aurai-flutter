import 'package:flutter/material.dart';

import 'settings_icon.dart';
import 'speech_readout.dart';

class SpeechReadoutButton extends StatelessWidget {
  const SpeechReadoutButton({
    super.key,
    required this.messageKey,
    required this.onPressed,
  });
  final Object messageKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: speechReadoutState,
    builder: (context, state, _) {
      final phase = state?.key == messageKey ? state?.phase : null;
      final color = Theme.of(context).colorScheme.onSurfaceVariant;
      return IconButton(
        tooltip: switch (phase) {
          SpeechReadoutPhase.loading => '取消加载',
          SpeechReadoutPhase.playing => '暂停朗读',
          null => '朗读',
        },
        onPressed: onPressed,
        icon: switch (phase) {
          SpeechReadoutPhase.loading => SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 1.65, color: color),
          ),
          SpeechReadoutPhase.playing => _PlayingWave(color: color),
          null => SettingsIcon(type: SettingsIconType.sound, color: color),
        },
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(32),
          minimumSize: const Size.square(32),
          padding: const EdgeInsets.all(4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    },
  );
}

/// Matches SMPlayer's four rounded bars and staggered 800 ms rhythm.
class _PlayingWave extends StatefulWidget {
  const _PlayingWave({required this.color});
  final Color color;
  @override
  State<_PlayingWave> createState() => _PlayingWaveState();
}

class _PlayingWaveState extends State<_PlayingWave>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 24,
    child: AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < 4; index++)
            Container(
              width: 2,
              height: _height(index),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
        ],
      ),
    ),
  );

  double _height(int index) {
    final phase = (_animation.value - index * .25) % 1;
    final triangle = phase <= .5 ? phase * 2 : (1 - phase) * 2;
    return 5 + Curves.easeInOut.transform(triangle) * 10;
  }
}
