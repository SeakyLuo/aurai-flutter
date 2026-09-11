import 'package:flutter/material.dart';

typedef Choice<T> = ({T value, String label});

Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<Choice<T>> choices,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (_) =>
      _ChoiceSheet(title: title, selected: selected, choices: choices),
);

class _ChoiceSheet<T> extends StatefulWidget {
  const _ChoiceSheet({
    required this.title,
    required this.selected,
    required this.choices,
  });
  final String title;
  final T selected;
  final List<Choice<T>> choices;
  @override
  State<_ChoiceSheet<T>> createState() => _ChoiceSheetState<T>();
}

class _ChoiceSheetState<T> extends State<_ChoiceSheet<T>> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final choices = widget.choices
        .where((choice) => choice.label.toLowerCase().contains(query))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: widget.choices.length > 8 ? 0.8 : 0.48,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xffdfdfdf),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 22),
                    ),
                  ],
                ),
              ),
              if (widget.choices.length > 8)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '搜索模型',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清空搜索',
                              onPressed: () => setState(_search.clear),
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
              Expanded(
                child: choices.isEmpty
                    ? const Center(
                        child: Text(
                          '没有匹配的模型',
                          style: TextStyle(color: Color(0xff808080)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                        itemCount: choices.length,
                        itemBuilder: (context, index) {
                          final choice = choices[index];
                          final selected = choice.value == widget.selected;
                          return Semantics(
                            selected: selected,
                            button: true,
                            child: Material(
                              color: selected
                                  ? const Color(0xffedf6ff)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () =>
                                    Navigator.pop(context, choice.value),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          choice.label,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: selected
                                                ? const Color(0xff087cf0)
                                                : const Color(0xff242424),
                                          ),
                                        ),
                                      ),
                                      if (selected)
                                        const Icon(
                                          Icons.check_rounded,
                                          color: Color(0xff087cf0),
                                          size: 21,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChoiceField extends StatelessWidget {
  const ChoiceField({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: Material(
      color: const Color(0xfff5f6f8),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: onTap == null
                        ? const Color(0xff929292)
                        : const Color(0xff242424),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.unfold_more_rounded,
                size: 20,
                color: Color(0xff878b92),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
