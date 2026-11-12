import 'package:flutter/material.dart';

import '../../../core/navigation/page_transitions.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/admin_widgets.dart';
import '../../branches/screens/branch_list_screen.dart';
import 'company/company_profile_screen.dart';
import '../../access_control/screens/access_control_screen.dart';
import '../../users/screens/staff_list_screen.dart';

class AdministrationHomeScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  const AdministrationHomeScreen({super.key, required this.themeMode});

  @override
  State<AdministrationHomeScreen> createState() => _AdministrationHomeScreenState();
}

class _AdministrationHomeScreenState extends State<AdministrationHomeScreen> {
  late AppThemeMode _theme;

  @override
  void initState() {
    super.initState();
    _theme = widget.themeMode;
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _theme == AppThemeMode.neumorphic;
    final bg = isNeu ? AppColors.bgNeu : AppColors.bgDefault;
    final tp = isNeu ? AppColors.textPrimaryNeu : AppColors.textPrimary;
    final ts = isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;
    final bot = MediaQuery.of(context).padding.bottom;

    final items = [
      (
        icon: Icons.store_mall_directory_outlined,
        iconBg: const Color(0xFFDFF5EB),
        iconFg: AppColors.primary,
        title: 'Branches',
        subtitle: 'Manage your business locations',
        onTap: () => Navigator.of(context)
            .push(slideRight(BranchListScreen(themeMode: _theme))),
      ),
      (
        icon: Icons.people_outline_rounded,
        iconBg: const Color(0xFFDEEFFE),
        iconFg: const Color(0xFF3B82F6),
        title: 'Staff',
        subtitle: 'Manage staff accounts and access',
        onTap: () =>
            Navigator.of(context).push(slideRight(StaffListScreen(themeMode: _theme))),
      ),
      (
        icon: Icons.badge_outlined,
        iconBg: const Color(0xFFF3E8FF),
        iconFg: const Color(0xFF9333EA),
        title: 'Access Control',
        subtitle: 'Define custom roles for your staff',
        onTap: () =>
            Navigator.of(context).push(slideRight(AccessControlScreen(themeMode: _theme))),
      ),
      (
        icon: Icons.business_outlined,
        iconBg: const Color(0xFFFFF3E0),
        iconFg: const Color(0xFFF59E0B),
        title: 'Company & tax',
        subtitle: 'Business profile and tax configuration',
        onTap: () => Navigator.of(context)
            .push(slideRight(CompanyProfileScreen(themeMode: _theme))),
      ),
    ];

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        AdminHeader(title: 'Administration', isNeu: isNeu, tp: tp, ts: ts),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bot + 24),
            children: items
                .map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: item.onTap,
                        child: AdminCard(
                          isNeu: isNeu,
                          child: Row(children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: item.iconBg,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(item.icon, color: item.iconFg, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title,
                                      style: TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w700, color: tp)),
                                  const SizedBox(height: 3),
                                  Text(item.subtitle,
                                      style: TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w500, color: ts)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, size: 18, color: ts),
                          ]),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ]),
    );
  }
}
