import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/config_models.dart';

/// Clients for /api/v1/mobile/categories and /api/v1/mobile/units.
class ConfigService {
  ConfigService._();
  static final ConfigService instance = ConfigService._();

  static const _cat = '/api/v1/mobile/categories';
  static const _uom = '/api/v1/mobile/units';

  final _dio = ApiClient.instance.dio;

  // ---- categories ----

  Future<List<CategoryItem>> categories({String? query, bool? active}) => _call(
      () => _dio.get(_cat, queryParameters: {
            if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
            'active': ?active,
          }),
      (d) => (d as List<dynamic>).map((e) => CategoryItem.fromJson(e as Map<String, dynamic>)).toList());

  Future<CategoryDetail> category(String id) => _catDetail(() => _dio.get('$_cat/$id'));

  Future<CategoryDetail> saveCategory({String? id, required String name, String? description}) {
    final body = {'categoryName': name, 'description': ?description};
    return _catDetail(() => id == null ? _dio.post(_cat, data: body) : _dio.put('$_cat/$id', data: body));
  }

  Future<CategoryDetail> setCategoryActive(String id, bool active) =>
      _catDetail(() => _dio.patch('$_cat/$id/status', queryParameters: {'active': active}));

  Future<void> deleteCategory(String id) => _call(() => _dio.delete('$_cat/$id'), (_) {});

  // ---- units ----

  Future<List<UnitItem>> units({String? query, bool? activeOnly}) => _call(
      () => _dio.get(_uom, queryParameters: {
            if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
            if (activeOnly == true) 'active': true,
          }),
      (d) => (d as List<dynamic>).map((e) => UnitItem.fromJson(e as Map<String, dynamic>)).toList());

  Future<UnitDetail> unit(String id) => _unitDetail(() => _dio.get('$_uom/$id'));

  Future<UnitDetail> saveUnit({String? id, required String code, required String name, String? description}) {
    final body = {'code': code, 'name': name, 'description': ?description};
    return _unitDetail(() => id == null ? _dio.post(_uom, data: body) : _dio.put('$_uom/$id', data: body));
  }

  Future<UnitDetail> setUnitActive(String id, bool active) =>
      _unitDetail(() => _dio.patch('$_uom/$id/status', queryParameters: {'active': active}));

  Future<void> deleteUnit(String id) => _call(() => _dio.delete('$_uom/$id'), (_) {});

  // ---- plumbing ----

  Future<CategoryDetail> _catDetail(Future<Response<dynamic>> Function() r) =>
      _call(r, (d) => CategoryDetail.fromJson(d as Map<String, dynamic>));

  Future<UnitDetail> _unitDetail(Future<Response<dynamic>> Function() r) =>
      _call(r, (d) => UnitDetail.fromJson(d as Map<String, dynamic>));

  Future<T> _call<T>(Future<Response<dynamic>> Function() request, T Function(dynamic) parse) async {
    try {
      final response = await request();
      return parse(response.data);
    } on DioException catch (e) {
      throw e.toApiException();
    }
  }
}
