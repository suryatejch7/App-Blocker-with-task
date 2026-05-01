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

  static WebsiteEntry fromJson(Map<String, dynamic> j) {
    final url = (j['url']?.toString() ?? '').trim();
    final title = (j['title']?.toString() ?? '').trim();
    final rawId = (j['id']?.toString() ?? '').trim();
    final derivedId = url.isNotEmpty ? url : title;

    return WebsiteEntry(
      id: rawId.isNotEmpty ? rawId : derivedId,
      title: title,
      url: url,
      notes: (j['notes']?.toString() ?? ''),
    );
  }
}
