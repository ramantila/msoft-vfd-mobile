// Categories and units of measure (the web portal's "Configurations" section).

int _i(Object? v) => (v as num?)?.toInt() ?? 0;
DateTime? _t(Object? v) => DateTime.tryParse(v?.toString() ?? '')?.toLocal();

class ProductRef {
  final String id;
  final String productName;
  const ProductRef(this.id, this.productName);

  static List<ProductRef> listFrom(Object? v) => (v as List<dynamic>? ?? const [])
      .map((e) => e as Map<String, dynamic>)
      .map((p) => ProductRef(p['id'].toString(), p['productName'] as String? ?? ''))
      .toList();
}

class CategoryItem {
  final String id;
  final String categoryName;
  final String? description;
  final bool systemDefault;
  final bool active;
  final int productCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CategoryItem({
    required this.id,
    required this.categoryName,
    this.description,
    required this.systemDefault,
    required this.active,
    required this.productCount,
    this.createdAt,
    this.updatedAt,
  });

  factory CategoryItem.fromJson(Map<String, dynamic> j) => CategoryItem(
        id: j['id'].toString(),
        categoryName: j['categoryName'] as String? ?? '',
        description: j['description'] as String?,
        systemDefault: j['systemDefault'] as bool? ?? false,
        active: j['active'] as bool? ?? true,
        productCount: _i(j['productCount']),
        createdAt: _t(j['createdAt']),
        updatedAt: _t(j['updatedAt']),
      );
}

class CategoryDetail {
  final CategoryItem category;
  final List<ProductRef> products;
  final bool canEdit;
  final bool canDelete;
  final String? deleteBlocker;

  const CategoryDetail({
    required this.category,
    required this.products,
    required this.canEdit,
    required this.canDelete,
    this.deleteBlocker,
  });

  factory CategoryDetail.fromJson(Map<String, dynamic> j) => CategoryDetail(
        category: CategoryItem.fromJson(j['category'] as Map<String, dynamic>),
        products: ProductRef.listFrom(j['products']),
        canEdit: j['canEdit'] as bool? ?? false,
        canDelete: j['canDelete'] as bool? ?? false,
        deleteBlocker: j['deleteBlocker'] as String?,
      );
}

class UnitItem {
  final String id;
  final String code;
  final String name;
  final String? description;
  final bool systemDefault;
  final bool active;
  final int productCount;
  final DateTime? createdAt;

  const UnitItem({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.systemDefault,
    required this.active,
    required this.productCount,
    this.createdAt,
  });

  factory UnitItem.fromJson(Map<String, dynamic> j) => UnitItem(
        id: j['id'].toString(),
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        systemDefault: j['systemDefault'] as bool? ?? false,
        active: j['active'] as bool? ?? true,
        productCount: _i(j['productCount']),
        createdAt: _t(j['createdAt']),
      );
}

class UnitDetail {
  final UnitItem unit;
  final List<ProductRef> products;
  final bool canEdit;
  final bool canToggle;
  final bool canDelete;
  final String? lockedReason;

  const UnitDetail({
    required this.unit,
    required this.products,
    required this.canEdit,
    required this.canToggle,
    required this.canDelete,
    this.lockedReason,
  });

  factory UnitDetail.fromJson(Map<String, dynamic> j) => UnitDetail(
        unit: UnitItem.fromJson(j['unit'] as Map<String, dynamic>),
        products: ProductRef.listFrom(j['products']),
        canEdit: j['canEdit'] as bool? ?? false,
        canToggle: j['canToggle'] as bool? ?? false,
        canDelete: j['canDelete'] as bool? ?? false,
        lockedReason: j['lockedReason'] as String?,
      );
}
