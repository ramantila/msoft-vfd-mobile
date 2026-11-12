import 'package:flutter/widgets.dart';

import '../../features/auth/utils/auth_state.dart';

/// Shows/hides UI based on the current session's permission codes.
///
/// This is UI-only gating: CSP's `@PreAuthorize` checks are not currently
/// enforced server-side except for SUPER_ADMIN, so an action hidden here is
/// not guaranteed to be rejected by the API — callers must still handle
/// 401/403 responses rather than assume this widget is the real gate.
class PermissionGate extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (AuthState.has(permission)) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
