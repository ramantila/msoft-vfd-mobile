enum PackageStatus { active, inactive, deleted }

extension PackageStatusX on PackageStatus {
  static PackageStatus parse(String? value) => PackageStatus.values.firstWhere(
        (s) => s.name.toUpperCase() == value?.toUpperCase(),
        orElse: () => PackageStatus.active,
      );

  String get label => switch (this) {
        PackageStatus.active => 'Active',
        PackageStatus.inactive => 'Inactive',
        PackageStatus.deleted => 'Deleted',
      };
}

/// Read-only mirror of CSP's PackageDto — subscription plan details for the
/// company's assigned package. Fetched via `GET /api/v1/packages/{id}` for
/// display only; package definitions themselves are managed via ADP.
class ServicePackage {
  final String id;
  final String name;
  final String? description;
  final int monthlyReceipts;
  final double priceTzs;
  final double? pricePerYearTzs;
  final int maxUsers;
  final int maxBranches;
  final int maxDevices;
  final int licenseDurationMonths;
  final PackageStatus status;
  final bool allowCspLogin;

  const ServicePackage({
    required this.id,
    required this.name,
    this.description,
    required this.monthlyReceipts,
    required this.priceTzs,
    this.pricePerYearTzs,
    required this.maxUsers,
    required this.maxBranches,
    required this.maxDevices,
    required this.licenseDurationMonths,
    required this.status,
    required this.allowCspLogin,
  });

  factory ServicePackage.fromJson(Map<String, dynamic> json) => ServicePackage(
        id: json['id'].toString(),
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        monthlyReceipts: json['monthlyReceipts'] as int? ?? 0,
        priceTzs: (json['priceTzs'] as num?)?.toDouble() ?? 0,
        pricePerYearTzs: (json['pricePerYearTzs'] as num?)?.toDouble(),
        maxUsers: json['maxUsers'] as int? ?? 0,
        maxBranches: json['maxBranches'] as int? ?? 0,
        maxDevices: json['maxDevices'] as int? ?? 0,
        licenseDurationMonths: json['licenseDurationMonths'] as int? ?? 0,
        status: PackageStatusX.parse(json['status'] as String?),
        allowCspLogin: json['allowCspLogin'] as bool? ?? true,
      );
}
