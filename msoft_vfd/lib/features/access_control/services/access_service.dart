import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/access_models.dart';

/// Client for /api/v1/mobile/access-control.
class AccessService {
  AccessService._();
  static final AccessService instance = AccessService._();

  static const _base = '/api/v1/mobile/access-control';
  final _dio = ApiClient.instance.dio;

  Future<List<RoleItem>> roles({String? query}) => _call(
      () => _dio.get('$_base/roles', queryParameters: {
            if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          }),
      (d) => (d as List<dynamic>).map((e) => RoleItem.fromJson(e as Map<String, dynamic>)).toList());

  Future<RoleDetail> role(String id) => _detail(() => _dio.get('$_base/roles/$id'));

  Future<RoleDetail> saveRole({
    String? id,
    required String name,
    String? description,
    required Set<String> permissionIds,
    required bool active,
  }) {
    final body = {
      'name': name,
      'description': ?description,
      'permissionIds': permissionIds.toList(),
      'active': active,
    };
    return _detail(() => id == null ? _dio.post('$_base/roles', data: body) : _dio.put('$_base/roles/$id', data: body));
  }

  Future<RoleDetail> setActive(String id, bool active) =>
      _detail(() => _dio.patch('$_base/roles/$id/status', queryParameters: {'active': active}));

  Future<void> deleteRole(String id) => _call(() => _dio.delete('$_base/roles/$id'), (_) {});

  Future<PermissionOptions> permissionOptions() => _call(
      () => _dio.get('$_base/permission-options'), (d) => PermissionOptions.fromJson(d as Map<String, dynamic>));

  Future<List<PermissionGroup>> catalog({String? query}) => _call(
      () => _dio.get('$_base/permissions', queryParameters: {
            if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          }),
      PermissionGroup.listFrom);

  Future<RoleDetail> _detail(Future<Response<dynamic>> Function() r) =>
      _call(r, (d) => RoleDetail.fromJson(d as Map<String, dynamic>));

  Future<T> _call<T>(Future<Response<dynamic>> Function() request, T Function(dynamic) parse) async {
    try {
      final response = await request();
      return parse(response.data);
    } on DioException catch (e) {
      throw e.toApiException();
    }
  }
}
