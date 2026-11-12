import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/branch.dart';

/// Client for CSP's mobile branch API (/api/v1/mobile/branches).
class BranchService {
  BranchService._();
  static final BranchService instance = BranchService._();

  static const _base = '/api/v1/mobile/branches';

  final _dio = ApiClient.instance.dio;

  Future<List<BranchItem>> list({String? query}) => _call(
      () => _dio.get(_base, queryParameters: {
            if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          }),
      (d) => (d as List<dynamic>).map((e) => BranchItem.fromJson(e as Map<String, dynamic>)).toList());

  Future<BranchSummary> summary() =>
      _call(() => _dio.get('$_base/summary'), (d) => BranchSummary.fromJson(d as Map<String, dynamic>));

  Future<BranchDetail> getById(String id) => _detail(() => _dio.get('$_base/$id'));

  Future<BranchDetail> create(BranchInput input) => _detail(() => _dio.post(_base, data: input.toJson()));

  Future<BranchDetail> update(String id, BranchInput input) =>
      _detail(() => _dio.put('$_base/$id', data: input.toJson()));

  Future<void> delete(String id) => _call(() => _dio.delete('$_base/$id'), (_) {});

  Future<BranchDetail> _detail(Future<Response<dynamic>> Function() request) =>
      _call(request, (d) => BranchDetail.fromJson(d as Map<String, dynamic>));

  Future<T> _call<T>(Future<Response<dynamic>> Function() request, T Function(dynamic) parse) async {
    try {
      final response = await request();
      return parse(response.data);
    } on DioException catch (e) {
      throw e.toApiException();
    }
  }
}
