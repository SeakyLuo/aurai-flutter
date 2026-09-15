import 'package:flutter/material.dart';
import '../../storage/group_message_search.dart';

class GroupSearchTypeSegment extends StatelessWidget {
  const GroupSearchTypeSegment({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final GroupSearchType value;
  final ValueChanged<GroupSearchType> onChanged;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xff262626) : const Color(0xfff3f3f3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              alignment: Alignment(-1 + value.index * .5, 0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: FractionallySizedBox(
                widthFactor: .2,
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
              for (final type in GroupSearchType.values)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: value == type,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(type),
                      child: Center(
                        child: Text(
                          type.label,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
