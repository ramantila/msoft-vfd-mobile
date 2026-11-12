import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/page_response.dart';
import '../models/sale.dart';
import '../models/sale_list_item.dart';
import '../models/sales_summary.dart';
import '../utils/sales_format.dart';

/// Client for CSP's mobile sales API (/api/v1/mobile/sales).
class SaleService {
  SaleService._();
  static final SaleService instance = SaleService._();

  static const _base = '/api/v1/mobile/sales';

  final _dio = ApiClient.instance.dio;

  /// Creates and completes a sale in one call. Stock is deducted and, for
  /// TRA-integrated companies, the receipt is queued for fiscal submission.
  Future<Sale> checkout(CheckoutInput input) =>
      _sale(() => _dio.post('$_base/checkout', data: input.toJson()));

  /// Newest-first sales history. [from]/[to] are inclusive calendar dates.
  /// [query] matches receipt number, fiscal code or customer name.
  Future<PageResponse<SaleListItem>> history({
    DateTime? from,
    DateTime? to,
    SaleStatus? status,
    PaymentMethod? paymentMethod,
    String? branchId,
    String? customerId,
    String? userId,
    String? query,
    bool mine = false,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await _dio.get(_base, queryParameters: {
        if (from != null) 'from': SalesFormat.apiDate(from),
        if (to != null) 'to': SalesFormat.apiDate(to),
        if (status != null) 'status': status.cspName,
        if (paymentMethod != null) 'paymentMethod': paymentMethod.cspName,
        'branchId': ?branchId,
        'customerId': ?customerId,
        'userId': ?userId,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (mine) 'mine': true,
        'page': page,
        'size': size,
      });
      return PageResponse.fromJson(
          response.data as Map<String, dynamic>, SaleListItem.fromJson);
    } on DioException catch (e) {
      throw e.toApiException();
    }
  }

  Future<Sale> getById(String id) => _sale(() => _dio.get('$_base/$id'));

  /// Figures for [from]..[to] inclusive (defaults to today server-side).
  Future<SalesSummary> summary({
    DateTime? from,
    DateTime? to,
    String? branchId,
    int topProducts = 5,
  }) async {
    try {
      final response = await _dio.get('$_base/summary', queryParameters: {
        if (from != null) 'from': SalesFormat.apiDate(from),
        if (to != null) 'to': SalesFormat.apiDate(to),
        'branchId': ?branchId,
        'topProducts': topProducts,
      });
      return SalesSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.toApiException();
    }
  }

  /// Cancels a pending or completed sale (stock is restored).
  Future<Sale> cancel(String id, {String? reason}) =>
      _sale(() => _dio.post('$_base/$id/cancel', data: _reason(reason)));

  /// Refunds a completed sale (stock is restored).
  Future<Sale> refund(String id, {String? reason}) =>
      _sale(() => _dio.post('$_base/$id/refund', data: _reason(reason)));

  Map<String, dynamic> _reason(String? reason) =>
      {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()};

  Future<Sale> _sale(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      return Sale.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.toApiException();
    }
  }
}
