enum CompanyStatus { active, suspended, trial, deleted }

extension CompanyStatusX on CompanyStatus {
  static CompanyStatus parse(String? value) => CompanyStatus.values.firstWhere(
        (s) => s.name.toUpperCase() == value?.toUpperCase(),
        orElse: () => CompanyStatus.active,
      );

  String get label => switch (this) {
        CompanyStatus.active => 'Active',
        CompanyStatus.suspended => 'Suspended',
        CompanyStatus.trial => 'Trial',
        CompanyStatus.deleted => 'Deleted',
      };
}

class Company {
  final String id;
  final String businessName;
  final String tin;
  final String? vrn;
  final String phone;
  final String? email;
  final String? address;
  final CompanyStatus status;
  final Map<String, dynamic>? packageInfo;
  final DateTime? registeredAt;
  final DateTime? suspendedAt;
  final String? suspendReason;

  const Company({
    required this.id,
    required this.businessName,
    required this.tin,
    this.vrn,
    required this.phone,
    this.email,
    this.address,
    required this.status,
    this.packageInfo,
    this.registeredAt,
    this.suspendedAt,
    this.suspendReason,
  });

  /// CSP's CompanyMapper only ever populates `packageId`/`packageName` on
  /// this map — the full plan details (limits, pricing) live at
  /// `GET /api/v1/packages/{packageId}`, fetched separately.
  String? get packageId => packageInfo?['packageId']?.toString();

  factory Company.fromJson(Map<String, dynamic> json) => Company(
        id: json['id'].toString(),
        businessName: json['businessName'] as String? ?? '',
        tin: json['tin'] as String? ?? '',
        vrn: json['vrn'] as String?,
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String?,
        address: json['address'] as String?,
        status: CompanyStatusX.parse(json['status'] as String?),
        packageInfo: json['packageDto'] as Map<String, dynamic>?,
        registeredAt: json['registeredAt'] != null
            ? DateTime.tryParse(json['registeredAt'] as String)
            : null,
        suspendedAt: json['suspendedAt'] != null
            ? DateTime.tryParse(json['suspendedAt'] as String)
            : null,
        suspendReason: json['suspendReason'] as String?,
      );
}
