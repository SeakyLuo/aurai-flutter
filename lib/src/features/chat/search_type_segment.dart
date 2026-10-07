import 'package:flutter/material.dart';

class SearchTypeSegment extends StatelessWidget {
  const SearchTypeSegment({
    super.key,
    required this.files,
    required this.onChanged,
    this.labels = const ['任务', '文件'],
  }) : selectedIndex = null,
       onIndexChanged = null;
  const SearchTypeSegment.indexed({
    super.key,
    required this.labels,
    required int index,
    required ValueChanged<int> onChanged,
  }) : selectedIndex = index,
       onIndexChanged = onChanged,
       files = false,
       onChanged = null;
  final int? selectedIndex;
  final ValueChanged<int>? onIndexChanged;
  int get index => selectedIndex ?? (files ? 1 : 0);
  final List<String> labels;
  final bool files;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 98.0 * labels.length,
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
                  alignment: Alignment(-1 + 2 * index / (labels.length - 1), 0),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: FractionallySizedBox(
                    widthFactor: 1 / labels.length,
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
                  for (var value = 0; value < labels.length; value++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: index == value,
                        inMutuallyExclusiveGroup: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (index != value) {
                              if (onIndexChanged != null) {
                                onIndexChanged!(value);
                              } else {
                                onChanged!(value == 1);
                              }
                            }
                          },
                          child: Center(
                            child: Text(
                              labels[value],
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
