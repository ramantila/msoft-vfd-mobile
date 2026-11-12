import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../utils/auth_state.dart';
import '../../dashboard/screens/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  AppThemeMode _theme   = AppThemeMode.defaultMode;
  bool _obscure         = true;
  bool _remember        = true;
  bool _loading         = false;

  final _phoneFocus    = FocusNode();
  final _passwordFocus = FocusNode();
  final _phoneCtrl     = TextEditingController(text: '+255 712 345 678');
  final _passwordCtrl  = TextEditingController();

  late final AnimationController _heroCtrl;   // logo float
  late final AnimationController _sheetCtrl;  // card slide-up

  late final Animation<double>  _logoFloat;
  late final Animation<Offset>  _sheetSlide;
  late final Animation<double>  _sheetFade;

  @override
  void initState() {
    super.initState();

    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    _logoFloat = Tween<double>(begin: 0, end: -10).animate(
        CurvedAnimation(parent: _heroCtrl, curve: Curves.easeInOut));

    _sheetCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _sheetSlide = Tween<Offset>(
            begin: const Offset(0, 0.22), end: Offset.zero)
        .animate(CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOutCubic));
    _sheetFade  = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _sheetCtrl,
            curve: const Interval(0.0, 0.60, curve: Curves.easeOut)));
    _sheetCtrl.forward();

    _phoneFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _sheetCtrl.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final session = await AuthService.instance.login(
        _phoneCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (!mounted) return;
      AuthState.applySession(session);
      AuthState.lastTheme = _theme;
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toApiException().message)),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
      return;
    }

    const expo = Cubic(0.16, 1.0, 0.3, 1.0);
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => DashboardScreen(themeMode: _theme),
        transitionDuration: const Duration(milliseconds: 420),
        transitionsBuilder: (_, anim, _, child) {
          final slide = Tween<Offset>(
                  begin: const Offset(0.0, 1.0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: expo));
          final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: anim,
                  curve: const Interval(0.0, 0.45, curve: Curves.easeOut)));
          return FadeTransition(opacity: fade,
              child: SlideTransition(position: slide, child: child));
        },
      ),
      (route) => false,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isNeu  = _theme == AppThemeMode.neumorphic;
    final size   = MediaQuery.of(context).size;
    final bot    = MediaQuery.of(context).padding.bottom;
    final heroH  = size.height * 0.38;

    return Scaffold(
      backgroundColor: isNeu ? AppColors.bgNeu : const Color(0xFFF4F6F5),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Hero background ──────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: heroH,
            child: _buildHero(isNeu, heroH),
          ),

          // ── Form card ───────────────────────────────────────────────────
          Positioned(
            top: heroH,
            left: 0, right: 0, bottom: 0,
            child: SlideTransition(
              position: _sheetSlide,
              child: FadeTransition(
                opacity: _sheetFade,
                child: _buildFormCard(isNeu, bot),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero section ───────────────────────────────────────────────────────────

  Widget _buildHero(bool isNeu, double heroH) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // Gradient base
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF12D48A), Color(0xFF055C3F)],
            ),
          ),
        ),

        // Decorative circles
        Positioned(
          top: -heroH * 0.28,
          right: -heroH * 0.22,
          child: Container(
            width: heroH * 0.72,
            height: heroH * 0.72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ),
        Positioned(
          top: heroH * 0.18,
          right: -heroH * 0.08,
          child: Container(
            width: heroH * 0.36,
            height: heroH * 0.36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ),
        Positioned(
          bottom: heroH * 0.14,
          left: -heroH * 0.18,
          child: Container(
            width: heroH * 0.50,
            height: heroH * 0.50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),
        // Dot grid pattern (top-left)
        Positioned(
          top: 56, left: 20,
          child: CustomPaint(
            size: const Size(90, 90),
            painter: _DotGridPainter(
                color: Colors.white.withValues(alpha: 0.12)),
          ),
        ),

        // Content
        SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Theme pill (top-right)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => setState(() => _theme =
                        _theme == AppThemeMode.defaultMode
                            ? AppThemeMode.neumorphic
                            : AppThemeMode.defaultMode),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          _theme == AppThemeMode.neumorphic
                              ? Icons.wb_sunny_outlined
                              : Icons.blur_on_rounded,
                          size: 12, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          _theme == AppThemeMode.neumorphic
                              ? 'Default' : 'Neumorphic',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Floating logo
              AnimatedBuilder(
                animation: _logoFloat,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _logoFloat.value),
                  child: child,
                ),
                child: Column(children: [
                  // Logo ring
                  Container(
                    width: 62, height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.30), width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.storefront_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // App name
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: -0.5),
                      children: [
                        TextSpan(text: 'MSOFT '),
                        TextSpan(text: 'vfd',
                            style: TextStyle(color: Color(0xFFAAF0D1))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Smart POS for your business',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.78))),
                ]),
              ),

              const SizedBox(height: 12),

              // Feature chips
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _featureChip(Icons.receipt_long_outlined, 'Sales'),
                  const SizedBox(width: 8),
                  _featureChip(Icons.inventory_2_outlined, 'Inventory'),
                  const SizedBox(width: 8),
                  _featureChip(Icons.bar_chart_rounded, 'Reports'),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _featureChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ]),
      );

  // ── Form card ──────────────────────────────────────────────────────────────

  Widget _buildFormCard(bool isNeu, double bot) {
    final cardBg   = isNeu ? AppColors.bgNeu : Colors.white;
    final tp       = isNeu ? AppColors.textPrimaryNeu : AppColors.textPrimary;
    final ts       = isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;
    final divColor = isNeu ? const Color(0xFFD5DDD8) : const Color(0xFFF0F3F1);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 40, offset: const Offset(0, -8)),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 16, 24, bot + 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                  color: divColor, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Heading row
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Welcome back!',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800,
                        color: tp, letterSpacing: -0.4)),
                const SizedBox(height: 3),
                Text('Sign in to your account to continue.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: ts)),
              ]),
            ),
            // Avatar hint
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
                  BoxShadow(color: AppColors.shadowDarkNeu,
                      blurRadius: 8, offset: Offset(4, 4)),
                  BoxShadow(color: AppColors.shadowLightNeu,
                      blurRadius: 8, offset: Offset(-4, -4)),
                ] : [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: const Center(
                child: Text('SK',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ),
          ]),

          const SizedBox(height: 26),

          // Phone field
          _fieldLabel('Phone or email', ts),
          const SizedBox(height: 8),
          _inputField(
            isNeu: isNeu, tp: tp, ts: ts,
            icon: Icons.phone_outlined,
            focusNode: _phoneFocus,
            child: TextField(
              controller: _phoneCtrl,
              focusNode: _phoneFocus,
              keyboardType: TextInputType.phone,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tp),
              decoration: InputDecoration(
                hintText: '+255 7XX XXX XXX',
                hintStyle: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w500, color: ts),
                border: InputBorder.none,
                isDense: true, contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Password field
          _fieldLabel('Password', ts),
          const SizedBox(height: 8),
          _inputField(
            isNeu: isNeu, tp: tp, ts: ts,
            icon: Icons.lock_outline_rounded,
            focusNode: _passwordFocus,
            trailing: GestureDetector(
              onTap: () => setState(() => _obscure = !_obscure),
              child: Icon(
                _obscure ? Icons.visibility_outlined
                         : Icons.visibility_off_outlined,
                size: 18, color: ts),
            ),
            child: TextField(
              controller: _passwordCtrl,
              focusNode: _passwordFocus,
              obscureText: _obscure,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tp),
              decoration: InputDecoration(
                hintText: 'Enter your password',
                hintStyle: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w500, color: ts),
                border: InputBorder.none,
                isDense: true, contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Remember + Forgot
          Row(children: [
            GestureDetector(
              onTap: () => setState(() => _remember = !_remember),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: _remember ? AppColors.primary
                        : (isNeu ? AppColors.bgNeu : Colors.white),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _remember ? AppColors.primary
                          : (isNeu ? const Color(0xFFBEC8C2)
                                   : AppColors.borderDefault),
                    ),
                    boxShadow: isNeu && !_remember ? const [
                      BoxShadow(color: AppColors.shadowDarkNeu,
                          blurRadius: 4, offset: Offset(2, 2)),
                      BoxShadow(color: AppColors.shadowLightNeu,
                          blurRadius: 4, offset: Offset(-2, -2)),
                    ] : null,
                  ),
                  child: _remember
                      ? const Icon(Icons.check_rounded,
                          size: 13, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                Text('Remember me',
                    style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w500, color: ts)),
              ]),
            ),
            const Spacer(),
            const Text('Forgot password?',
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700, color: AppColors.primary)),
          ]),

          const SizedBox(height: 26),

          // Sign in button
          GestureDetector(
            onTap: _loading ? null : _login,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 17),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF0EC87F), Color(0xFF067A53)],
                ),
                borderRadius: BorderRadius.circular(isNeu ? 18 : 16),
                boxShadow: isNeu ? const [
                  BoxShadow(color: AppColors.shadowDarkNeu,
                      blurRadius: 14, offset: Offset(6, 6)),
                  BoxShadow(color: AppColors.shadowLightNeu,
                      blurRadius: 14, offset: Offset(-6, -6)),
                ] : [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Sign in',
                            style: TextStyle(fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 18),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // Divider
          Row(children: [
            Expanded(child: Container(height: 1, color: divColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('or', style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w600, color: ts)),
            ),
            Expanded(child: Container(height: 1, color: divColor)),
          ]),

          const SizedBox(height: 20),

          // PIN login option
          GestureDetector(
            onTap: _loading ? null : _login,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isNeu ? AppColors.bgNeu : const Color(0xFFF4F6F5),
                borderRadius: BorderRadius.circular(isNeu ? 18 : 16),
                border: isNeu ? null : Border.all(color: divColor),
                boxShadow: isNeu ? const [
                  BoxShadow(color: AppColors.shadowDarkNeu,
                      blurRadius: 10, offset: Offset(5, 5)),
                  BoxShadow(color: AppColors.shadowLightNeu,
                      blurRadius: 10, offset: Offset(-5, -5)),
                ] : null,
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.grid_view_rounded, size: 17, color: ts),
                const SizedBox(width: 8),
                Text('Sign in with PIN',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: tp)),
              ]),
            ),
          ),

          const SizedBox(height: 22),

          // Footer
          Center(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ts),
                children: const [
                  TextSpan(text: 'Need access? '),
                  TextSpan(text: 'Contact your administrator',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('v1.0.0 · Secured by MSOFT',
                style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w500, color: ts)),
          ),
        ]),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _fieldLabel(String text, Color ts) => Text(text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ts));

  Widget _inputField({
    required bool isNeu,
    required Color tp,
    required Color ts,
    required IconData icon,
    required FocusNode focusNode,
    required Widget child,
    Widget? trailing,
  }) {
    final focused = focusNode.hasFocus;
    final inner = Row(children: [
      Icon(icon, size: 17,
          color: focused ? AppColors.primary : ts),
      const SizedBox(width: 12),
      Expanded(child: child),
      if (trailing != null) ...[const SizedBox(width: 8), trailing],
    ]);

    if (isNeu) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.bgNeu,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowDarkNeu,
                blurRadius: 10, offset: Offset(5, 5)),
            BoxShadow(color: AppColors.shadowLightNeu,
                blurRadius: 10, offset: Offset(-5, -5)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: inner,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused ? AppColors.primary : AppColors.borderDefault,
          width: focused ? 1.5 : 1.0,
        ),
        boxShadow: focused ? [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.10),
              blurRadius: 0, spreadRadius: 3),
        ] : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: inner,
    );
  }
}

// ── Dot grid painter ──────────────────────────────────────────────────────────

class _DotGridPainter extends CustomPainter {
  final Color color;
  const _DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const gap  = 14.0;
    const r    = 1.8;
    for (double x = 0; x <= size.width; x += gap) {
      for (double y = 0; y <= size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}
