enum UserRole { superAdmin, manager, cashier, viewer }

extension UserRoleX on UserRole {
  static UserRole parse(String? value) => UserRole.values.firstWhere(
        (r) => r.cspName == value?.toUpperCase(),
        orElse: () => UserRole.viewer,
      );

  String get cspName => switch (this) {
        UserRole.superAdmin => 'SUPER_ADMIN',
        UserRole.manager => 'MANAGER',
        UserRole.cashier => 'CASHIER',
        UserRole.viewer => 'VIEWER',
      };

  String get label => switch (this) {
        UserRole.superAdmin => 'Super Admin',
        UserRole.manager => 'Manager',
        UserRole.cashier => 'Cashier',
        UserRole.viewer => 'Viewer',
      };
}

/// Authenticated session returned by CSP's POST /api/v1/auth/login.
class Session {
  final String token;
  final String tokenType;
  final String userId;
  final String username;
  final String firstName;
  final String lastName;
  final UserRole role;
  final String companyId;
  final String? branchId;
  final List<String> permissions;
  final List<String> roleNames;

  const Session({
    required this.token,
    required this.tokenType,
    required this.userId,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.companyId,
    this.branchId,
    required this.permissions,
    required this.roleNames,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final combined = '$f$l'.toUpperCase();
    if (combined.isNotEmpty) return combined;
    return username.isNotEmpty ? username[0].toUpperCase() : '?';
  }

  /// SUPER_ADMIN implicitly has every permission (mirrors CSP's own
  /// CspJwtAuthFilter, which grants SUPER_ADMIN the full permission list).
  bool has(String permission) =>
      role == UserRole.superAdmin || permissions.contains(permission);

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        token: json['token'] as String,
        tokenType: json['tokenType'] as String? ?? 'Bearer',
        userId: json['userId'].toString(),
        username: json['username'] as String? ?? '',
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        role: UserRoleX.parse(json['role'] as String?),
        companyId: json['companyId'].toString(),
        branchId: json['branchId']?.toString(),
        permissions: (json['permissions'] as List<dynamic>? ?? const [])
            .map((e) =>
                e is Map ? e['permissionName'].toString() : e.toString())
            .toList(),
        roleNames: (json['roleNames'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'tokenType': tokenType,
        'userId': userId,
        'username': username,
        'firstName': firstName,
        'lastName': lastName,
        'role': role.cspName,
        'companyId': companyId,
        'branchId': branchId,
        'permissions': permissions,
        'roleNames': roleNames,
      };
}
