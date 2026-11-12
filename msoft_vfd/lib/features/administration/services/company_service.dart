import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/company.dart';

/// Read-only by design: company info is owned by the Admin Portal (ADP), not
/// CSP or this app — do not add an update/create/delete method here.
class CompanyService {
  CompanyService._();
  static final CompanyService instance = CompanyService._();

  final _dio = ApiClient.instance.dio;

  Future<Company> getById(String id) async {
    try {
      final response = await _dio.get('/api/v1/companies/$id');
      return Company.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.toApiException();
    }
  }
}
