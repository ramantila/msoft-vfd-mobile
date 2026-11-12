int _i(Object? v) => (v as num?)?.toInt() ?? 0;

class PermissionItem {
  final String id;
  final String name;
  final String action;
  final String actionLabel;
  final bool inPackage;
  const PermissionItem({
    required this.id,
    required this.name,
    required this.action,
    required this.actionLabel,
    required this.inPackage,
  });

  factory PermissionItem.fromJson(Map<String, dynamic> j) => PermissionItem(
        id: j['id'].toString(),
        name: j['name'] as String? ?? '',
        action: j['action'] as String? ?? '',
        actionLabel: j['actionLabel'] as String? ?? '',
        inPackage: j['inPackage'] as bool? ?? false,
      );
}

/// Permissions of one module, e.g. "Products" -> View, Create, Update, Delete.
class PermissionGroup {
  final String key;
  final String label;
  final List<PermissionItem> items;
  const PermissionGroup({required this.key, required this.label, required this.items});

  factory PermissionGroup.fromJson(Map<String, dynamic> j) => PermissionGroup(
        key: j['key'] as String? ?? '',
        label: j['label'] as String? ?? '',
        items: (j['items'] as List<dynamic>? ?? const [])
            .map((e) => PermissionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static List<PermissionGroup> listFrom(Object? v) =>
      (v as List<dynamic>? ?? const []).map((e) => PermissionGroup.fromJson(e as Map<String, dynamic>)).toList();
}

class PermissionOptions {
  final String? packageName;
  final int total;
  final List<PermissionGroup> groups;
  final String? emptyReason;
  const PermissionOptions({this.packageName, required this.total, required this.groups, this.emptyReason});

  factory PermissionOptions.fromJson(Map<String, dynamic> j) => PermissionOptions(
        packageName: j['packageName'] as String?,
        total: _i(j['total']),
        groups: PermissionGroup.listFrom(j['groups']),
        emptyReason: j['emptyReason'] as String?,
      );
}

class RoleItem {
  final String id;
  final String name;
  final String? description;
  final bool active;
  final int permissionCount;
  final int userCount;
  final DateTime? createdAt;

  const RoleItem({
    required this.id,
    required this.name,
    this.description,
    required this.active,
    required this.permissionCount,
    required this.userCount,
    this.createdAt,
  });

  factory RoleItem.fromJson(Map<String, dynamic> j) => RoleItem(
        id: j['id'].toString(),
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        active: j['active'] as bool? ?? true,
        permissionCount: _i(j['permissionCount']),
        userCount: _i(j['userCount']),
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '')?.toLocal(),
      );
}

class RoleHolder {
  final String id;
  final String fullName;
  final String username;
  const RoleHolder(this.id, this.fullName, this.username);
}

class RoleDetail {
  final RoleItem role;
  final List<PermissionGroup> permissions;
  final List<String> notInPackage;
  final List<RoleHolder> users;
  final bool canEdit;
  final bool canDelete;
  final String? deleteBlocker;

  const RoleDetail({
    required this.role,
    required this.permissions,
    required this.notInPackage,
    required this.users,
    required this.canEdit,
    required this.canDelete,
    this.deleteBlocker,
  });

  Set<String> get permissionIds => {for (final g in permissions) for (final p in g.items) p.id};

  factory RoleDetail.fromJson(Map<String, dynamic> j) => RoleDetail(
        role: RoleItem.fromJson(j['role'] as Map<String, dynamic>),
        permissions: PermissionGroup.listFrom(j['permissions']),
        notInPackage: (j['notInPackage'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
        users: (j['users'] as List<dynamic>? ?? const [])
            .map((e) => e as Map<String, dynamic>)
            .map((u) => RoleHolder(u['id'].toString(), u['fullName'] as String? ?? '', u['username'] as String? ?? ''))
            .toList(),
        canEdit: j['canEdit'] as bool? ?? false,
        canDelete: j['canDelete'] as bool? ?? false,
        deleteBlocker: j['deleteBlocker'] as String?,
      );
}
