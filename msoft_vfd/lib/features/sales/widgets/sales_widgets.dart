import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/sale.dart';

/// Building blocks shared by the sales history / detail / report screens,
/// matching the app's two looks (default flat cards and neumorphic).
class SalesUi {
  SalesUi._();

  static Color bg(bool isNeu) => isNeu ? AppColors.bgNeu : AppColors.bgDefault;
  static Color text(bool isNeu) => isNeu ? AppColors.textPrimaryNeu : AppColors.textPrimary;
  static Color textSec(bool isNeu) => isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;
  static double gutter(bool isNeu) => isNeu ? 22.0 : 20.0;

  static BoxDecoration card(bool isNeu, {double radius = 18}) => isNeu
      ? BoxDecoration(
          color: AppColors.bgNeu,
          borderRadius: BorderRadius.circular(radius + 2),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 13, offset: Offset(6, 6)),
            BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 13, offset: Offset(-6, -6)),
          ],
        )
      : BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.borderDefault),
        );

  static const tabular = [FontFeature.tabularFigures()];

  static Color statusColor(SaleStatus s) => switch (s) {
        SaleStatus.completed => AppColors.primaryDark,
        SaleStatus.pending => AppColors.warningText,
        SaleStatus.cancelled => AppColors.error,
        SaleStatus.refunded => AppColors.purple,
      };
}

/// Back button + title + optional trailing action, as used across the app.
class SalesHeader extends StatelessWidget {
  final String title;
  final bool isNeu;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const SalesHeader({
    super.key,
    required this.title,
    required this.isNeu,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final px = SalesUi.gutter(isNeu);
    return Padding(
      padding: EdgeInsets.fromLTRB(px, 12, px, 10),
      child: Row(
        children: [
          SalesIconButton(
            icon: Icons.arrow_back_ios_new,
            isNeu: isNeu,
            onTap: () => Navigator.of(context).maybePop(),
            iconSize: 14,
            color: SalesUi.text(isNeu),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: SalesUi.text(isNeu))),
          ),
          if (actionIcon != null)
            SalesIconButton(icon: actionIcon!, isNeu: isNeu, onTap: onAction),
        ],
      ),
    );
  }
}

class SalesIconButton extends StatelessWidget {
  final IconData icon;
  final bool isNeu;
  final VoidCallback? onTap;
  final double iconSize;
  final Color? color;

  const SalesIconButton({
    super.key,
    required this.icon,
    required this.isNeu,
    this.onTap,
    this.iconSize = 18,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: isNeu
            ? BoxDecoration(
                color: AppColors.bgNeu,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 9, offset: Offset(4, 4)),
                  BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 9, offset: Offset(-4, -4)),
                ],
              )
            : BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDefault),
              ),
        child: Icon(icon, size: iconSize, color: color ?? SalesUi.textSec(isNeu)),
      ),
    );
  }
}

/// Pill used for period / status filters.
class SalesChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool isNeu;
  final VoidCallback onTap;

  const SalesChip({
    super.key,
    required this.label,
    required this.active,
    required this.isNeu,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: isNeu
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.bgNeu,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: active
                      ? const [
                          BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 6, offset: Offset(3, 3), spreadRadius: -2),
                          BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 6, offset: Offset(-3, -3), spreadRadius: -2),
                        ]
                      : const [
                          BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 9, offset: Offset(4, 4)),
                          BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 9, offset: Offset(-4, -4)),
                        ],
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active ? AppColors.primaryDark : const Color(0xFF5E6C66))),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: active ? AppColors.primary : AppColors.borderDefault),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : const Color(0xFF5E6F69))),
              ),
      ),
    );
  }
}

class SaleStatusBadge extends StatelessWidget {
  final SaleStatus status;
  const SaleStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = SalesUi.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status.label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Centered message with an optional retry button, for empty and error states.
class SalesMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isNeu;
  final VoidCallback? onRetry;

  const SalesMessage({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.isNeu,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: SalesUi.textSec(isNeu)),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: SalesUi.text(isNeu))),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: SalesUi.textSec(isNeu))),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}
