class TaxType {
  final String id;
  final String taxCode;
  final String taxName;
  final int? taxPercent;
  final String? taxCategoryName;

  const TaxType({
    required this.id,
    required this.taxCode,
    required this.taxName,
    this.taxPercent,
    this.taxCategoryName,
  });

  factory TaxType.fromJson(Map<String, dynamic> json) => TaxType(
        id: json['id'].toString(),
        taxCode: json['taxCode'] as String? ?? '',
        taxName: json['taxName'] as String? ?? '',
        taxPercent: json['taxPercent'] as int?,
        taxCategoryName: json['taxCategoryName'] as String?,
      );
}
