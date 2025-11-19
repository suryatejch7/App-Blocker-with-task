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

  static AppEntry fromJson(Map<String, dynamic> j) => AppEntry(
        id: j['id'] as String,
        name: j['name'] as String,
        packageName: j['packageName'] as String,
        notes: j['notes'] as String? ?? '',
      );
}
