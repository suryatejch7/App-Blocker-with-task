class AppEntry {
  String id;
  String name;
  String packageName;
  String notes;

  AppEntry(
      {required this.id,
      required this.name,
      required this.packageName,
      this.notes = ''});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'packageName': packageName,
        'notes': notes,
      };

  static AppEntry fromJson(Map<String, dynamic> j) {
    final packageName = (j['packageName']?.toString() ?? '').trim();
    final name = (j['name']?.toString() ?? '').trim();
    final rawId = (j['id']?.toString() ?? '').trim();
    final derivedId = packageName.isNotEmpty ? packageName : name;

    return AppEntry(
      id: rawId.isNotEmpty ? rawId : derivedId,
      name: name,
      packageName: packageName,
      notes: (j['notes']?.toString() ?? ''),
    );
  }
}
