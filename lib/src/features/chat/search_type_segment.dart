import 'package:flutter/material.dart';

class SearchTypeSegment extends StatelessWidget {
  const SearchTypeSegment({
    super.key,
    required this.files,
    required this.onChanged,
    this.labels = const ['会话', '文件'],
  });
  final List<String> labels;
  final bool files;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 196,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? const Color(0xff262626) : const Color(0xfff3f3f3),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedAlign(
                  alignment: files
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: FractionallySizedBox(
                    widthFactor: .5,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xff454545) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final value in [false, true])
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: files == value,
                        inMutuallyExclusiveGroup: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (files != value) onChanged(value);
                          },
                          child: Center(
                            child: Text(
                              labels[value ? 1 : 0],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
