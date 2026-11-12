import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BottomNav extends StatelessWidget {
  final int activeIndex;
  final bool isNeu;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.activeIndex,
    required this.isNeu,
    required this.onTap,
  });

  static const _icons = [
    Icons.dashboard_rounded,
    Icons.receipt_long_rounded,
    Icons.inventory_2_rounded,
    Icons.bar_chart_rounded,
    Icons.more_horiz_rounded,
  ];
  static const _labels = ['Dashboard', 'Sales', 'Products', 'Reports', 'More'];

  @override
  Widget build(BuildContext context) {
    final bot = MediaQuery.of(context).padding.bottom;

    if (isNeu) {
      return _NeuNav(
        icons: _icons, labels: _labels,
        activeIndex: activeIndex, onTap: onTap, bot: bot,
      );
    }

    return _DefaultNav(
      icons: _icons, labels: _labels,
      activeIndex: activeIndex, onTap: onTap, bot: bot,
    );
  }
}

// ── Default theme nav ─────────────────────────────────────────────────────────

class _DefaultNav extends StatelessWidget {
  final List<IconData> icons;
  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onTap;
  final double bot;

  const _DefaultNav({
    required this.icons, required this.labels,
    required this.activeIndex, required this.onTap, required this.bot,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEDF1EF), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24, offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(6, 10, 6, bot + 8),
      child: Row(
        children: List.generate(icons.length, (i) {
          final active = i == activeIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Pill indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFD9F5EA)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icons[i], size: 22,
                    color: active
                        ? AppColors.primary
                        : const Color(0xFFA2AFA8),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? AppColors.primary : const Color(0xFFA2AFA8),
                  ),
                  child: Text(labels[i], maxLines: 1),
                ),
              ]),
            ),
          );
        }),
      ),
    );
  }
}

// ── Neumorphic theme nav ──────────────────────────────────────────────────────

class _NeuNav extends StatelessWidget {
  final List<IconData> icons;
  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onTap;
  final double bot;

  const _NeuNav({
    required this.icons, required this.labels,
    required this.activeIndex, required this.onTap, required this.bot,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(22, 0, 22, bot + 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.bgNeu,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 18, offset: Offset(8, 8)),
          BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 18, offset: Offset(-8, -8)),
        ],
      ),
      child: Row(
        children: List.generate(icons.length, (i) {
          final active = i == activeIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.bgNeu,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.38),
                              blurRadius: 14, offset: const Offset(0, 5)),
                          ]
                        : const [
                            BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 7, offset: Offset(3, 3)),
                            BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 7, offset: Offset(-3, -3)),
                          ],
                  ),
                  child: Icon(icons[i], size: 20,
                      color: active ? Colors.white : AppColors.textSecondaryNeu),
                ),
                const SizedBox(height: 5),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: active ? AppColors.primaryDark : AppColors.textSecondaryNeu,
                  ),
                  child: Text(labels[i], maxLines: 1),
                ),
              ]),
            ),
          );
        }),
      ),
    );
  }
}