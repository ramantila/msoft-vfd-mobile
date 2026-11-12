import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/license.dart';

/// Read-only: license lifecycle (renew/suspend/cancel/payment) is a billing
/// operation owned by ADP, not this app.
class LicenseService {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  final _dio = ApiClient.instance.dio;

  Future<List<License>> listByCompany(String companyId) async {
    try {
      final response = await _dio.get('/api/v1/licenses', queryParameters: {
        'companyId': companyId,
      });
      return (response.data as List)
          .map((e) => License.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw e.toApiException();
    }
  }
}
