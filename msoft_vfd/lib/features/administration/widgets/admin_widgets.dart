import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Shared chrome for the administration feature's screens — header, card,
/// loading/empty/error states, form inputs, buttons, and a confirm dialog —
/// so each list/form screen doesn't re-implement identical boilerplate.
/// Colors/decorations still branch on `isNeu` to match the rest of the app.
class AdminHeader extends StatelessWidget {
  final String title;
  final bool isNeu;
  final Color tp;
  final Color ts;
  final Widget? trailing;

  const AdminHeader({
    super.key,
    required this.title,
    required this.isNeu,
    required this.tp,
    required this.ts,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: isNeu ? AppColors.bgNeu : AppColors.bgDefault,
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 14),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: _iconBox(Icons.arrow_back_ios_new_rounded, isNeu, tp),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tp)),
        ),
        ?trailing,
      ]),
    );
  }

  static Widget _iconBox(IconData icon, bool isNeu, Color color) {
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
        child: Icon(icon, color: color, size: 14),
      );
    }
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }
}

class AdminCard extends StatelessWidget {
  final bool isNeu;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AdminCard({
    super.key,
    required this.isNeu,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: isNeu ? AppTheme.neuCard() : AppTheme.defaultCard(),
        padding: padding,
        child: child,
      );
}

/// A small icon+value+label tile, meant to sit in a 2-column grid (e.g. plan
/// limits: max users, max branches, ...).
class AdminStatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool isNeu;
  final Color tp;
  final Color ts;
  final Color accent;

  const AdminStatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.isNeu,
    required this.tp,
    required this.ts,
    this.accent = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: isNeu ? AppTheme.neuInset(radius: 14) : AppTheme.defaultCard(radius: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tp)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ts)),
        ]),
      );
}

class AdminLoading extends StatelessWidget {
  const AdminLoading({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
        ),
      );
}

class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tp;
  final Color ts;

  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tp,
    required this.ts,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(children: [
          Icon(icon, size: 40, color: ts),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tp)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ts)),
        ]),
      );
}

class AdminErrorBanner extends StatelessWidget {
  final String message;
  final Color tp;
  final Color ts;
  final VoidCallback? onRetry;

  const AdminErrorBanner({
    super.key,
    required this.message,
    required this.tp,
    required this.ts,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEDF0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFAD2D6)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFE5484D), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB3242B))),
          ),
          if (onRetry != null)
            GestureDetector(
              onTap: onRetry,
              child: const Text('Retry',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFB3242B))),
            ),
        ]),
      );
}

class AdminTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isNeu;
  final Color tp;
  final Color ts;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final String? hint;

  const AdminTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.isNeu,
    required this.tp,
    required this.ts,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ts)),
      const SizedBox(height: 8),
      Container(
        decoration: isNeu ? AppTheme.neuInset() : AppTheme.defaultCard(radius: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tp),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ts),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }
}

class AdminPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  const AdminPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0EC87F), Color(0xFF067A53)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.30),
                  blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      );
}

/// Returns true if the user confirmed.
Future<bool> showAdminConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required bool isNeu,
  bool destructive = true,
}) async {
  final bg = isNeu ? AppColors.bgNeu : Colors.white;
  final tp = isNeu ? AppColors.textPrimaryNeu : AppColors.textPrimary;
  final ts = isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;
  final div = isNeu ? const Color(0xFFD5DDD8) : const Color(0xFFF0F3F1);

  final result = await showDialog<bool>(
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
              color: destructive ? const Color(0xFFFFEDF0) : const Color(0xFFDFF5EB),
              shape: BoxShape.circle,
            ),
            child: Icon(
              destructive ? Icons.delete_outline_rounded : Icons.help_outline_rounded,
              color: destructive ? const Color(0xFFE5484D) : AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tp)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ts, height: 1.4)),
          const SizedBox(height: 20),
          Container(height: 1, color: div),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: isNeu ? AppColors.bgNeu : const Color(0xFFF4F6F5),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text('Cancel',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tp)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: destructive ? const Color(0xFFE5484D) : AppColors.primary,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(confirmLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
  return result ?? false;
}
