class ApiSearchResult {
  final String id;
  final String name;
  final String source;
  final String? thumbnailUrl;
  final String? year;

  ApiSearchResult({
    required this.id,
    required this.name,
    required this.source,
    this.thumbnailUrl,
    this.year,
  });
}
