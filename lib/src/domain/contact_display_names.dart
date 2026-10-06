/// Private contact labels used by the local interface, never AI identities.
abstract final class ContactDisplayNames {
  static final _names = <String, String>{};

  static String? remark(String id) => _names[id];

  static void replace(Map<String, String> names) {
    _names
      ..clear()
      ..addAll(names);
  }

  static void set(String id, String name) {
    if (name.isEmpty) {
      _names.remove(id);
    } else {
      _names[id] = name;
    }
  }
}
