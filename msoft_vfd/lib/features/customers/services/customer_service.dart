import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/page_response.dart';
import '../models/customer.dart';

/// Client for CSP's mobile customer API (/api/v1/mobile/customers).
class CustomerService {
  CustomerService._();
  static final CustomerService instance = CustomerService._();

  static const _base = '/api/v1/mobile/customers';

  final _dio = ApiClient.instance.dio;

  /// [query] matches name, phone, email, VRN or ID number.
  Future<PageResponse<CustomerItem>> list({
    String? query,
    CustomerStatus? status,
    int page = 0,
    int size = 30,
    String sort = 'customerName,asc',
  }) =>
      _call(
          () => _dio.get(_base, queryParameters: {
                if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
                'status': ?status?.cspName,
                'page': page,
                'size': size,
                'sort': sort,
              }),
          (d) => PageResponse.fromJson(d as Map<String, dynamic>, CustomerItem.fromJson));

  Future<CustomerSummary> summary() => _call(
      () => _dio.get('$_base/summary'), (d) => CustomerSummary.fromJson(d as Map<String, dynamic>));

  Future<CustomerFormOptions> formOptions() => _call(
      () => _dio.get('$_base/form-options'), (d) => CustomerFormOptions.fromJson(d as Map<String, dynamic>));

  Future<CustomerDetail> getById(String id) => _detail(() => _dio.get('$_base/$id'));

  Future<CustomerDetail> create(CustomerInput input) => _detail(() => _dio.post(_base, data: input.toJson()));

  Future<CustomerDetail> update(String id, CustomerInput input) =>
      _detail(() => _dio.put('$_base/$id', data: input.toJson()));

  Future<CustomerDetail> setStatus(String id, CustomerStatus status) => _detail(
      () => _dio.patch('$_base/$id/status', queryParameters: {'status': status.cspName}));

  Future<void> delete(String id) => _call(() => _dio.delete('$_base/$id'), (_) {});

  Future<CustomerDetail> _detail(Future<Response<dynamic>> Function() request) =>
      _call(request, (d) => CustomerDetail.fromJson(d as Map<String, dynamic>));

  Future<T> _call<T>(Future<Response<dynamic>> Function() request, T Function(dynamic) parse) async {
    try {
      final response = await request();
      return parse(response.data);
    } on DioException catch (e) {
      throw e.toApiException();
    }
  }
}
