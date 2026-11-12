import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/models/session.dart';
import '../models/staff.dart';

class StaffUi {
  StaffUi._();

  static Color statusColor(StaffStatus s) => switch (s) {
        StaffStatus.active => AppColors.primaryDark,
        StaffStatus.inactive => AppColors.textMuted,
        StaffStatus.suspended => AppColors.error,
      };

  static Color roleColor(UserRole r) => switch (r) {
        UserRole.superAdmin => AppColors.purple,
        UserRole.manager => AppColors.blue,
        UserRole.cashier => AppColors.primaryDark,
        UserRole.viewer => AppColors.textMuted,
      };

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }
}

class StaffAvatar extends StatelessWidget {
  final String name;
  final double size;
  const StaffAvatar({super.key, required this.name, this.size = 44});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF10A56F), Color(0xFF067A53)]),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Text(StaffUi.initials(name),
            style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w800, color: Colors.white)),
      );
}

class StaffPill extends StatelessWidget {
  final String label;
  final Color color;
  const StaffPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );
}

/// Shared input decoration for the staff forms.
InputDecoration staffInput(bool isNeu, String label, {String? error, String? helper, Widget? suffix}) =>
    InputDecoration(
      labelText: label,
      errorText: error,
      helperText: helper,
      suffixIcon: suffix,
      isDense: true,
      filled: true,
      fillColor: isNeu ? const Color(0xFFEEF2F0) : const Color(0xFFF8FAF9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDefault)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDefault)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    );

/// Same heuristic as the web portal's passwordStrength(): a nudge, not a rule.
({int score, String label, Color color}) passwordStrength(String v) {
  if (v.isEmpty) return (score: 0, label: '', color: AppColors.borderDefault);
  var score = 0;
  if (v.length >= 8) score++;
  if (v.length >= 12) score++;
  if (RegExp(r'[a-z]').hasMatch(v) && RegExp(r'[A-Z]').hasMatch(v)) score++;
  if (RegExp(r'[0-9]').hasMatch(v) && RegExp(r'[^A-Za-z0-9]').hasMatch(v)) score++;
  const labels = ['Too short', 'Weak', 'Fair', 'Good', 'Strong'];
  const colors = [AppColors.error, AppColors.error, AppColors.warningText, AppColors.blue, AppColors.primaryDark];
  return (score: score, label: labels[score], color: colors[score]);
}

/// 14 random characters from the portal's charset (no look-alikes like 0/O, 1/l).
String generatePassword() {
  const charset = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%&*';
  final rnd = Random.secure();
  return List.generate(14, (_) => charset[rnd.nextInt(charset.length)]).join();
}

/// Strength bar + label + "Generate secure password", as on the portal.
class PasswordStrengthBar extends StatelessWidget {
  final String password;
  final VoidCallback? onGenerate;
  const PasswordStrengthBar({super.key, required this.password, this.onGenerate});

  @override
  Widget build(BuildContext context) {
    final s = passwordStrength(password);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s.score / 4,
              minHeight: 6,
              backgroundColor: AppColors.borderDefault,
              color: s.color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
            width: 64,
            child: Text(s.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: s.color))),
        if (onGenerate != null)
          TextButton.icon(
            onPressed: onGenerate,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), visualDensity: VisualDensity.compact),
            icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
            label: const Text('Generate', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }
}

/// "3 / 10 users used (Basic)" with a progress bar, as on the portal.
class QuotaBar extends StatelessWidget {
  final int used;
  final int max;
  final String noun;
  final String packageName;
  final bool isNeu;
  const QuotaBar({
    super.key,
    required this.used,
    required this.max,
    required this.noun,
    required this.packageName,
    required this.isNeu,
  });

  @override
  Widget build(BuildContext context) {
    final reached = used >= max;
    final color = reached ? AppColors.error : (used / (max == 0 ? 1 : max) >= 0.8 ? AppColors.warningText : AppColors.primaryDark);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(reached ? Icons.block_rounded : Icons.donut_large_rounded, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text('$used / $max $noun used${packageName.isEmpty ? '' : ' ($packageName)'}',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: max <= 0 ? 1 : (used / max).clamp(0, 1).toDouble(),
          minHeight: 5,
          backgroundColor: AppColors.borderDefault,
          color: color,
        ),
      ),
      if (reached) ...[
        const SizedBox(height: 6),
        Text(
          "You've reached your ${packageName.isEmpty ? '' : '$packageName '}plan's limit of $max $noun. "
          'Upgrade your package or remove an existing one to add more.',
          style: const TextStyle(fontSize: 11.5, color: AppColors.error, height: 1.35),
        ),
      ],
    ]);
  }
}
