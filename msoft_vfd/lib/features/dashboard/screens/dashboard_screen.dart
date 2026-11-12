import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bottom_nav.dart';
import '../../settings/screens/settings_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/utils/auth_state.dart';
import '../../products/screens/add_product_screen.dart';
import '../../administration/screens/company/company_profile_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../sales/screens/new_sale_screen.dart';
import '../../products/screens/product_list_screen.dart';
import '../../customers/screens/customer_list_screen.dart';
import '../../users/screens/staff_list_screen.dart';
import '../../users/screens/staff_detail_screen.dart';
import '../../users/screens/staff_password_screen.dart';
import '../../branches/screens/branch_list_screen.dart';
import '../../configurations/screens/categories_screens.dart';
import '../../configurations/screens/units_screens.dart';
import '../../access_control/screens/access_control_screen.dart';
import '../../sales/screens/sales_report_screen.dart';
import '../../sales/screens/sales_history_screen.dart';
import '../../sales/screens/sale_detail_screen.dart';
import '../../sales/models/sale.dart';
import '../../sales/models/sale_list_item.dart';
import '../../sales/models/sales_summary.dart';
import '../../sales/services/sale_service.dart';
import '../../sales/utils/sales_format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/page_response.dart';

class DashboardScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  const DashboardScreen({super.key, required this.themeMode});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late AppThemeMode _theme;
  int _navIndex = 0;
  int _prevNavIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Live sales figures from /api/v1/mobile/sales. Null until loaded (or if
  // the user lacks SALE_VIEW) — the cards then show "—" placeholders.
  SalesSummary? _today;
  SalesSummary? _week;
  SalesSummary? _month;
  List<SaleListItem>? _recent;
  bool _salesLoading = false;

  @override
  void initState() {
    super.initState();
    _theme = widget.themeMode;
    _loadSales();
  }

  Future<void> _loadSales() async {
    if (_salesLoading) return;
    _salesLoading = true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sales = SaleService.instance;
    Future<T?> soft<T>(Future<T> f) => f.then<T?>((v) => v).catchError((Object e) {
          // One failing card (e.g. 403 without SALE_VIEW, or offline)
          // shouldn't blank the others.
          if (e is! ApiException) throw e;
          return null;
        });
    final results = await Future.wait<Object?>([
      soft(sales.summary(from: today, to: today, topProducts: 3)),
      soft(sales.summary(from: today.subtract(const Duration(days: 6)), to: today, topProducts: 0)),
      soft(sales.summary(from: DateTime(today.year, today.month, 1), to: today, topProducts: 0)),
      soft(sales.history(size: 3)),
    ]);
    _salesLoading = false;
    if (!mounted) return;
    setState(() {
      _today = results[0] as SalesSummary?;
      _week = results[1] as SalesSummary?;
      _month = results[2] as SalesSummary?;
      _recent = (results[3] as PageResponse<SaleListItem>?)?.content;
    });
  }

  void _openHistory() {
    Navigator.of(context)
        .push(_slideRight(SalesHistoryScreen(themeMode: _theme)))
        .then((_) => _loadSales());
  }

  void _openSale(SaleListItem sale) {
    Navigator.of(context)
        .push(_slideRight(SaleDetailScreen(themeMode: _theme, saleId: sale.id)))
        .then((_) => _loadSales());
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _theme == AppThemeMode.neumorphic;
    final bg = isNeu ? AppColors.bgNeu : AppColors.bgDefault;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitDialog();
      },
      child: Scaffold(
      key: _scaffoldKey,
      backgroundColor: bg,
      drawer: _buildDrawer(isNeu),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(isNeu),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, anim) {
                  final isIncoming =
                      (child.key as ValueKey?)?.value == _navIndex;
                  final goRight = _navIndex > _prevNavIndex;
                  final begin = isIncoming
                      ? Offset(goRight ? 0.06 : -0.06, 0)
                      : Offset(goRight ? -0.06 : 0.06, 0);
                  return FadeTransition(
                    opacity: CurvedAnimation(
                        parent: anim, curve: Curves.easeOut),
                    child: SlideTransition(
                      position: Tween<Offset>(
                              begin: begin, end: Offset.zero)
                          .animate(CurvedAnimation(
                              parent: anim, curve: Curves.easeOut)),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_navIndex),
                  child: _buildBody(isNeu),
                ),
              ),
            ),
            BottomNav(
              activeIndex: _navIndex,
              isNeu: isNeu,
              onTap: _handleNav,
            ),
          ],
        ),
      ),
      ),
    );
  }

  // Horizontal slide-right route for peer screens (Sales, Products, Reports) —
  // (Reports is to the right of Dashboard in the nav). Pop slides back left.
  static PageRoute<T> _slideRight<T>(Widget page) => PageRouteBuilder<T>(
        pageBuilder: (_, _, _) => page,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        transitionsBuilder: (_, anim, _, child) {
          const curve = Curves.easeOutCubic;
          final slide = Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: curve));
          final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
                parent: anim,
                curve: const Interval(0.0, 0.38, curve: Curves.easeOut)),
          );
          return FadeTransition(
              opacity: fade,
              child: SlideTransition(position: slide, child: child));
        },
      );

  void _handleNav(int i) {
    // Sales (1), Products (2) and Reports (3) are full-screen peers pushed as
    // routes. Horizontal slide matches the rightward tab direction; nav index
    // resets when the user pops back to the dashboard.
    if (i == 1 || i == 2 || i == 3) {
      final Widget page = switch (i) {
        1 => NewSaleScreen(themeMode: _theme),
        2 => ProductListScreen(themeMode: _theme),
        _ => SalesReportScreen(themeMode: _theme),
      };
      Navigator.of(context).push(_slideRight(page)).then((_) {
        if (mounted) setState(() { _navIndex = _prevNavIndex; });
        _loadSales();
      });
      return;
    }
    setState(() {
      _prevNavIndex = _navIndex;
      _navIndex = i;
    });
  }

  void _signOut(bool isNeu) {
    final tp  = isNeu ? AppColors.textPrimaryNeu   : AppColors.textPrimary;
    final ts  = isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;
    final bg  = isNeu ? AppColors.bgNeu            : Colors.white;
    final div = isNeu ? const Color(0xFFD5DDD8)    : const Color(0xFFF0F3F1);

    showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => Dialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Icon
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFFECED),
                shape: BoxShape.circle,
                boxShadow: isNeu
                    ? const [
                        BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 10, offset: Offset(4, 4)),
                        BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 10, offset: Offset(-4, -4)),
                      ]
                    : null,
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Color(0xFFE5484D), size: 22),
            ),
            const SizedBox(height: 16),
            Text('Sign out?',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: tp)),
            const SizedBox(height: 6),
            Text('You will be returned to the login screen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: ts, height: 1.4)),
            const SizedBox(height: 20),
            Container(height: 1, color: div),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: isNeu ? AppColors.bgNeu : const Color(0xFFF4F6F5),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: isNeu
                          ? const [
                              BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 8, offset: Offset(3, 3)),
                              BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 8, offset: Offset(-3, -3)),
                            ]
                          : null,
                    ),
                    child: Text('Cancel',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: tp)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await AuthService.instance.logout();
                    AuthState.clear();
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      PageRouteBuilder(
                        pageBuilder: (_, _, _) => const LoginScreen(),
                        transitionDuration: const Duration(milliseconds: 420),
                        transitionsBuilder: (_, anim, _, child) =>
                            FadeTransition(
                          opacity: CurvedAnimation(
                              parent: anim, curve: Curves.easeInOut),
                          child: child,
                        ),
                      ),
                      (route) => false,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5484D),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFE5484D).withValues(alpha: 0.28),
                            blurRadius: 14, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: const Text('Sign out',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showExitDialog() {
    final isNeu = _theme == AppThemeMode.neumorphic;
    final tp  = isNeu ? AppColors.textPrimaryNeu   : AppColors.textPrimary;
    final ts  = isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;
    final bg  = isNeu ? AppColors.bgNeu            : Colors.white;
    final div = isNeu ? const Color(0xFFD5DDD8)    : const Color(0xFFF0F3F1);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => Dialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                shape: BoxShape.circle,
                boxShadow: isNeu
                    ? const [
                        BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 10, offset: Offset(4, 4)),
                        BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 10, offset: Offset(-4, -4)),
                      ]
                    : null,
              ),
              child: const Icon(Icons.exit_to_app_rounded,
                  color: Color(0xFFF59E0B), size: 22),
            ),
            const SizedBox(height: 16),
            Text('Exit app?',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: tp)),
            const SizedBox(height: 6),
            Text('Are you sure you want to close the application?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: ts, height: 1.4)),
            const SizedBox(height: 20),
            Container(height: 1, color: div),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: isNeu ? AppColors.bgNeu : const Color(0xFFF4F6F5),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: isNeu
                          ? const [
                              BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 8, offset: Offset(3, 3)),
                              BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 8, offset: Offset(-3, -3)),
                            ]
                          : null,
                    ),
                    child: Text('Cancel',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: tp)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    SystemNavigator.pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.30),
                            blurRadius: 14, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: const Text('Exit',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isNeu) {
    final textPrimary = isNeu ? AppColors.textPrimaryNeu : AppColors.textPrimary;
    final textSec = isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: isNeu
                ? Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.bgNeu,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 10, offset: Offset(5, 5)),
                        BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 10, offset: Offset(-5, -5)),
                      ],
                    ),
                    child: Center(
                      child: Text(AuthState.session?.initials ?? '?',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark)),
                    ),
                  )
                : Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF10A56F), Color(0xFF067A53)],
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Text(AuthState.session?.initials ?? '?',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Good morning',
                  style: TextStyle(
                      fontSize: 13, color: textSec, fontWeight: FontWeight.w600)),
              Text(AuthState.session?.fullName ?? '',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: textPrimary)),
            ],
          ),
          const Spacer(),
          _notificationBell(isNeu, textPrimary),
        ],
      ),
    );
  }

  Widget _buildDrawer(bool isNeu) {
    final bg       = isNeu ? AppColors.bgNeu : Colors.white;
    final tp       = isNeu ? AppColors.textPrimaryNeu : AppColors.textPrimary;
    final ts       = isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;
    final divColor = isNeu ? const Color(0xFFD5DDD8) : const Color(0xFFF0F3F1);
    final bot      = MediaQuery.of(context).padding.bottom;

    return Drawer(
      backgroundColor: bg,
      child: Column(
        children: [
          // ── Hero banner ──────────────────────────────────────────────────
          _buildDrawerHero(isNeu),

          // ── Scrollable body ──────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User profile row
                  const SizedBox(height: 8),
                  _buildUserRow(isNeu, tp, ts, divColor),
                  const SizedBox(height: 16),
                  Container(height: 1, color: divColor),
                  const SizedBox(height: 16),

                  // Menu — each entry shows only when the user's
                  // permissions allow it (the server enforces them too).
                  // Same groups and order as the web portal's sidebar
                  // (Overview → Operations → Configurations → Administration).
                  ..._drawerSection('OVERVIEW', ts, [
                    if (AuthState.has('SALE_CREATE'))
                      _drawerItem(Icons.point_of_sale_rounded, 'POS', tp, ts, isNeu,
                          onTap: () => _drawerGo(NewSaleScreen(themeMode: _theme))),
                  ]),
                  ..._drawerSection('OPERATIONS', ts, [
                    if (AuthState.has('CUSTOMER_VIEW'))
                      _drawerItem(Icons.people_alt_outlined, 'Customers', tp, ts, isNeu,
                          onTap: () => _drawerGo(CustomerListScreen(themeMode: _theme))),
                    if (AuthState.has('PRODUCT_VIEW'))
                      _drawerItem(Icons.inventory_2_outlined, 'Products', tp, ts, isNeu,
                          onTap: () => _drawerGo(ProductListScreen(themeMode: _theme))),
                    if (AuthState.has('REPORT_VIEW') || AuthState.has('SALE_VIEW'))
                      _drawerItem(Icons.bar_chart_rounded, 'Sales Report', tp, ts, isNeu,
                          onTap: () => _drawerGo(SalesReportScreen(themeMode: _theme))),
                    if (AuthState.has('SALE_VIEW'))
                      _drawerItem(Icons.receipt_long_outlined, 'Sales History', tp, ts, isNeu,
                          onTap: () => _drawerGo(SalesHistoryScreen(themeMode: _theme))),
                  ]),
                  ..._drawerSection('CONFIGURATIONS', ts, [
                    if (AuthState.has('BRANCH_VIEW'))
                      _drawerItem(Icons.store_mall_directory_outlined, 'Branches', tp, ts, isNeu,
                          onTap: () => _drawerGo(BranchListScreen(themeMode: _theme))),
                    if (AuthState.has('CATEGORY_VIEW'))
                      _drawerItem(Icons.category_outlined, 'Categories', tp, ts, isNeu,
                          onTap: () => _drawerGo(CategoryListScreen(themeMode: _theme))),
                    if (AuthState.has('UOM_VIEW'))
                      _drawerItem(Icons.straighten_rounded, 'Units of Measure', tp, ts, isNeu,
                          onTap: () => _drawerGo(UnitListScreen(themeMode: _theme))),
                  ]),
                  ..._drawerSection('ADMINISTRATION', ts, [
                    if (AuthState.has('USER_VIEW'))
                      _drawerItem(Icons.manage_accounts_outlined, 'System Users', tp, ts, isNeu,
                          onTap: () => _drawerGo(StaffListScreen(themeMode: _theme))),
                    if (AuthState.has('ROLE_VIEW'))
                      _drawerItem(Icons.shield_outlined, 'Access Control', tp, ts, isNeu,
                          onTap: () => _drawerGo(AccessControlScreen(themeMode: _theme))),
                    if (AuthState.has('COMPANY_VIEW'))
                      _drawerItem(Icons.business_outlined, 'Company Info', tp, ts, isNeu,
                          onTap: () => _drawerGo(CompanyProfileScreen(themeMode: _theme))),
                  ]),
                  ..._drawerSection('ACCOUNT', ts, [
                    _drawerItem(Icons.person_outline_rounded, 'My profile', tp, ts, isNeu,
                        onTap: () => _drawerGo(StaffDetailScreen(themeMode: _theme))),
                    _drawerItem(Icons.lock_outline_rounded, 'Change password', tp, ts, isNeu,
                        onTap: () => _drawerGo(StaffPasswordScreen(themeMode: _theme))),
                    _drawerItem(Icons.settings_outlined, 'Settings', tp, ts, isNeu,
                        onTap: () => _drawerGo(SettingsScreen(
                              themeMode: _theme,
                              onThemeChanged: (t) => setState(() {
                                _theme = t;
                                AuthState.lastTheme = t;
                              }),
                            ))),
                  ]),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── Sign out (always pinned at bottom) ───────────────────────────
          Container(height: 1, color: divColor),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, bot + 4),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _signOut(isNeu),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  child: Row(children: [
                    const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFE5484D)),
                    const SizedBox(width: 12),
                    const Text('Sign out',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: Color(0xFFE5484D))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDF0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('v1.0.0',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: Color(0xFFE5484D))),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHero(bool isNeu) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0DA86F), Color(0xFF056845)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, top + 20, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Store icon + close button row
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
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
            ),
          ),
        ]),

        const SizedBox(height: 14),

        // Store name + package badge
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const Text('Kondo General Shop',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.40)),
            ),
            child: const Text('PRO',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 0.8)),
          ),
        ]),

        const SizedBox(height: 4),

        // TIN + branch
        Row(children: [
          Icon(Icons.tag_rounded, size: 12, color: Colors.white.withValues(alpha: 0.75)),
          const SizedBox(width: 4),
          Text('TIN: 100-234-567',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(width: 10),
          Icon(Icons.location_on_outlined, size: 12, color: Colors.white.withValues(alpha: 0.75)),
          const SizedBox(width: 3),
          Text('Dar es Salaam',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85))),
        ]),
      ]),
    );
  }

  Widget _buildUserRow(bool isNeu, Color tp, Color ts, Color divColor) {
    final isElevated = AuthState.role == UserRole.superAdmin ||
        AuthState.role == UserRole.manager;
    final role = AuthState.role.label;
    final roleColor = isElevated ? const Color(0xFF9333EA) : AppColors.primary;
    final roleBg =
        isElevated ? const Color(0xFFF3E8FF) : const Color(0xFFDFF5EB);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF10A56F), Color(0xFF067A53)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: isNeu ? const [
              BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 8, offset: Offset(4, 4)),
              BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 8, offset: Offset(-4, -4)),
            ] : [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Text(AuthState.session?.initials ?? '?',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AuthState.session?.fullName ?? '',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tp)),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: roleBg,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(role,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: roleColor)),
              ),
              const SizedBox(width: 6),
              Text('· @${AuthState.session?.username ?? ''}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ts)),
            ]),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, size: 18, color: ts),
      ]),
    );
  }

  /// Closes the drawer, opens [page], and refreshes dashboard figures on return.
  void _drawerGo(Widget page) {
    Navigator.of(context).pop();
    Navigator.of(context).push(_slideRight(page)).then((_) {
      if (mounted) {
        setState(() {}); // name / permissions may have changed (My profile)
        _loadSales();
      }
    });
  }

  /// A labelled drawer group; empty when the user can see none of its items.
  List<Widget> _drawerSection(String label, Color ts, List<Widget> items) => items.isEmpty
      ? const []
      : [
          const SizedBox(height: 8),
          _drawerSectionLabel(label, ts),
          const SizedBox(height: 6),
          ...items,
          const SizedBox(height: 8),
        ];

  Widget _drawerSectionLabel(String label, Color ts) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: ts, letterSpacing: 0.9)),
      );

  Widget _drawerItem(IconData icon, String label, Color color, Color secColor, bool isNeu,
      {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color == const Color(0xFFE5484D) ? color : secColor),
                const SizedBox(width: 12),
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _notificationBell(bool isNeu, Color textPrimary) {
    if (isNeu) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.bgNeu,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 10, offset: Offset(5, 5)),
            BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 10, offset: Offset(-5, -5)),
          ],
        ),
        child: Stack(
          children: [
            Center(child: Icon(Icons.notifications_none_rounded, color: textPrimary, size: 22)),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Stack(
        children: [
          Center(child: Icon(Icons.notifications_none_rounded, color: textPrimary, size: 19)),
          Positioned(
            top: 9,
            right: 10,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFE5484D),
                shape: BoxShape.circle,
              ),
              foregroundDecoration: const BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isNeu) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadSales,
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroCard(isNeu),
          const SizedBox(height: 16),
          _buildWeekMonthRow(isNeu),
          const SizedBox(height: 18),
          _buildQuickActions(isNeu),
          const SizedBox(height: 20),
          _buildLowStockAlert(isNeu),
          const SizedBox(height: 20),
          _buildSectionHeader('Recent sales', 'See all', isNeu, onAction: _openHistory),
          const SizedBox(height: 12),
          _buildRecentSales(isNeu),
          const SizedBox(height: 20),
          _buildSectionHeader('Top selling today', null, isNeu),
          const SizedBox(height: 12),
          _buildTopSelling(isNeu),
        ],
      ),
      ),
    );
  }


  Widget _buildHeroCard(bool isNeu) {
    if (isNeu) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.bgNeu,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 20, offset: Offset(9, 9)),
            BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 20, offset: Offset(-9, -9)),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: _heroCardContent(isNeu),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0DA86F), Color(0xFF067049)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF087049).withValues(alpha: 0.32),
              blurRadius: 32,
              offset: const Offset(0, 16)),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: _heroCardContent(isNeu),
    );
  }

  Widget _heroCardContent(bool isNeu) {
    final labelColor = isNeu
        ? AppColors.textSecondaryNeu
        : Colors.white.withValues(alpha: 0.8);
    final valueColor = isNeu ? AppColors.primary : Colors.white;
    final badgeColor = isNeu ? AppColors.primaryDark : Colors.white;
    final badgeBg = isNeu
        ? const Color(0xFFECEFED)
        : Colors.white.withValues(alpha: 0.2);
    final subColor = isNeu ? AppColors.textSecondaryNeu : Colors.white.withValues(alpha: 0.8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("Today's sales",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(999)),
              child: Text(SalesFormat.change(_today?.changePercent) ?? '—',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: badgeColor)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(_today != null ? SalesFormat.money(_today!.grossTotal) : 'TSh —',
            style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: valueColor,
                fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(height: 2),
        Text(
            _today == null
                ? 'Sales figures unavailable'
                : '${_today!.saleCount} transaction${_today!.saleCount == 1 ? '' : 's'}'
                    ' · vs ${SalesFormat.money(_today!.previousPeriodTotal)} yesterday',
            style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        _miniChart(isNeu),
      ],
    );
  }

  Widget _miniChart(bool isNeu) {
    // Last 7 days, today last.
    final totals = _week?.trend.map((p) => p.total).toList() ?? List.filled(7, 0.0);
    final max = totals.fold<double>(0, (m, v) => v > m ? v : m);
    final heights = totals.map((v) => max == 0 ? 0.06 : (v / max).clamp(0.06, 1.0)).toList();
    final barColor = isNeu ? const Color(0xFFCBD3CE) : Colors.white.withValues(alpha: 0.3);
    final activeColor = isNeu ? AppColors.primary : Colors.white;

    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(heights.length, (i) {
          final active = i == heights.length - 1;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 44 * heights[i],
              decoration: BoxDecoration(
                color: active ? activeColor : barColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWeekMonthRow(bool isNeu) {
    return Row(
      children: [
        Expanded(
            child: _statCard('Last 7 days',
                _week != null ? SalesFormat.compactMoney(_week!.grossTotal) : 'TSh —',
                SalesFormat.change(_week?.changePercent) ?? '', isNeu)),
        const SizedBox(width: 12),
        Expanded(
            child: _statCard('This month',
                _month != null ? SalesFormat.compactMoney(_month!.grossTotal) : 'TSh —',
                SalesFormat.change(_month?.changePercent) ?? '', isNeu)),
      ],
    );
  }

  Widget _statCard(String label, String value, String badge, bool isNeu) {
    final textPrimary = isNeu ? AppColors.textPrimaryNeu : AppColors.textPrimary;
    final textSec = isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;

    if (isNeu) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.bgNeu,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 13, offset: Offset(6, 6)),
            BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 13, offset: Offset(-6, -6)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: textSec, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: textSec, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(height: 2),
          Text(badge,
              style: TextStyle(
                  fontSize: 11,
                  color: badge.startsWith('▼') ? AppColors.error : const Color(0xFF0E7A55),
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isNeu) {
    final actions = [
      _QuickAction(icon: Icons.add, label: 'New sale', primary: true),
      _QuickAction(icon: Icons.add_box_rounded, label: 'Add product', primary: false),
      _QuickAction(icon: Icons.people_alt_rounded, label: 'Customers', primary: false),
      _QuickAction(icon: Icons.bar_chart_rounded, label: 'Reports', primary: false),
    ];

    return Row(
      children: actions.map((a) {
        return Expanded(
          child: _TapScale(
            onTap: () {
              if (a.label == 'New sale') {
                Navigator.of(context)
                    .push(_slideRight(NewSaleScreen(themeMode: _theme)))
                    .then((_) => _loadSales());
              } else if (a.label == 'Add product') {
                Navigator.of(context).push(
                    _slideRight(AddProductScreen(themeMode: _theme)));
              } else if (a.label == 'Customers') {
                Navigator.of(context).push(
                    _slideRight(CustomerListScreen(themeMode: _theme)));
              } else if (a.label == 'Reports') {
                Navigator.of(context).push(
                    _slideRight(SalesReportScreen(themeMode: _theme)));
              }
            },
            child: Column(
              children: [
                _actionIcon(a, isNeu),
                const SizedBox(height: 8),
                Text(a.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isNeu
                            ? const Color(0xFF5E6C66)
                            : const Color(0xFF3A4742))),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _actionIcon(_QuickAction a, bool isNeu) {
    if (a.primary) {
      return Container(
        width: isNeu ? 58 : 54,
        height: isNeu ? 58 : 54,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(isNeu ? 19 : 17),
          boxShadow: isNeu
              ? const [
                  BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 13, offset: Offset(6, 6)),
                  BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 13, offset: Offset(-6, -6)),
                ]
              : [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 8)),
                ],
        ),
        child: Icon(a.icon, color: Colors.white, size: 24),
      );
    }

    if (isNeu) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: AppColors.bgNeu,
          borderRadius: BorderRadius.circular(19),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 13, offset: Offset(6, 6)),
            BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 13, offset: Offset(-6, -6)),
          ],
        ),
        child: Icon(a.icon, color: AppColors.textPrimaryNeu, size: 22),
      );
    }

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Icon(a.icon, color: AppColors.textPrimary, size: 22),
    );
  }

  Widget _buildLowStockAlert(bool isNeu) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFBE6C0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF1DC),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFB26A00), size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('7 products low on stock',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text('2 are out of stock',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9A7B3D),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const Text('View',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB26A00))),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? action, bool isNeu, {VoidCallback? onAction}) {
    final textPrimary = isNeu ? AppColors.textPrimaryNeu : AppColors.textPrimary;
    return Row(
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary)),
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
      ],
    );
  }

  Widget _buildRecentSales(bool isNeu) {
    final recent = _recent ?? const <SaleListItem>[];
    final sales = recent.map((s) {
      final when = s.saleDate == null
          ? ''
          : SalesFormat.dayLabel(s.saleDate!) == 'Today'
              ? SalesFormat.time(s.saleDate!)
              : '${SalesFormat.shortDate(s.saleDate!)} ${SalesFormat.time(s.saleDate!)}';
      final status = s.status == SaleStatus.completed ? '' : ' · ${s.status.label}';
      final receipt = s.receiptNo ?? '';
      return _SaleItem(
        s.title,
        '$when · ${s.paymentMethod.label} · ${s.itemCount} item${s.itemCount == 1 ? '' : 's'}$status',
        SalesFormat.money(s.grandTotal),
        receipt.length > 3 ? receipt.substring(receipt.length - 3) : receipt.padLeft(3, '0'),
        onTap: () => _openSale(s),
      );
    }).toList();

    if (sales.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: isNeu
            ? BoxDecoration(
                color: AppColors.bgNeu,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 13, offset: Offset(6, 6)),
                  BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 13, offset: Offset(-6, -6)),
                ],
              )
            : BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderDefault),
              ),
        child: Text(_recent == null ? 'Recent sales unavailable' : 'No sales yet',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                color: isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary)),
      );
    }

    if (isNeu) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.bgNeu,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 13, offset: Offset(6, 6)),
            BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 13, offset: Offset(-6, -6)),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: List.generate(sales.length, (i) {
            return Column(
              children: [
                _saleRow(sales[i], isNeu),
                if (i < sales.length - 1)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: const Color(0xFFD5DDD8),
                  ),
              ],
            );
          }),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: List.generate(sales.length, (i) {
          return Column(
            children: [
              _saleRow(sales[i], isNeu),
              if (i < sales.length - 1)
                const Divider(height: 1, color: Color(0xFFF0F3F1)),
            ],
          );
        }),
      ),
    );
  }

  Widget _saleRow(_SaleItem sale, bool isNeu) {
    final textPrimary = isNeu ? AppColors.textPrimaryNeu : AppColors.textPrimary;
    final textSec = isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;

    return GestureDetector(
      onTap: sale.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: isNeu ? 40 : 38,
            height: isNeu ? 40 : 38,
            decoration: BoxDecoration(
              color: isNeu ? AppColors.bgNeu : const Color(0xFFE7F6EF),
              borderRadius: BorderRadius.circular(isNeu ? 12 : 11),
              boxShadow: isNeu
                  ? const [
                      BoxShadow(
                          color: AppColors.shadowDarkNeu,
                          blurRadius: 6,
                          offset: Offset(3, 3),
                          spreadRadius: -1),
                      BoxShadow(
                          color: AppColors.shadowLightNeu,
                          blurRadius: 6,
                          offset: Offset(-3, -3),
                          spreadRadius: -1),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                sale.code,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sale.name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPrimary)),
                Text(sale.sub,
                    style: TextStyle(
                        fontSize: 12,
                        color: textSec,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text(sale.amount,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
      ),
    );
  }

  Widget _buildTopSelling(bool isNeu) {
    final top = _today?.topProducts ?? const <TopProduct>[];
    final items = [
      for (var i = 0; i < top.length; i++)
        _TopItem(top[i].productName, '${SalesFormat.quantity(top[i].quantity)} sold',
            SalesFormat.money(top[i].total), i + 1),
    ];

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: isNeu
            ? BoxDecoration(
                color: AppColors.bgNeu,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 13, offset: Offset(6, 6)),
                  BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 13, offset: Offset(-6, -6)),
                ],
              )
            : BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderDefault),
              ),
        child: Text(_today == null ? 'Top products unavailable' : 'No sales today yet',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                color: isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary)),
      );
    }

    if (isNeu) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.bgNeu,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 13, offset: Offset(6, 6)),
            BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 13, offset: Offset(-6, -6)),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: List.generate(items.length, (i) {
            return Column(
              children: [
                _topRow(items[i], isNeu),
                if (i < items.length - 1)
                  Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 12), color: const Color(0xFFD5DDD8)),
              ],
            );
          }),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDefault),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: List.generate(items.length, (i) {
          return Column(
            children: [
              _topRow(items[i], isNeu),
              if (i < items.length - 1) const Divider(height: 1, color: Color(0xFFF0F3F1)),
            ],
          );
        }),
      ),
    );
  }

  Widget _topRow(_TopItem item, bool isNeu) {
    final textPrimary = isNeu ? AppColors.textPrimaryNeu : AppColors.textPrimary;
    final textSec = isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '${item.rank}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: item.rank == 1 ? AppColors.primary : AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEEF2F0), Color(0xFFE4EAE7)],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPrimary)),
                Text(item.sold,
                    style: TextStyle(fontSize: 12, color: textSec, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text(item.revenue,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final bool primary;
  _QuickAction({required this.icon, required this.label, required this.primary});
}

class _SaleItem {
  final String name, sub, amount, code;
  final VoidCallback? onTap;
  _SaleItem(this.name, this.sub, this.amount, this.code, {this.onTap});
}

class _TopItem {
  final String name, sold, revenue;
  final int rank;
  _TopItem(this.name, this.sold, this.revenue, this.rank);
}

class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _TapScale({required this.child, this.onTap});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.88 : 1.0,
        duration: Duration(milliseconds: _down ? 80 : 240),
        curve: _down ? Curves.easeIn : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
