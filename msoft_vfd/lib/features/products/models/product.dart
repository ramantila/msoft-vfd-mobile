enum ProductStatus { active, inactive, discontinued }

extension ProductStatusX on ProductStatus {
  static ProductStatus parse(String? value) => ProductStatus.values.firstWhere(
        (s) => s.name.toUpperCase() == value?.toUpperCase(),
        orElse: () => ProductStatus.active,
      );

  String get cspName => name.toUpperCase();

  String get label => switch (this) {
        ProductStatus.active => 'Active',
        ProductStatus.inactive => 'Inactive',
        ProductStatus.discontinued => 'Discontinued',
      };
}

enum StockStatus { inStock, lowStock, outOfStock }

extension StockStatusX on StockStatus {
  static StockStatus? parse(String? value) => switch (value?.toUpperCase()) {
        'IN_STOCK' => StockStatus.inStock,
        'LOW_STOCK' => StockStatus.lowStock,
        'OUT_OF_STOCK' => StockStatus.outOfStock,
        _ => null,
      };

  String get label => switch (this) {
        StockStatus.inStock => 'In stock',
        StockStatus.lowStock => 'Low stock',
        StockStatus.outOfStock => 'Out of stock',
      };
}

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int? _i(Object? v) => (v as num?)?.toInt();
String? _s(Object? v) => v?.toString();

/// Mirrors CSP's ProductResponse.
class Product {
  final String id;
  final String companyId;
  final String productName;
  final String? categoryId;
  final String? categoryName;
  final double price;
  final String? vatId;
  final String? vatCode;
  final String? vatName;
  final String? uomId;
  final String? uomCode;
  final String? uomName;
  final String? description;
  final String? imageUrl;
  final ProductStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Product({
    required this.id,
    required this.companyId,
    required this.productName,
    this.categoryId,
    this.categoryName,
    required this.price,
    this.vatId,
    this.vatCode,
    this.vatName,
    this.uomId,
    this.uomCode,
    this.uomName,
    this.description,
    this.imageUrl,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'].toString(),
        companyId: json['companyId']?.toString() ?? '',
        productName: json['productName'] as String? ?? '',
        categoryId: _s(json['categoryId']),
        categoryName: json['categoryName'] as String?,
        price: _d(json['price']),
        vatId: _s(json['vatId']),
        vatCode: json['vatCode'] as String?,
        vatName: json['vatName'] as String?,
        uomId: _s(json['uomId']),
        uomCode: json['uomCode'] as String?,
        uomName: json['uomName'] as String?,
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
        status: ProductStatusX.parse(json['status'] as String?),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal(),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toLocal(),
      );
}

/// A catalog row from /api/v1/mobile/products. Stock fields are for one
/// branch (the user's by default) and are null when the product isn't
/// stock-tracked there.
class ProductItem {
  final String id;
  final String productName;
  final String? categoryId;
  final String? categoryName;
  final double price;
  final String? vatCode;
  final String? vatName;
  final int? vatPercent;
  final String? uomCode;
  final String? imageUrl;
  final ProductStatus status;
  final int? quantityOnHand;
  final int? reorderLevel;
  final StockStatus? stockStatus;
  final DateTime? createdAt;

  const ProductItem({
    required this.id,
    required this.productName,
    this.categoryId,
    this.categoryName,
    required this.price,
    this.vatCode,
    this.vatName,
    this.vatPercent,
    this.uomCode,
    this.imageUrl,
    required this.status,
    this.quantityOnHand,
    this.reorderLevel,
    this.stockStatus,
    this.createdAt,
  });

  bool get tracked => quantityOnHand != null;

  factory ProductItem.fromJson(Map<String, dynamic> json) => ProductItem(
        id: json['id'].toString(),
        productName: json['productName'] as String? ?? '',
        categoryId: _s(json['categoryId']),
        categoryName: json['categoryName'] as String?,
        price: _d(json['price']),
        vatCode: json['vatCode'] as String?,
        vatName: json['vatName'] as String?,
        vatPercent: _i(json['vatPercent']),
        uomCode: json['uomCode'] as String?,
        imageUrl: json['imageUrl'] as String?,
        status: ProductStatusX.parse(json['status'] as String?),
        quantityOnHand: _i(json['quantityOnHand']),
        reorderLevel: _i(json['reorderLevel']),
        stockStatus: StockStatusX.parse(json['stockStatus'] as String?),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal(),
      );
}

class BranchStock {
  final String stockId;
  final String branchId;
  final String branchName;
  final int quantityOnHand;
  final int reorderLevel;
  final StockStatus status;
  final DateTime? lastRestock;

  const BranchStock({
    required this.stockId,
    required this.branchId,
    required this.branchName,
    required this.quantityOnHand,
    required this.reorderLevel,
    required this.status,
    this.lastRestock,
  });

  factory BranchStock.fromJson(Map<String, dynamic> json) => BranchStock(
        stockId: json['stockId'].toString(),
        branchId: json['branchId'].toString(),
        branchName: json['branchName'] as String? ?? 'Branch',
        quantityOnHand: _i(json['quantityOnHand']) ?? 0,
        reorderLevel: _i(json['reorderLevel']) ?? 0,
        status: StockStatusX.parse(json['stockStatus'] as String? ?? json['status'] as String?) ??
            StockStatus.inStock,
        lastRestock: DateTime.tryParse(json['lastRestock']?.toString() ?? '')?.toLocal(),
      );
}

/// Product detail: product, stock per branch, last-30-day sales.
class ProductDetail {
  final Product product;
  final int? vatPercent;
  final bool stockTrackingEnabled;
  final int totalOnHand;
  final List<BranchStock> stocks;
  final double soldQuantity30d;
  final double revenue30d;

  const ProductDetail({
    required this.product,
    this.vatPercent,
    required this.stockTrackingEnabled,
    required this.totalOnHand,
    required this.stocks,
    required this.soldQuantity30d,
    required this.revenue30d,
  });

  BranchStock? stockAt(String? branchId) {
    if (branchId == null) return null;
    for (final s in stocks) {
      if (s.branchId == branchId) return s;
    }
    return null;
  }

  factory ProductDetail.fromJson(Map<String, dynamic> json) => ProductDetail(
        product: Product.fromJson(json['product'] as Map<String, dynamic>),
        vatPercent: _i(json['vatPercent']),
        stockTrackingEnabled: json['stockTrackingEnabled'] as bool? ?? false,
        totalOnHand: _i(json['totalOnHand']) ?? 0,
        stocks: (json['stocks'] as List<dynamic>? ?? const [])
            .map((e) => BranchStock.fromJson(e as Map<String, dynamic>))
            .toList(),
        soldQuantity30d: _d(json['soldQuantity30d']),
        revenue30d: _d(json['revenue30d']),
      );
}

class ProductSummary {
  final int total;
  final int active;
  final int inactive;
  final int discontinued;
  final String? branchId;
  final int tracked;
  final int lowStock;
  final int outOfStock;

  const ProductSummary({
    required this.total,
    required this.active,
    required this.inactive,
    required this.discontinued,
    this.branchId,
    required this.tracked,
    required this.lowStock,
    required this.outOfStock,
  });

  factory ProductSummary.fromJson(Map<String, dynamic> json) => ProductSummary(
        total: _i(json['total']) ?? 0,
        active: _i(json['active']) ?? 0,
        inactive: _i(json['inactive']) ?? 0,
        discontinued: _i(json['discontinued']) ?? 0,
        branchId: _s(json['branchId']),
        tracked: _i(json['tracked']) ?? 0,
        lowStock: _i(json['lowStock']) ?? 0,
        outOfStock: _i(json['outOfStock']) ?? 0,
      );
}

class FormOption {
  final String id;
  final String label;
  final String? detail;
  final int? percent;
  const FormOption({required this.id, required this.label, this.detail, this.percent});
}

/// Choices for the add/edit product form.
class ProductFormOptions {
  final List<FormOption> categories;
  final List<FormOption> units;
  final List<FormOption> taxTypes;
  final bool stockTrackingEnabled;
  final String? defaultBranchId;
  final String? defaultBranchName;

  /// The company's 18% tax type, preselected like on the web portal.
  final String? defaultTaxId;

  const ProductFormOptions({
    required this.categories,
    required this.units,
    required this.taxTypes,
    required this.stockTrackingEnabled,
    this.defaultBranchId,
    this.defaultBranchName,
    this.defaultTaxId,
  });

  static List<FormOption> _list(Object? v, FormOption Function(Map<String, dynamic>) f) =>
      (v as List<dynamic>? ?? const []).map((e) => f(e as Map<String, dynamic>)).toList();

  factory ProductFormOptions.fromJson(Map<String, dynamic> json) => ProductFormOptions(
        categories: _list(json['categories'], (c) => FormOption(
              id: c['id'].toString(),
              label: c['name'] as String? ?? '',
              detail: (c['shared'] as bool? ?? false) ? 'Default' : null,
            )),
        units: _list(json['units'], (u) => FormOption(
              id: u['id'].toString(),
              label: u['code'] as String? ?? '',
              detail: u['name'] as String?,
            )),
        taxTypes: _list(json['taxTypes'], (t) => FormOption(
              id: t['id'].toString(),
              label: t['name'] as String? ?? t['code'] as String? ?? '',
              detail: t['code'] as String?,
              percent: _i(t['percent']),
            )),
        stockTrackingEnabled: json['stockTrackingEnabled'] as bool? ?? false,
        defaultBranchId: _s(json['defaultBranchId']),
        defaultBranchName: json['defaultBranchName'] as String?,
        defaultTaxId: _s(json['defaultTaxId']),
      );
}

/// Body for create / update.
class ProductInput {
  final String productName;
  final String categoryId;
  final double price;
  final String? vatId;
  final String uomId;
  final String? description;
  final ProductStatus? status;
  final int? openingStock;
  final int? reorderLevel;
  final String? branchId;

  const ProductInput({
    required this.productName,
    required this.categoryId,
    required this.price,
    this.vatId,
    required this.uomId,
    this.description,
    this.status,
    this.openingStock,
    this.reorderLevel,
    this.branchId,
  });

  Map<String, dynamic> toJson() => {
        'productName': productName,
        'categoryId': categoryId,
        'price': price,
        'vatId': ?vatId,
        'uomId': uomId,
        'description': ?description,
        'status': ?status?.cspName,
        'openingStock': ?openingStock,
        'reorderLevel': ?reorderLevel,
        'branchId': ?branchId,
      };
}

enum StockAdjustment { add, remove, set }

extension StockAdjustmentX on StockAdjustment {
  String get cspName => name.toUpperCase();

  String get label => switch (this) {
        StockAdjustment.add => 'Receive',
        StockAdjustment.remove => 'Remove',
        StockAdjustment.set => 'Count',
      };

  String get hint => switch (this) {
        StockAdjustment.add => 'Units received',
        StockAdjustment.remove => 'Units damaged, lost or returned',
        StockAdjustment.set => 'Units counted on the shelf',
      };
}
