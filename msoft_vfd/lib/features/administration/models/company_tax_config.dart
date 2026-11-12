class CompanyTaxConfig {
  final String id;
  final String companyId;
  final String taxTypeId;
  final String taxTypeName;
  final int? status;

  const CompanyTaxConfig({
    required this.id,
    required this.companyId,
    required this.taxTypeId,
    required this.taxTypeName,
    this.status,
  });

  bool get isActive => status != 0;

  factory CompanyTaxConfig.fromJson(Map<String, dynamic> json) => CompanyTaxConfig(
        id: json['id'].toString(),
        companyId: json['companyId'].toString(),
        taxTypeId: json['taxTypeId'].toString(),
        taxTypeName: json['taxTypeName'] as String? ?? '',
        status: json['status'] as int?,
      );
}

class CompanyTaxConfigInput {
  final String companyId;
  final String taxTypeId;
  final int? status;

  const CompanyTaxConfigInput({
    required this.companyId,
    required this.taxTypeId,
    this.status,
  });

  Map<String, dynamic> toJson() => {
        'companyId': companyId,
        'taxTypeId': taxTypeId,
        'status': status,
      };
}
