import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../services/session_manager.dart';
import '../utils/auth_state.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Logo bounces in
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  // Title + tagline slide up
  late final AnimationController _textCtrl;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _tagFade;

  // Loading dots
  late final AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _logoScale = Tween<double>(begin: 0.42, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _logoCtrl,
            curve: const Interval(0.0, 0.35, curve: Curves.easeIn)));

    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _textCtrl,
            curve: const Interval(0.0, 0.65, curve: Curves.easeOut)));
    _textSlide =
        Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
            CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _tagFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _textCtrl,
            curve: const Interval(0.55, 1.0, curve: Curves.easeOut)));

    _dotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 120));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 480));
    _textCtrl.forward();

    // Restore a persisted session (if any) in parallel with the animation.
    final session = await SessionManager.instance.load();
    if (session != null) AuthState.applySession(session);

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    const expo = Cubic(0.16, 1.0, 0.3, 1.0);

    PageRouteBuilder<void> slideUp(Widget page, {bool reversible = false}) =>
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => page,
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration:
              reversible ? const Duration(milliseconds: 500) : Duration.zero,
          transitionsBuilder: (_, anim, _, child) {
            final slide = Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: expo));
            final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: anim,
                curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
              ),
            );
            return FadeTransition(
              opacity: fade,
              child: SlideTransition(position: slide, child: child),
            );
          },
        );

    if (AuthState.isLoggedIn) {
      // Already authenticated — replace splash so the user can't swipe back to it.
      Navigator.of(context).pushReplacement(
        slideUp(DashboardScreen(themeMode: AuthState.lastTheme)),
      );
    } else {
      // Keep splash in the back stack: swiping back on login slides down to splash.
      // login_screen.dart clears the full stack (pushAndRemoveUntil) on sign-in.
      Navigator.of(context).push(
        slideUp(const LoginScreen(), reversible: true),
      );
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
          backgroundColor: AppColors.primary,
          body: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // ── Logo ──────────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _logoCtrl,
                  builder: (_, _) => FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: _Logo(),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // ── Title + tagline ───────────────────────────────────────
                AnimatedBuilder(
                  animation: _textCtrl,
                  builder: (_, _) => FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Column(children: [
                        Text.rich(
                          TextSpan(
                            text: 'MSOFT ',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.6,
                            ),
                            children: [
                              TextSpan(
                                text: 'vfd',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.68),
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),
                        FadeTransition(
                          opacity: _tagFade,
                          child: Text(
                            'Virtual Fiscal Device',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.58),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                // ── Pulsing dots ──────────────────────────────────────────
                AnimatedBuilder(
                  animation: _dotCtrl,
                  builder: (_, _) => _Dots(progress: _dotCtrl.value),
                ),

                const SizedBox(height: 52),
              ],
            ),
          ),
        ),
    );
  }
}


// ── Extracted widgets ───────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.12),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Container(
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
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final double progress;
  const _Dots({required this.progress});

  double _opacity(int index) {
    // Each dot is offset by 1/3 of the cycle and pulses 0.25 → 1.0 → 0.25
    final t = (progress - index / 3.0) % 1.0;
    // Triangle wave: 0→0.5 ramps up, 0.5→1.0 ramps down
    final v = t < 0.5 ? t / 0.5 : 1.0 - (t - 0.5) / 0.5;
    return 0.25 + v * 0.75;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _opacity(i)),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}