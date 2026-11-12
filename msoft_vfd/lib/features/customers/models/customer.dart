import '../../sales/models/sale_list_item.dart';

enum CustomerStatus { active, inactive, suspended }

extension CustomerStatusX on CustomerStatus {
  static CustomerStatus parse(String? value) => CustomerStatus.values.firstWhere(
        (s) => s.name.toUpperCase() == value?.toUpperCase(),
        orElse: () => CustomerStatus.active,
      );

  String get cspName => name.toUpperCase();

  String get label => switch (this) {
        CustomerStatus.active => 'Active',
        CustomerStatus.inactive => 'Inactive',
        CustomerStatus.suspended => 'Suspended',
      };
}

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
String? _s(Object? v) => v?.toString();
DateTime? _t(Object? v) => DateTime.tryParse(v?.toString() ?? '')?.toLocal();

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return '$first$last'.toUpperCase();
}

/// Mirrors CSP's CustomerResponse.
class Customer {
  final String id;
  final String customerName;
  final String? email;
  final String? phone;
  final String? address;
  final String? vrn;
  final String? idTypeId;
  final String? idTypeName;
  final String? idNumber;
  final String? branchId;
  final String? branchName;
  final CustomerStatus status;
  final DateTime? createdAt;

  const Customer({
    required this.id,
    required this.customerName,
    this.email,
    this.phone,
    this.address,
    this.vrn,
    this.idTypeId,
    this.idTypeName,
    this.idNumber,
    this.branchId,
    this.branchName,
    required this.status,
    this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'].toString(),
        customerName: json['customerName'] as String? ?? '',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        vrn: json['vrn'] as String?,
        idTypeId: _s(json['idTypeId']),
        idTypeName: json['idTypeName'] as String?,
        idNumber: json['idNumber'] as String?,
        branchId: _s(json['branchId']),
        branchName: json['branchName'] as String?,
        status: CustomerStatusX.parse(json['status'] as String?),
        createdAt: _t(json['createdAt']),
      );
}

/// A row from /api/v1/mobile/customers with completed-sale totals.
class CustomerItem {
  final String id;
  final String customerName;
  final String? phone;
  final String? email;
  final String? vrn;
  final CustomerStatus status;
  final String? branchName;
  final int saleCount;
  final double totalSpent;
  final DateTime? lastSaleAt;

  const CustomerItem({
    required this.id,
    required this.customerName,
    this.phone,
    this.email,
    this.vrn,
    required this.status,
    this.branchName,
    required this.saleCount,
    required this.totalSpent,
    this.lastSaleAt,
  });

  factory CustomerItem.fromJson(Map<String, dynamic> json) => CustomerItem(
        id: json['id'].toString(),
        customerName: json['customerName'] as String? ?? '',
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        vrn: json['vrn'] as String?,
        status: CustomerStatusX.parse(json['status'] as String?),
        branchName: json['branchName'] as String?,
        saleCount: _i(json['saleCount']),
        totalSpent: _d(json['totalSpent']),
        lastSaleAt: _t(json['lastSaleAt']),
      );

  factory CustomerItem.fromCustomer(Customer c) => CustomerItem(
        id: c.id,
        customerName: c.customerName,
        phone: c.phone,
        email: c.email,
        vrn: c.vrn,
        status: c.status,
        branchName: c.branchName,
        saleCount: 0,
        totalSpent: 0,
      );
}

class CustomerDetail {
  final Customer customer;
  final int saleCount;
  final double totalSpent;
  final double averageSale;
  final DateTime? firstSaleAt;
  final DateTime? lastSaleAt;
  final List<SaleListItem> recentSales;

  const CustomerDetail({
    required this.customer,
    required this.saleCount,
    required this.totalSpent,
    required this.averageSale,
    this.firstSaleAt,
    this.lastSaleAt,
    required this.recentSales,
  });

  factory CustomerDetail.fromJson(Map<String, dynamic> json) => CustomerDetail(
        customer: Customer.fromJson(json['customer'] as Map<String, dynamic>),
        saleCount: _i(json['saleCount']),
        totalSpent: _d(json['totalSpent']),
        averageSale: _d(json['averageSale']),
        firstSaleAt: _t(json['firstSaleAt']),
        lastSaleAt: _t(json['lastSaleAt']),
        recentSales: (json['recentSales'] as List<dynamic>? ?? const [])
            .map((e) => SaleListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CustomerSummary {
  final int total;
  final int active;
  final int inactive;
  final int suspended;
  final int newThisMonth;

  const CustomerSummary({
    required this.total,
    required this.active,
    required this.inactive,
    required this.suspended,
    required this.newThisMonth,
  });

  factory CustomerSummary.fromJson(Map<String, dynamic> json) => CustomerSummary(
        total: _i(json['total']),
        active: _i(json['active']),
        inactive: _i(json['inactive']),
        suspended: _i(json['suspended']),
        newThisMonth: _i(json['newThisMonth']),
      );
}

class IdTypeOption {
  final String id;
  final int? code;
  final String name;
  const IdTypeOption({required this.id, this.code, required this.name});
}

class CustomerFormOptions {
  final List<IdTypeOption> idTypes;
  final String? defaultBranchId;
  final String? defaultBranchName;

  const CustomerFormOptions({required this.idTypes, this.defaultBranchId, this.defaultBranchName});

  factory CustomerFormOptions.fromJson(Map<String, dynamic> json) => CustomerFormOptions(
        idTypes: (json['idTypes'] as List<dynamic>? ?? const [])
            .map((e) => e as Map<String, dynamic>)
            .map((t) => IdTypeOption(
                  id: t['id'].toString(),
                  code: (t['code'] as num?)?.toInt(),
                  name: t['name'] as String? ?? '',
                ))
            .toList(),
        defaultBranchId: _s(json['defaultBranchId']),
        defaultBranchName: json['defaultBranchName'] as String?,
      );
}

/// Body for create / update.
class CustomerInput {
  final String customerName;
  final String? phone;
  final String? email;
  final String? address;
  final String? vrn;
  final String? idTypeId;
  final String? idNumber;
  final CustomerStatus? status;

  const CustomerInput({
    required this.customerName,
    this.phone,
    this.email,
    this.address,
    this.vrn,
    this.idTypeId,
    this.idNumber,
    this.status,
  });

  Map<String, dynamic> toJson() => {
        'customerName': customerName,
        'phone': ?phone,
        'email': ?email,
        'address': ?address,
        'vrn': ?vrn,
        'idTypeId': ?idTypeId,
        'idNumber': ?idNumber,
        'status': ?status?.cspName,
      };
}
