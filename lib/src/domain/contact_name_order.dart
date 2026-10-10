import 'package:lpinyin/lpinyin.dart';
import 'message_sender.dart';

extension ContactNameOrdering<T> on Iterable<T> {
  List<T> byContactName(MessageSender Function(T) senderOf) {
    final entries = map((item) {
      final sender = senderOf(item);
      return (item, ContactNameOrder(sender.id, sender.displayName));
    }).toList()..sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final entry in entries) entry.$1];
  }
}

class ContactNameOrder implements Comparable<ContactNameOrder> {
  ContactNameOrder(this.id, String name)
    : spelling = PinyinHelper.getPinyinE(
        name,
        separator: '',
        format: PinyinFormat.WITHOUT_TONE,
      ).toUpperCase(),
      name = name;
  final String id, name, spelling;
  String get section =>
      RegExp(r'^[A-Z]').hasMatch(spelling) ? spelling.substring(0, 1) : '#';

  @override
  int compareTo(ContactNameOrder other) {
    final group = (section == '#' ? 1 : 0).compareTo(
      other.section == '#' ? 1 : 0,
    );
    if (group != 0) return group;
    final letters = spelling.compareTo(other.spelling);
    if (letters != 0) return letters;
    final names = name.compareTo(other.name);
    return names != 0 ? names : id.compareTo(other.id);
  }
}
