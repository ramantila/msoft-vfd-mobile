/// Parses a Spring Data `Page<T>` JSON body ({content, totalElements, ...}).
class PageResponse<T> {
  final List<T> content;
  final int totalElements;

  const PageResponse({required this.content, required this.totalElements});

  factory PageResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) =>
      PageResponse(
        content: (json['content'] as List<dynamic>? ?? const [])
            .map((e) => fromJson(e as Map<String, dynamic>))
            .toList(),
        totalElements: json['totalElements'] as int? ?? 0,
      );
}
