class WebsiteEntry {
  String id;
  String title;
  String url;
  String notes;

  WebsiteEntry(
      {required this.id,
      required this.title,
      required this.url,
      this.notes = ''});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'notes': notes,
      };

  static WebsiteEntry fromJson(Map<String, dynamic> j) => WebsiteEntry(
        id: j['id'] as String,
        title: j['title'] as String,
        url: j['url'] as String,
        notes: j['notes'] as String? ?? '',
      );
}
