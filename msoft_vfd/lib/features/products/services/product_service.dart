import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/page_response.dart';
import '../models/product.dart';

/// Stock filters supported by the mobile catalog list.
enum StockFilter { tracked, untracked, low, out, attention }

/// Client for CSP's mobile product API (/api/v1/mobile/products).
class ProductService {
  ProductService._();
  static final ProductService instance = ProductService._();

  static const _base = '/api/v1/mobile/products';

  final _dio = ApiClient.instance.dio;

  /// Fetches the company's catalog in one large page (core products API),
  /// used by the new-sale picker.
  Future<List<Product>> listByCompany(String companyId) async {
    try {
      final response = await _dio.get('/api/v1/products', queryParameters: {
        'companyId': companyId,
        'size': 500,
      });
      return PageResponse.fromJson(
        response.data as Map<String, dynamic>,
        Product.fromJson,
      ).content;
    } on DioException catch (e) {
      throw e.toApiException();
    }
  }

  /// Paged catalog with stock at [branchId] (default: the user's branch).
  Future<PageResponse<ProductItem>> catalog({
    String? query,
    String? categoryId,
    ProductStatus? status,
    StockFilter? stock,
    String? branchId,
    int page = 0,
    int size = 30,
    String sort = 'productName,asc',
  }) =>
      _call(() => _dio.get(_base, queryParameters: {
            if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
            'categoryId': ?categoryId,
            'status': ?status?.cspName,
            'stock': ?stock?.name.toUpperCase(),
            'branchId': ?branchId,
            'page': page,
            'size': size,
            'sort': sort,
          }), (d) => PageResponse.fromJson(d as Map<String, dynamic>, ProductItem.fromJson));

  Future<ProductSummary> summary({String? branchId}) => _call(
      () => _dio.get('$_base/summary', queryParameters: {'branchId': ?branchId}),
      (d) => ProductSummary.fromJson(d as Map<String, dynamic>));

  Future<ProductFormOptions> formOptions() => _call(
      () => _dio.get('$_base/form-options'),
      (d) => ProductFormOptions.fromJson(d as Map<String, dynamic>));

  Future<ProductDetail> getById(String id) => _detail(() => _dio.get('$_base/$id'));

  Future<ProductDetail> create(ProductInput input) =>
      _detail(() => _dio.post(_base, data: input.toJson()));

  Future<ProductDetail> update(String id, ProductInput input) =>
      _detail(() => _dio.put('$_base/$id', data: input.toJson()));

  Future<ProductDetail> setStatus(String id, ProductStatus status) => _detail(
      () => _dio.patch('$_base/$id/status', queryParameters: {'status': status.cspName}));

  Future<void> delete(String id) => _call(() => _dio.delete('$_base/$id'), (_) {});

  Future<ProductDetail> adjustStock(
    String id, {
    required StockAdjustment type,
    required int quantity,
    int? reorderLevel,
    String? branchId,
  }) =>
      _detail(() => _dio.post('$_base/$id/stock', data: {
            'type': type.cspName,
            'quantity': quantity,
            'reorderLevel': ?reorderLevel,
            'branchId': ?branchId,
          }));

  /// Uploads or replaces the product photo (JPEG, PNG or WebP, up to 5 MB).
  Future<ProductDetail> uploadImage(String id, String filePath) {
    final lower = filePath.toLowerCase();
    final subtype = lower.endsWith('.png') ? 'png' : lower.endsWith('.webp') ? 'webp' : 'jpeg';
    return _detail(() async => _dio.post(
          '$_base/$id/image',
          data: FormData.fromMap({
            'file': await MultipartFile.fromFile(filePath,
                filename: 'product.${subtype == 'jpeg' ? 'jpg' : subtype}',
                contentType: DioMediaType('image', subtype)),
          }),
        ));
  }

  /// The portal's bulk Activate / Inactivate / Discontinue. Returns the server's message.
  Future<String> bulkStatus(List<String> ids, ProductStatus status) => _call(
      () => _dio.post('$_base/bulk-status', data: {'ids': ids, 'status': status.cspName}),
      (d) => (d as Map<String, dynamic>)['message'] as String? ?? 'Done');

  /// The portal's Bulk Upload: an .xlsx with the template's columns.
  Future<String> bulkCreate(List<int> bytes, String fileName) => _call(
      () => _dio.post('$_base/bulk-create',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(bytes,
                filename: fileName,
                contentType: DioMediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet')),
          })),
      (d) => (d as Map<String, dynamic>)['message'] as String? ?? 'Products created');

  Future<ProductDetail> deleteImage(String id) => _detail(() => _dio.delete('$_base/$id/image'));

  Future<ProductDetail> _detail(Future<Response<dynamic>> Function() request) =>
      _call(request, (d) => ProductDetail.fromJson(d as Map<String, dynamic>));

  Future<T> _call<T>(Future<Response<dynamic>> Function() request, T Function(dynamic) parse) async {
    try {
      final response = await request();
      return parse(response.data);
    } on DioException catch (e) {
      throw e.toApiException();
    }
  }
}
