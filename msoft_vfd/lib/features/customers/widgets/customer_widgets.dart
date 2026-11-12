import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/customer.dart';

class CustomerUi {
  CustomerUi._();

  static const _bg = [Color(0xFFDFF5EB), Color(0xFFDEEFFE), Color(0xFFFFF3E0), Color(0xFFF3E8FF)];
  static const _fg = [AppColors.primaryDark, Color(0xFF2E6FD8), Color(0xFFB26A00), Color(0xFF7C3AED)];

  static int _idx(String key) => key.hashCode.abs() % _bg.length;

  static Color statusColor(CustomerStatus s) => switch (s) {
        CustomerStatus.active => AppColors.primaryDark,
        CustomerStatus.inactive => AppColors.textMuted,
        CustomerStatus.suspended => AppColors.error,
      };

  static Color avatarBg(String name) => _bg[_idx(name)];
  static Color avatarFg(String name) => _fg[_idx(name)];
}

/// Circle with the customer's initials.
class CustomerAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool isNeu;
  const CustomerAvatar({super.key, required this.name, required this.isNeu, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isNeu ? AppColors.bgNeu : CustomerUi.avatarBg(name),
        boxShadow: isNeu
            ? const [
                BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 6, offset: Offset(3, 3), spreadRadius: -1),
                BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 6, offset: Offset(-3, -3), spreadRadius: -1),
              ]
            : null,
      ),
      child: Text(initialsOf(name),
          style: TextStyle(
              fontSize: size * 0.36,
              fontWeight: FontWeight.w800,
              color: CustomerUi.avatarFg(name))),
    );
  }
}

class CustomerStatusPill extends StatelessWidget {
  final CustomerStatus status;
  const CustomerStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = CustomerUi.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(status.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
    );
  }
}
