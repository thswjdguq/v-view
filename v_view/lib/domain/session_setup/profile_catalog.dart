enum ProfileCatalogType { school, certification }

String normalizeProfileName(String value) =>
    value.replaceAll(RegExp(r'\s+'), '').toLowerCase();

class ProfileCatalogEntry {
  const ProfileCatalogEntry({
    required this.name,
    this.detail = '',
    this.aliases = const [],
    this.sortOrder = 100,
  });
  final String name;
  final String detail;
  final List<String> aliases;
  final int sortOrder;
  factory ProfileCatalogEntry.fromMap(Map<String, dynamic> value) =>
      ProfileCatalogEntry(
        name: value['name'] as String,
        detail: value['detail'] as String? ?? '',
        aliases: List<String>.from(value['aliases'] as List? ?? []),
        sortOrder: value['sortOrder'] as int? ?? 100,
      );
  bool hasExactName(String query) => [
    name,
    ...aliases,
  ].any((v) => normalizeProfileName(v) == normalizeProfileName(query));
}

List<ProfileCatalogEntry> searchProfileCatalog(
  List<ProfileCatalogEntry> entries,
  String query,
) {
  final key = normalizeProfileName(query);
  final result = entries
      .where(
        (entry) =>
            key.isEmpty ||
            [
              entry.name,
              entry.detail,
              ...entry.aliases,
            ].any((v) => normalizeProfileName(v).contains(key)),
      )
      .toList();
  int rank(ProfileCatalogEntry entry) => key.isEmpty
      ? 2
      : entry.hasExactName(query)
      ? 0
      : normalizeProfileName(entry.name).startsWith(key)
      ? 1
      : 2;
  result.sort((a, b) {
    final order = rank(a).compareTo(rank(b));
    if (order != 0) return order;
    final preset = a.sortOrder.compareTo(b.sortOrder);
    return preset == 0 ? a.name.compareTo(b.name) : preset;
  });
  return result;
}
