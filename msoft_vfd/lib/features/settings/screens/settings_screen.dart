import 'package:flutter/material.dart';
import '../../users/screens/staff_detail_screen.dart';
import '../../users/screens/staff_password_screen.dart';
import '../../../core/navigation/page_transitions.dart';
import '../../../core/theme/app_theme.dart';
import '../../administration/screens/administration_home_screen.dart';
import '../../auth/utils/auth_state.dart';
import '../../../core/widgets/theme_toggle.dart';

class SettingsScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final ValueChanged<AppThemeMode> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppThemeMode _theme;
  late UserRole     _role;

  // local notification toggles
  bool _notifSales     = true;
  bool _notifStock     = true;
  bool _notifReports   = false;
  bool _notifUpdates   = true;

  @override
  void initState() {
    super.initState();
    _theme = widget.themeMode;
    _role  = AuthState.role;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isNeu = _theme == AppThemeMode.neumorphic;
    final bg    = isNeu ? AppColors.bgNeu : AppColors.bgDefault;
    final tp    = isNeu ? AppColors.textPrimaryNeu : AppColors.textPrimary;
    final ts    = isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;
    final bot   = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _buildHeader(isNeu, tp, ts),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, bot + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Appearance
                  _sectionLabel('APPEARANCE', ts),
                  const SizedBox(height: 8),
                  _card(isNeu, [
                    _settingRow(
                      icon: Icons.palette_outlined,
                      iconBg: const Color(0xFFDFF5EB),
                      iconColor: AppColors.primary,
                      label: 'Theme',
                      subtitle: _theme == AppThemeMode.neumorphic ? 'Neumorphic' : 'Default',
                      isNeu: isNeu, tp: tp, ts: ts,
                      trailing: ThemeToggle(
                        current: _theme,
                        onChanged: (t) {
                          setState(() => _theme = t);
                          AuthState.lastTheme = t;
                          widget.onThemeChanged(t);
                        },
                      ),
                      divider: true,
                    ),
                    _settingRow(
                      icon: Icons.text_fields_rounded,
                      iconBg: const Color(0xFFE0F7FA),
                      iconColor: const Color(0xFF0097A7),
                      label: 'Font size',
                      subtitle: 'Medium',
                      isNeu: isNeu, tp: tp, ts: ts,
                      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: ts),
                      divider: false,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // Account
                  _sectionLabel('ACCOUNT', ts),
                  const SizedBox(height: 8),
                  _card(isNeu, [
                    if (_role == UserRole.superAdmin || _role == UserRole.manager)
                      _settingRow(
                        icon: Icons.admin_panel_settings_outlined,
                        iconBg: const Color(0xFFDEEFFE),
                        iconColor: const Color(0xFF3B82F6),
                        label: 'Administration',
                        subtitle: 'Branches, staff, roles & company settings',
                        isNeu: isNeu, tp: tp, ts: ts,
                        trailing: Icon(Icons.chevron_right_rounded, size: 18, color: ts),
                        divider: true,
                        onTap: () => Navigator.of(context)
                            .push(slideRight(AdministrationHomeScreen(themeMode: _theme))),
                      ),
                    _settingRow(
                      icon: Icons.shield_outlined,
                      iconBg: const Color(0xFFF3E8FF),
                      iconColor: const Color(0xFF9333EA),
                      label: 'Role',
                      subtitle: _role.label,
                      isNeu: isNeu, tp: tp, ts: ts,
                      // Role is assigned server-side (CSP) at login and is
                      // read-only here — no longer a local demo toggle.
                      trailing: _RoleBadge(isNeu: isNeu, role: _role),
                      divider: true,
                    ),
                    _settingRow(
                      icon: Icons.person_outline_rounded,
                      iconBg: const Color(0xFFDFF5EB),
                      iconColor: AppColors.primary,
                      label: 'My profile',
                      subtitle: '${AuthState.session?.fullName ?? ''} · @${AuthState.session?.username ?? ''}',
                      isNeu: isNeu, tp: tp, ts: ts,
                      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: ts),
                      divider: true,
                      onTap: () => Navigator.of(context)
                          .push(slideRight(StaffDetailScreen(themeMode: _theme)))
                          .then((_) { if (mounted) setState(() {}); }),
                    ),
                    _settingRow(
                      icon: Icons.lock_outline_rounded,
                      iconBg: const Color(0xFFFFF8EC),
                      iconColor: const Color(0xFFB26A00),
                      label: 'Change password',
                      subtitle: 'Signs you out on other devices',
                      isNeu: isNeu, tp: tp, ts: ts,
                      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: ts),
                      divider: false,
                      onTap: () => Navigator.of(context)
                          .push(slideRight(StaffPasswordScreen(themeMode: _theme))),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // Notifications
                  _sectionLabel('NOTIFICATIONS', ts),
                  const SizedBox(height: 8),
                  _card(isNeu, [
                    _switchRow(
                      icon: Icons.receipt_long_outlined,
                      iconBg: const Color(0xFFDFF5EB),
                      iconColor: AppColors.primary,
                      label: 'New sales',
                      subtitle: 'Alert for every completed sale',
                      value: _notifSales,
                      onChanged: (v) => setState(() => _notifSales = v),
                      isNeu: isNeu, tp: tp, ts: ts,
                      divider: true,
                    ),
                    _switchRow(
                      icon: Icons.inventory_2_outlined,
                      iconBg: const Color(0xFFFFF8EC),
                      iconColor: const Color(0xFFB26A00),
                      label: 'Low stock alerts',
                      subtitle: 'Notify when stock falls below 10',
                      value: _notifStock,
                      onChanged: (v) => setState(() => _notifStock = v),
                      isNeu: isNeu, tp: tp, ts: ts,
                      divider: true,
                    ),
                    _switchRow(
                      icon: Icons.bar_chart_rounded,
                      iconBg: const Color(0xFFE0F7FA),
                      iconColor: const Color(0xFF0097A7),
                      label: 'Daily reports',
                      subtitle: 'Summary every day at 8 PM',
                      value: _notifReports,
                      onChanged: (v) => setState(() => _notifReports = v),
                      isNeu: isNeu, tp: tp, ts: ts,
                      divider: true,
                    ),
                    _switchRow(
                      icon: Icons.system_update_outlined,
                      iconBg: const Color(0xFFF3E8FF),
                      iconColor: const Color(0xFF9333EA),
                      label: 'App updates',
                      subtitle: 'Get notified about new versions',
                      value: _notifUpdates,
                      onChanged: (v) => setState(() => _notifUpdates = v),
                      isNeu: isNeu, tp: tp, ts: ts,
                      divider: false,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // Data & privacy
                  _sectionLabel('DATA & PRIVACY', ts),
                  const SizedBox(height: 8),
                  _card(isNeu, [
                    _settingRow(
                      icon: Icons.backup_outlined,
                      iconBg: const Color(0xFFDFF5EB),
                      iconColor: AppColors.primary,
                      label: 'Backup data',
                      subtitle: 'Last backup: today 06:00 AM',
                      isNeu: isNeu, tp: tp, ts: ts,
                      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: ts),
                      divider: true,
                    ),
                    _settingRow(
                      icon: Icons.delete_outline_rounded,
                      iconBg: const Color(0xFFFFEDF0),
                      iconColor: const Color(0xFFE5484D),
                      label: 'Clear cache',
                      subtitle: '2.4 MB used',
                      isNeu: isNeu, tp: tp, ts: ts,
                      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: ts),
                      divider: false,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // About
                  _sectionLabel('ABOUT', ts),
                  const SizedBox(height: 8),
                  _card(isNeu, [
                    _settingRow(
                      icon: Icons.info_outline_rounded,
                      iconBg: const Color(0xFFDFF5EB),
                      iconColor: AppColors.primary,
                      label: 'App version',
                      subtitle: 'v1.0.0 (build 100)',
                      isNeu: isNeu, tp: tp, ts: ts,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDFF5EB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Latest',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ),
                      divider: true,
                    ),
                    _settingRow(
                      icon: Icons.description_outlined,
                      iconBg: const Color(0xFFF0F3F1),
                      iconColor: AppColors.textSecondary,
                      label: 'Terms of service',
                      subtitle: '',
                      isNeu: isNeu, tp: tp, ts: ts,
                      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: ts),
                      divider: true,
                    ),
                    _settingRow(
                      icon: Icons.privacy_tip_outlined,
                      iconBg: const Color(0xFFF0F3F1),
                      iconColor: AppColors.textSecondary,
                      label: 'Privacy policy',
                      subtitle: '',
                      isNeu: isNeu, tp: tp, ts: ts,
                      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: ts),
                      divider: false,
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isNeu, Color tp, Color ts) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: isNeu ? AppColors.bgNeu : AppColors.bgDefault,
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 14),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: _iconBox(Icons.arrow_back_ios_new_rounded, isNeu, tp, size: 14),
        ),
        const SizedBox(width: 14),
        Text('Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tp)),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label, Color ts) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 2),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: ts, letterSpacing: 0.9)),
      );

  Widget _card(bool isNeu, List<Widget> rows) => Container(
        decoration: isNeu
            ? const BoxDecoration(
                color: AppColors.bgNeu,
                borderRadius: BorderRadius.all(Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 12, offset: Offset(6, 6)),
                  BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 12, offset: Offset(-6, -6)),
                ],
              )
            : BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderDefault),
              ),
        child: Column(children: rows),
      );

  Widget _settingRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String subtitle,
    required bool isNeu,
    required Color tp,
    required Color ts,
    required Widget trailing,
    required bool divider,
    VoidCallback? onTap,
  }) {
    final divColor = isNeu ? const Color(0xFFD5DDD8) : const Color(0xFFF0F3F1);
    return Column(children: [
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tp)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ts)),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          trailing,
        ]),
      ),
      ),
      if (divider)
        Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 16), color: divColor),
    ]);
  }

  Widget _switchRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isNeu,
    required Color tp,
    required Color ts,
    required bool divider,
  }) =>
      _settingRow(
        icon: icon, iconBg: iconBg, iconColor: iconColor,
        label: label, subtitle: subtitle,
        isNeu: isNeu, tp: tp, ts: ts,
        divider: divider,
        trailing: Transform.scale(
          scale: 0.82,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.35),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );

  Widget _iconBox(IconData icon, bool isNeu, Color color, {double size = 16}) {
    if (isNeu) {
      return Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.bgNeu,
          borderRadius: BorderRadius.circular(13),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 9, offset: Offset(4, 4)),
            BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 9, offset: Offset(-4, -4)),
          ],
        ),
        child: Icon(icon, color: color, size: size),
      );
    }
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}

// ── Role badge ────────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final bool isNeu;
  final UserRole role;
  const _RoleBadge({required this.isNeu, required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(7),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Text(role.label,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}