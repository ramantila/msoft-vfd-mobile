import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/page_transitions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/utils/auth_state.dart';
import '../../models/company.dart';
import '../../models/license.dart';
import '../../models/service_package.dart';
import '../../providers/company_provider.dart';
import '../../widgets/admin_widgets.dart';
import 'tax_config_screen.dart';

String formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String formatMoney(double value) {
  final s = value.toStringAsFixed(0);
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Read-only company profile. Company info (business name, TIN, VRN, etc.)
/// is provisioned and managed exclusively via the Admin Portal (ADP) — CSP
/// and this app deliberately never expose an edit path for it, even though
/// CSP's `/api/v1/companies` endpoint technically supports PUT.
class CompanyProfileScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  const CompanyProfileScreen({super.key, required this.themeMode});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  late AppThemeMode _theme;
  late final CompanyProvider _provider;

  @override
  void initState() {
    super.initState();
    _theme = widget.themeMode;
    _provider = CompanyProvider(companyId: AuthState.session!.companyId);
    _provider.load();
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _theme == AppThemeMode.neumorphic;
    final bg = isNeu ? AppColors.bgNeu : AppColors.bgDefault;
    final tp = isNeu ? AppColors.textPrimaryNeu : AppColors.textPrimary;
    final ts = isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;
    final bot = MediaQuery.of(context).padding.bottom;

    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: bg,
        body: Column(children: [
          AdminHeader(title: 'Company profile', isNeu: isNeu, tp: tp, ts: ts),
          Expanded(
            child: Consumer<CompanyProvider>(
              builder: (context, provider, _) {
                if (provider.loading && provider.company == null) {
                  return const AdminLoading();
                }
                final company = provider.company;
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: provider.load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, bot + 24),
                    children: [
                      if (provider.error != null)
                        AdminErrorBanner(
                          message: provider.error!.message,
                          tp: tp, ts: ts,
                          onRetry: provider.load,
                        ),
                      if (company != null) ...[
                        _HeroCard(company: company),
                        if (company.status == CompanyStatus.suspended)
                          _SuspendedBanner(company: company, isNeu: isNeu),
                        const SizedBox(height: 20),
                        _sectionLabel('BUSINESS DETAILS', ts),
                        const SizedBox(height: 8),
                        AdminCard(
                          isNeu: isNeu,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(children: [
                            if (company.vrn?.isNotEmpty == true)
                              _infoRow(Icons.badge_outlined, 'VRN', company.vrn!, isNeu, tp, ts),
                            _infoRow(Icons.phone_outlined, 'Phone', company.phone, isNeu, tp, ts),
                            if (company.email?.isNotEmpty == true)
                              _infoRow(Icons.email_outlined, 'Email', company.email!, isNeu, tp, ts),
                            if (company.address?.isNotEmpty == true)
                              _infoRow(Icons.location_on_outlined, 'Address', company.address!,
                                  isNeu, tp, ts),
                            if (company.registeredAt != null)
                              _infoRow(Icons.event_available_outlined, 'Registered',
                                  formatDate(company.registeredAt!), isNeu, tp, ts, last: true),
                          ]),
                        ),
                        const SizedBox(height: 20),
                        _sectionLabel('LICENSE', ts),
                        const SizedBox(height: 8),
                        if (provider.currentLicense != null)
                          _LicenseCard(
                              license: provider.currentLicense!, isNeu: isNeu, tp: tp, ts: ts)
                        else
                          AdminCard(
                            isNeu: isNeu,
                            child: Text('No license found for this company.',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600, color: ts)),
                          ),
                        const SizedBox(height: 20),
                        _sectionLabel('SUBSCRIPTION PLAN', ts),
                        const SizedBox(height: 8),
                        if (provider.package != null)
                          _PackageCard(pkg: provider.package!, isNeu: isNeu, tp: tp, ts: ts)
                        else
                          AdminCard(
                            isNeu: isNeu,
                            child: Text('Plan details unavailable.',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600, color: ts)),
                          ),
                        const SizedBox(height: 20),
                        _sectionLabel('TAX', ts),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => Navigator.of(context)
                              .push(slideRight(TaxConfigScreen(themeMode: _theme))),
                          child: AdminCard(
                            isNeu: isNeu,
                            child: Row(children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F7FA),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.receipt_long_outlined,
                                    color: Color(0xFF0097A7), size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Tax configuration',
                                        style: TextStyle(
                                            fontSize: 14, fontWeight: FontWeight.w700, color: tp)),
                                    Text('${provider.taxConfigs.length} tax types configured',
                                        style: TextStyle(
                                            fontSize: 11, fontWeight: FontWeight.w500, color: ts)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, size: 18, color: ts),
                            ]),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String label, Color ts) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 2),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: ts, letterSpacing: 0.9)),
      );

  Widget _infoRow(IconData icon, String label, String value, bool isNeu, Color tp, Color ts,
      {bool last = false}) {
    final divColor = isNeu ? const Color(0xFFD5DDD8) : const Color(0xFFF0F3F1);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Row(children: [
          Icon(icon, size: 16, color: ts),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ts)),
          ),
          Flexible(
            flex: 2,
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tp)),
          ),
        ]),
      ),
      if (!last)
        Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 12), color: divColor),
    ]);
  }
}

// ── Hero card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final Company company;
  const _HeroCard({required this.company});

  Color get _statusColor => switch (company.status) {
        CompanyStatus.active => const Color(0xFF12D48A),
        CompanyStatus.trial => AppColors.blue,
        CompanyStatus.suspended => AppColors.warningText,
        CompanyStatus.deleted => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12D48A), Color(0xFF055C3F)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: const Color(0xFF12D48A).withValues(alpha: 0.28),
              blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.30), width: 1.5),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 24),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(company.status.label,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: _statusColor)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        Text(company.businessName,
            style: const TextStyle(
                fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.tag_rounded, size: 13, color: Colors.white.withValues(alpha: 0.75)),
          const SizedBox(width: 4),
          Text('TIN ${company.tin}',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.90))),
        ]),
      ]),
    );
  }
}

class _SuspendedBanner extends StatelessWidget {
  final Company company;
  final bool isNeu;
  const _SuspendedBanner({required this.company, required this.isNeu});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warningBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.warningIcon, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Account suspended',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.warningText)),
            if (company.suspendReason?.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(company.suspendReason!,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.warningText)),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Package card ───────────────────────────────────────────────────────────────

class _PackageCard extends StatelessWidget {
  final ServicePackage pkg;
  final bool isNeu;
  final Color tp;
  final Color ts;
  const _PackageCard({required this.pkg, required this.isNeu, required this.tp, required this.ts});

  @override
  Widget build(BuildContext context) {
    final price = pkg.priceTzs;
    return AdminCard(
      isNeu: isNeu,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(pkg.name,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tp)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: pkg.status == PackageStatus.active
                  ? const Color(0xFFDFF5EB)
                  : const Color(0xFFFFEDF0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(pkg.status.label,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: pkg.status == PackageStatus.active
                        ? AppColors.primary
                        : AppColors.error)),
          ),
        ]),
        if (pkg.description?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(pkg.description!,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ts)),
        ],
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('TZS ${formatMoney(price)}',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
          const SizedBox(width: 4),
          Text('/ month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ts)),
          if (pkg.pricePerYearTzs != null) ...[
            const SizedBox(width: 10),
            Text('· TZS ${formatMoney(pkg.pricePerYearTzs!)} / year',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ts)),
          ],
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: AdminStatTile(
              icon: Icons.receipt_long_outlined,
              value: '${pkg.monthlyReceipts}',
              label: 'Receipts / mo',
              isNeu: isNeu, tp: tp, ts: ts,
              accent: AppColors.blue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AdminStatTile(
              icon: Icons.people_outline_rounded,
              value: '${pkg.maxUsers}',
              label: 'Max staff',
              isNeu: isNeu, tp: tp, ts: ts,
              accent: AppColors.purple,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: AdminStatTile(
              icon: Icons.store_mall_directory_outlined,
              value: '${pkg.maxBranches}',
              label: 'Max branches',
              isNeu: isNeu, tp: tp, ts: ts,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AdminStatTile(
              icon: Icons.point_of_sale_outlined,
              value: '${pkg.maxDevices}',
              label: 'Max devices',
              isNeu: isNeu, tp: tp, ts: ts,
              accent: const Color(0xFF0097A7),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Icon(Icons.verified_user_outlined, size: 14, color: ts),
          const SizedBox(width: 6),
          Text('${pkg.licenseDurationMonths}-month license',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ts)),
          const SizedBox(width: 14),
          Icon(pkg.allowCspLogin ? Icons.check_circle_outline_rounded : Icons.block_rounded,
              size: 14, color: pkg.allowCspLogin ? AppColors.primary : AppColors.error),
          const SizedBox(width: 6),
          Text(pkg.allowCspLogin ? 'Portal login enabled' : 'Portal login disabled',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ts)),
        ]),
      ]),
    );
  }
}

// ── License card ───────────────────────────────────────────────────────────────

class _LicenseCard extends StatelessWidget {
  final License license;
  final bool isNeu;
  final Color tp;
  final Color ts;
  const _LicenseCard({required this.license, required this.isNeu, required this.tp, required this.ts});

  Color get _statusColor => switch (license.status) {
        LicenseStatus.active => AppColors.primary,
        LicenseStatus.pendingPayment => AppColors.blue,
        LicenseStatus.suspended => AppColors.warningText,
        LicenseStatus.expired => AppColors.error,
        LicenseStatus.cancelled => AppColors.textSecondary,
      };

  Color get _statusBg => switch (license.status) {
        LicenseStatus.active => const Color(0xFFDFF5EB),
        LicenseStatus.pendingPayment => const Color(0xFFDEEFFE),
        LicenseStatus.suspended => AppColors.warning,
        LicenseStatus.expired => const Color(0xFFFFEDF0),
        LicenseStatus.cancelled => const Color(0xFFF0F3F1),
      };

  String _daysLabel(int days) {
    if (license.status == LicenseStatus.expired || days < 0) {
      return 'Expired ${-days}d ago';
    }
    if (days == 0) return 'Expires today';
    return '$days';
  }

  Color _progressColor(int days) {
    if (days < 0) return AppColors.error;
    if (days <= 7) return AppColors.warningIcon;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final days = license.daysLeft;
    final showCountdown = days != null &&
        (license.status == LicenseStatus.active || license.status == LicenseStatus.suspended);

    return AdminCard(
      isNeu: isNeu,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(license.licenseKey,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: tp, letterSpacing: 0.3)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _statusBg, borderRadius: BorderRadius.circular(6)),
            child: Text(license.status.label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor)),
          ),
        ]),
        const SizedBox(height: 16),
        if (showCountdown) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(_daysLabel(days),
                style: TextStyle(
                    fontSize: days >= 0 && license.status != LicenseStatus.expired ? 28 : 17,
                    fontWeight: FontWeight.w800,
                    color: _progressColor(days))),
            if (days >= 0 && license.status != LicenseStatus.expired) ...[
              const SizedBox(width: 6),
              Text('days left',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ts)),
            ],
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: license.elapsedFraction,
              minHeight: 8,
              backgroundColor: isNeu ? AppColors.shadowDarkNeu.withValues(alpha: 0.35) : const Color(0xFFF0F3F1),
              valueColor: AlwaysStoppedAnimation(_progressColor(days)),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Starts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ts)),
              const SizedBox(height: 2),
              Text(license.startsAt != null ? formatDate(license.startsAt!) : '—',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tp)),
            ]),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Expires', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ts)),
              const SizedBox(height: 2),
              Text(license.expiresAt != null ? formatDate(license.expiresAt!) : '—',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tp)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Container(height: 1, color: isNeu ? const Color(0xFFD5DDD8) : const Color(0xFFF0F3F1)),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.receipt_outlined, size: 14, color: ts),
          const SizedBox(width: 6),
          Text('TZS ${formatMoney(license.amountTzs)} · ${license.durationMonths}mo',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ts)),
          const SizedBox(width: 12),
          Icon(license.paid ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
              size: 14, color: license.paid ? AppColors.primary : AppColors.warningIcon),
          const SizedBox(width: 6),
          Text(license.paid ? 'Paid' : 'Payment pending',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ts)),
        ]),
      ]),
    );
  }
}
