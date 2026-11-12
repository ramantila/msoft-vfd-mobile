import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/product.dart';

/// Visual helpers shared by the product list, detail and form screens.
class ProductUi {
  ProductUi._();

  static const _accentBg = [
    Color(0xFFDFF5EB), Color(0xFFDEEFFE), Color(0xFFFFF3E0), Color(0xFFF3E8FF),
  ];
  static const _accentFg = [
    AppColors.primary, Color(0xFF3B82F6), Color(0xFFF59E0B), Color(0xFF9333EA),
  ];

  static int _idx(String? key) => (key ?? '').hashCode.abs() % _accentBg.length;
  static Color accentBg(String? key) => _accentBg[_idx(key)];
  static Color accentFg(String? key) => _accentFg[_idx(key)];

  /// Best-effort icon from the category name; categories are free text.
  static IconData categoryIcon(String? category) {
    final c = (category ?? '').toLowerCase();
    if (c.contains('bever') || c.contains('drink') || c.contains('food') || c.contains('grocer')) {
      return Icons.fastfood_rounded;
    }
    if (c.contains('station') || c.contains('office')) return Icons.edit_note_rounded;
    if (c.contains('house') || c.contains('home') || c.contains('clean')) return Icons.home_rounded;
    if (c.contains('electr') || c.contains('phone')) return Icons.devices_rounded;
    if (c.contains('cloth') || c.contains('fashion') || c.contains('wear')) return Icons.checkroom_rounded;
    if (c.contains('health') || c.contains('beauty') || c.contains('pharm')) return Icons.spa_outlined;
    if (c.contains('agri') || c.contains('farm')) return Icons.grass_rounded;
    if (c.contains('hardware') || c.contains('tool')) return Icons.handyman_rounded;
    return Icons.category_rounded;
  }

  static Color stockColor(StockStatus? s) => switch (s) {
        StockStatus.inStock => AppColors.primaryDark,
        StockStatus.lowStock => AppColors.warningText,
        StockStatus.outOfStock => AppColors.error,
        null => AppColors.textSecondary,
      };

  static Color statusColor(ProductStatus s) => switch (s) {
        ProductStatus.active => AppColors.primaryDark,
        ProductStatus.inactive => AppColors.textMuted,
        ProductStatus.discontinued => AppColors.error,
      };
}

/// Product photo, or a tinted category icon when there's no photo.
class ProductThumb extends StatelessWidget {
  final String? imageUrl;
  final String? category;
  final bool isNeu;
  final double size;

  const ProductThumb({
    super.key,
    this.imageUrl,
    this.category,
    required this.isNeu,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.29);
    final fallback = Icon(ProductUi.categoryIcon(category),
        size: size * 0.46,
        color: isNeu ? AppColors.textSecondaryNeu : ProductUi.accentFg(category));
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isNeu ? AppColors.bgNeu : ProductUi.accentBg(category),
        borderRadius: radius,
        boxShadow: isNeu
            ? const [
                BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 6, offset: Offset(3, 3), spreadRadius: -2),
                BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 6, offset: Offset(-3, -3), spreadRadius: -2),
              ]
            : null,
      ),
      child: imageUrl == null || imageUrl!.isEmpty
          ? fallback
          : Image.network(imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
              loadingBuilder: (_, child, progress) => progress == null ? child : fallback),
    );
  }
}

/// Small rounded label, e.g. "12 in stock" or "Inactive".
class ProductPill extends StatelessWidget {
  final String label;
  final Color color;
  const ProductPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Stock pill for a catalog row: "12 in stock", "Low · 3", "Out of stock",
/// or nothing when the product isn't tracked at the branch.
class StockPill extends StatelessWidget {
  final int? quantity;
  final StockStatus? status;
  const StockPill({super.key, this.quantity, this.status});

  @override
  Widget build(BuildContext context) {
    if (quantity == null) return const SizedBox.shrink();
    final label = switch (status) {
      StockStatus.outOfStock => 'Out of stock',
      StockStatus.lowStock => 'Low · $quantity left',
      _ => '$quantity in stock',
    };
    return ProductPill(label: label, color: ProductUi.stockColor(status));
  }
}
