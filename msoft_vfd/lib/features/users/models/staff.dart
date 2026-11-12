import '../../auth/models/session.dart';
import '../../sales/models/sale_list_item.dart';

enum StaffStatus { active, inactive, suspended }

extension StaffStatusX on StaffStatus {
  static StaffStatus parse(String? value) => StaffStatus.values.firstWhere(
        (s) => s.name.toUpperCase() == value?.toUpperCase(),
        orElse: () => StaffStatus.active,
      );

  String get cspName => name.toUpperCase();

  String get label => switch (this) {
        StaffStatus.active => 'Active',
        StaffStatus.inactive => 'Inactive',
        StaffStatus.suspended => 'Suspended',
      };
}

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
DateTime? _t(Object? v) => DateTime.tryParse(v?.toString() ?? '')?.toLocal();
List<String> _strings(Object? v) => (v as List<dynamic>? ?? const []).map((e) => e.toString()).toList();

/// The "role" the web portal shows: the fixed enum is a placeholder for every
/// non-Super-Admin account, so the company's custom roles are what matter.
String staffRoleLabel(UserRole role, List<String> roleNames) {
  if (role == UserRole.superAdmin) return 'Super Admin';
  return roleNames.isEmpty ? 'No role assigned' : roleNames.join(', ');
}

/// Company-wide user quota from the active licence's package.
class UserQuota {
  final String packageName;
  final int maxUsers;
  final int currentUsers;
  const UserQuota({required this.packageName, required this.maxUsers, required this.currentUsers});

  bool get reached => currentUsers >= maxUsers;
  double get fraction => maxUsers <= 0 ? 1 : (currentUsers / maxUsers).clamp(0, 1).toDouble();

  static UserQuota? fromJson(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    return UserQuota(
      packageName: j['packageName'] as String? ?? '',
      maxUsers: _i(j['maxUsers']),
      currentUsers: _i(j['currentUsers']),
    );
  }
}

/// Mirrors CSP's UserResponse.
class StaffUser {
  final String id;
  final String? branchId;
  final String? branchName;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String phone;
  final UserRole role;
  final List<String> roleIds;
  final List<String> roleNames;
  final String username;
  final StaffStatus status;
  final bool systemGenerated;
  final DateTime? createdAt;

  const StaffUser({
    required this.id,
    this.branchId,
    this.branchName,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.phone,
    required this.role,
    required this.roleIds,
    required this.roleNames,
    required this.username,
    required this.status,
    required this.systemGenerated,
    this.createdAt,
  });

  String get fullName => [firstName, middleName, lastName].where((s) => s?.isNotEmpty == true).join(' ');

  String get roleLabel => staffRoleLabel(role, roleNames);
  bool get profileLocked => role == UserRole.superAdmin || systemGenerated;

  factory StaffUser.fromJson(Map<String, dynamic> json) => StaffUser(
        id: json['id'].toString(),
        branchId: json['branchId']?.toString(),
        branchName: json['branchName'] as String?,
        firstName: json['firstName'] as String? ?? '',
        middleName: json['middleName'] as String?,
        lastName: json['lastName'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        role: UserRoleX.parse(json['role'] as String?),
        roleIds: _strings(json['roleIds']),
        roleNames: _strings(json['roleNames'])..sort(),
        username: json['username'] as String? ?? '',
        status: StaffStatusX.parse(json['status'] as String?),
        systemGenerated: json['systemGenerated'] as bool? ?? false,
        createdAt: _t(json['createdAt']),
      );
}

/// A row from /api/v1/mobile/users with today's completed sales.
class StaffItem {
  final String id;
  final String fullName;
  final String username;
  final String phone;
  final UserRole role;
  final List<String> roleNames;
  final StaffStatus status;
  final String? branchName;
  final bool systemGenerated;
  final bool me;
  final int salesToday;
  final double totalToday;

  const StaffItem({
    required this.id,
    required this.fullName,
    required this.username,
    required this.phone,
    required this.role,
    required this.roleNames,
    required this.status,
    this.branchName,
    required this.systemGenerated,
    required this.me,
    required this.salesToday,
    required this.totalToday,
  });

  String get roleLabel => staffRoleLabel(role, roleNames);

  factory StaffItem.fromJson(Map<String, dynamic> json) => StaffItem(
        id: json['id'].toString(),
        fullName: json['fullName'] as String? ?? '',
        username: json['username'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        role: UserRoleX.parse(json['role'] as String?),
        roleNames: _strings(json['roleNames']),
        status: StaffStatusX.parse(json['status'] as String?),
        branchName: json['branchName'] as String?,
        systemGenerated: json['systemGenerated'] as bool? ?? false,
        me: json['me'] as bool? ?? false,
        salesToday: _i(json['salesToday']),
        totalToday: _d(json['totalToday']),
      );
}

/// What the server says the caller may do with this account.
class StaffActions {
  final bool edit;
  final bool changeStatus;
  final bool resetPassword;
  final bool delete;
  final String? lockedReason;

  const StaffActions({
    required this.edit,
    required this.changeStatus,
    required this.resetPassword,
    required this.delete,
    this.lockedReason,
  });

  factory StaffActions.fromJson(Map<String, dynamic>? json) => StaffActions(
        edit: json?['edit'] as bool? ?? false,
        changeStatus: json?['changeStatus'] as bool? ?? false,
        resetPassword: json?['resetPassword'] as bool? ?? false,
        delete: json?['delete'] as bool? ?? false,
        lockedReason: json?['lockedReason'] as String?,
      );
}

class StaffDetail {
  final StaffUser user;
  final bool me;
  final int salesToday;
  final double totalToday;
  final int salesThisMonth;
  final double totalThisMonth;
  final DateTime? lastSaleAt;
  final List<SaleListItem> recentSales;
  final StaffActions actions;

  const StaffDetail({
    required this.user,
    required this.me,
    required this.salesToday,
    required this.totalToday,
    required this.salesThisMonth,
    required this.totalThisMonth,
    this.lastSaleAt,
    required this.recentSales,
    required this.actions,
  });

  factory StaffDetail.fromJson(Map<String, dynamic> json) => StaffDetail(
        user: StaffUser.fromJson(json['user'] as Map<String, dynamic>),
        me: json['me'] as bool? ?? false,
        salesToday: _i(json['salesToday']),
        totalToday: _d(json['totalToday']),
        salesThisMonth: _i(json['salesThisMonth']),
        totalThisMonth: _d(json['totalThisMonth']),
        lastSaleAt: _t(json['lastSaleAt']),
        recentSales: (json['recentSales'] as List<dynamic>? ?? const [])
            .map((e) => SaleListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        actions: StaffActions.fromJson(json['actions'] as Map<String, dynamic>?),
      );
}

class StaffSummary {
  final int total;
  final int active;
  final int inactive;
  final int suspended;
  final int sellingToday;
  final Map<UserRole, int> byRole;
  final UserQuota? quota;

  const StaffSummary({
    required this.total,
    required this.active,
    required this.inactive,
    required this.suspended,
    required this.sellingToday,
    required this.byRole,
    this.quota,
  });

  factory StaffSummary.fromJson(Map<String, dynamic> json) => StaffSummary(
        total: _i(json['total']),
        active: _i(json['active']),
        inactive: _i(json['inactive']),
        suspended: _i(json['suspended']),
        sellingToday: _i(json['sellingToday']),
        byRole: {
          for (final e in (json['byRole'] as Map<String, dynamic>? ?? const {}).entries)
            UserRoleX.parse(e.key): _i(e.value),
        },
        quota: UserQuota.fromJson(json['quota']),
      );
}

class CustomRoleOption {
  final String id;
  final String name;
  final String? description;
  const CustomRoleOption({required this.id, required this.name, this.description});
}

class BranchOption {
  final String id;
  final String name;
  final int staffCount;
  final int? capacity;
  const BranchOption({required this.id, required this.name, required this.staffCount, this.capacity});

  bool get full => capacity != null && staffCount >= capacity!;
}

class StaffFormOptions {
  final List<UserRole> roles;
  final List<CustomRoleOption> customRoles;
  final List<BranchOption> branches;
  final UserQuota? quota;

  const StaffFormOptions({required this.roles, required this.customRoles, required this.branches, this.quota});

  factory StaffFormOptions.fromJson(Map<String, dynamic> json) => StaffFormOptions(
        roles: _strings(json['roles']).map(UserRoleX.parse).toList(),
        customRoles: (json['customRoles'] as List<dynamic>? ?? const [])
            .map((e) => e as Map<String, dynamic>)
            .map((r) => CustomRoleOption(
                id: r['id'].toString(), name: r['name'] as String? ?? '', description: r['description'] as String?))
            .toList(),
        branches: (json['branches'] as List<dynamic>? ?? const [])
            .map((e) => e as Map<String, dynamic>)
            .map((b) => BranchOption(
                  id: b['id'].toString(),
                  name: b['name'] as String? ?? '',
                  staffCount: _i(b['staffCount']),
                  capacity: (b['capacity'] as num?)?.toInt(),
                ))
            .toList(),
        quota: UserQuota.fromJson(json['quota']),
      );
}

/// Body for create / update. [password] is only sent on create. [role] is
/// left out like in the web portal: the server saves new staff as CASHIER and
/// keeps the current role on update; access comes from [roleIds].
class StaffInput {
  final String firstName;
  final String? middleName;
  final String lastName;
  final String phone;
  final String username;
  final List<String> roleIds;
  final String? branchId;
  final String? password;

  const StaffInput({
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.phone,
    required this.username,
    required this.roleIds,
    this.branchId,
    this.password,
  });

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'middleName': ?middleName,
        'lastName': lastName,
        'phone': phone,
        'username': username,
        'roleIds': roleIds,
        'branchId': ?branchId,
        'password': ?password,
      };
}
