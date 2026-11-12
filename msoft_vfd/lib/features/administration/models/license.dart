enum LicenseStatus { pendingPayment, active, suspended, expired, cancelled }

extension LicenseStatusX on LicenseStatus {
  static LicenseStatus parse(String? value) {
    final normalized = value?.replaceAll('_', '').toUpperCase();
    return LicenseStatus.values.firstWhere(
      (s) => s.name.toUpperCase() == normalized,
      orElse: () => LicenseStatus.pendingPayment,
    );
  }

  String get label => switch (this) {
        LicenseStatus.pendingPayment => 'Pending payment',
        LicenseStatus.active => 'Active',
        LicenseStatus.suspended => 'Suspended',
        LicenseStatus.expired => 'Expired',
        LicenseStatus.cancelled => 'Cancelled',
      };
}

/// Read-only mirror of CSP's LicenseResponse. License lifecycle actions
/// (renew/suspend/cancel/confirm-payment) are billing operations owned by
/// ADP — this app only ever displays license state, never mutates it.
class License {
  final String id;
  final String companyId;
  final String packageId;
  final String licenseKey;
  final LicenseStatus status;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final int durationMonths;
  final double amountTzs;
  final bool paid;
  final int maxUsers;
  final int maxBranches;
  final int maxDevices;
  final int monthlyReceiptQuota;
  final DateTime? createdAt;

  const License({
    required this.id,
    required this.companyId,
    required this.packageId,
    required this.licenseKey,
    required this.status,
    required this.startsAt,
    required this.expiresAt,
    required this.durationMonths,
    required this.amountTzs,
    required this.paid,
    required this.maxUsers,
    required this.maxBranches,
    required this.maxDevices,
    required this.monthlyReceiptQuota,
    required this.createdAt,
  });

  /// Whole days until [expiresAt] (from today, dates only). Negative once
  /// past expiry. Null if the license has no expiry date on record.
  int? get daysLeft {
    final exp = expiresAt;
    if (exp == null) return null;
    final today = DateTime.now();
    final from = DateTime(today.year, today.month, today.day);
    final to = DateTime(exp.year, exp.month, exp.day);
    return to.difference(from).inDays;
  }

  /// Fraction of the license's total duration already elapsed, clamped to
  /// [0, 1] — for a progress indicator. Null if start/expiry aren't known.
  double? get elapsedFraction {
    final start = startsAt;
    final exp = expiresAt;
    if (start == null || exp == null) return null;
    final total = exp.difference(start).inSeconds;
    if (total <= 0) return 1;
    final elapsed = DateTime.now().difference(start).inSeconds;
    return (elapsed / total).clamp(0, 1).toDouble();
  }

  static DateTime? _parseDate(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;

  factory License.fromJson(Map<String, dynamic> json) => License(
        id: json['id'].toString(),
        companyId: json['companyId'].toString(),
        packageId: json['packageId'].toString(),
        licenseKey: json['licenseKey'] as String? ?? '',
        status: LicenseStatusX.parse(json['status'] as String?),
        startsAt: _parseDate(json['startsAt']),
        expiresAt: _parseDate(json['expiresAt']),
        durationMonths: json['durationMonths'] as int? ?? 0,
        amountTzs: (json['amountTzs'] as num?)?.toDouble() ?? 0,
        paid: json['paid'] as bool? ?? false,
        maxUsers: json['maxUsers'] as int? ?? 0,
        maxBranches: json['maxBranches'] as int? ?? 0,
        maxDevices: json['maxDevices'] as int? ?? 0,
        monthlyReceiptQuota: json['monthlyReceiptQuota'] as int? ?? 0,
        createdAt: _parseDate(json['createdAt']),
      );
}
