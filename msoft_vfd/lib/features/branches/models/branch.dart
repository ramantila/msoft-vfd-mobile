import '../../auth/models/session.dart';
import '../../products/models/product.dart';
import '../../sales/models/sale_list_item.dart';
import '../../users/models/staff.dart';

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
List<String> _strings(Object? v) => (v as List<dynamic>? ?? const []).map((e) => e.toString()).toList();

/// A branch with live figures, from /api/v1/mobile/branches.
class BranchItem {
  final String id;
  final String branchName;
  final String? location;
  final int? capacity;
  final int staffCount;
  final int activeStaff;
  final int salesToday;
  final double totalToday;
  final double totalThisMonth;
  final int lowStock;
  final int outOfStock;
  final int customerCount;
  final bool mine;

  const BranchItem({
    required this.id,
    required this.branchName,
    this.location,
    this.capacity,
    required this.staffCount,
    required this.activeStaff,
    required this.salesToday,
    required this.totalToday,
    required this.totalThisMonth,
    required this.lowStock,
    required this.outOfStock,
    required this.customerCount,
    required this.mine,
  });

  bool get full => capacity != null && staffCount >= capacity!;
  int get stockAlerts => lowStock + outOfStock;

  factory BranchItem.fromJson(Map<String, dynamic> j) => BranchItem(
        id: j['id'].toString(),
        branchName: j['branchName'] as String? ?? '',
        location: j['location'] as String?,
        capacity: (j['capacity'] as num?)?.toInt(),
        staffCount: _i(j['staffCount']),
        activeStaff: _i(j['activeStaff']),
        salesToday: _i(j['salesToday']),
        totalToday: _d(j['totalToday']),
        totalThisMonth: _d(j['totalThisMonth']),
        lowStock: _i(j['lowStock']),
        outOfStock: _i(j['outOfStock']),
        customerCount: _i(j['customerCount']),
        mine: j['mine'] as bool? ?? false,
      );
}

class BranchSummary {
  final int branchCount;
  final int? maxBranches;
  final int? maxUsers;
  final String? packageName;
  final bool canAddMore;
  final double totalToday;
  final int salesToday;

  const BranchSummary({
    required this.branchCount,
    this.maxBranches,
    this.maxUsers,
    this.packageName,
    required this.canAddMore,
    required this.totalToday,
    required this.salesToday,
  });

  factory BranchSummary.fromJson(Map<String, dynamic> j) => BranchSummary(
        branchCount: _i(j['branchCount']),
        maxBranches: (j['maxBranches'] as num?)?.toInt(),
        maxUsers: (j['maxUsers'] as num?)?.toInt(),
        packageName: j['packageName'] as String?,
        canAddMore: j['canAddMore'] as bool? ?? true,
        totalToday: _d(j['totalToday']),
        salesToday: _i(j['salesToday']),
      );
}

class BranchStaffMember {
  final String id;
  final String fullName;
  final UserRole role;
  final StaffStatus status;
  const BranchStaffMember({required this.id, required this.fullName, required this.role, required this.status});
}

class BranchStockAlert {
  final String productId;
  final String productName;
  final int quantityOnHand;
  final int reorderLevel;
  final StockStatus status;
  const BranchStockAlert({
    required this.productId,
    required this.productName,
    required this.quantityOnHand,
    required this.reorderLevel,
    required this.status,
  });
}

class BranchDeleteCheck {
  final bool allowed;
  final List<String> blockers;
  final List<String> notes;
  const BranchDeleteCheck({required this.allowed, required this.blockers, required this.notes});
}

class BranchDetail {
  final String id;
  final String branchName;
  final String? location;
  final int? noOfEmployee;
  final DateTime? createdAt;
  final BranchItem figures;
  final List<BranchStaffMember> staff;
  final List<BranchStockAlert> stockAlerts;
  final List<SaleListItem> recentSales;
  final BranchDeleteCheck deleteCheck;

  const BranchDetail({
    required this.id,
    required this.branchName,
    this.location,
    this.noOfEmployee,
    this.createdAt,
    required this.figures,
    required this.staff,
    required this.stockAlerts,
    required this.recentSales,
    required this.deleteCheck,
  });

  factory BranchDetail.fromJson(Map<String, dynamic> j) {
    final b = j['branch'] as Map<String, dynamic>;
    final dc = j['deleteCheck'] as Map<String, dynamic>? ?? const {};
    List<Map<String, dynamic>> list(String k) =>
        (j[k] as List<dynamic>? ?? const []).map((e) => e as Map<String, dynamic>).toList();
    return BranchDetail(
      id: b['id'].toString(),
      branchName: b['branchName'] as String? ?? '',
      location: b['location'] as String?,
      noOfEmployee: (b['noOfEmployee'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(b['createdAt']?.toString() ?? '')?.toLocal(),
      figures: BranchItem.fromJson(j['figures'] as Map<String, dynamic>),
      staff: list('staff')
          .map((s) => BranchStaffMember(
                id: s['id'].toString(),
                fullName: s['fullName'] as String? ?? '',
                role: UserRoleX.parse(s['role'] as String?),
                status: StaffStatusX.parse(s['status'] as String?),
              ))
          .toList(),
      stockAlerts: list('stockAlerts')
          .map((a) => BranchStockAlert(
                productId: a['productId'].toString(),
                productName: a['productName'] as String? ?? '',
                quantityOnHand: _i(a['quantityOnHand']),
                reorderLevel: _i(a['reorderLevel']),
                status: StockStatusX.parse(a['status'] as String?) ?? StockStatus.lowStock,
              ))
          .toList(),
      recentSales: list('recentSales').map(SaleListItem.fromJson).toList(),
      deleteCheck: BranchDeleteCheck(
        allowed: dc['allowed'] as bool? ?? false,
        blockers: _strings(dc['blockers']),
        notes: _strings(dc['notes']),
      ),
    );
  }
}

class BranchInput {
  final String branchName;
  final String? location;
  final int? noOfEmployee;
  const BranchInput({required this.branchName, this.location, this.noOfEmployee});

  Map<String, dynamic> toJson() => {
        'branchName': branchName,
        'location': ?location,
        'noOfEmployee': ?noOfEmployee,
      };
}
