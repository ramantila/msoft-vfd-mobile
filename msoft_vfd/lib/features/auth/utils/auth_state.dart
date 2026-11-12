import '../../../core/theme/app_theme.dart';
import '../models/session.dart';

export '../models/session.dart' show UserRole, UserRoleX, Session;

/// Thin synchronous facade over the persisted [Session], so existing screens
/// can keep reading `AuthState.xxx` in their build methods without threading
/// futures everywhere. Populated by `SessionManager` on login/bootstrap/logout
/// — see `AuthService.login`, `splash_screen.dart`, and `dashboard_screen.dart`'s
/// sign-out flow.
class AuthState {
  AuthState._();

  static bool isLoggedIn = false;
  static AppThemeMode lastTheme = AppThemeMode.defaultMode;
  static UserRole role = UserRole.cashier;
  static Session? session;

  static void applySession(Session s) {
    session = s;
    isLoggedIn = true;
    role = s.role;
  }

  static void clear() {
    session = null;
    isLoggedIn = false;
  }

  static bool has(String permission) => session?.has(permission) ?? false;

  static bool hasAny(Iterable<String> permissions) => permissions.any(has);
}