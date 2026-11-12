import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/service_package.dart';

/// Read-only: package definitions are managed via ADP, not this app.
class PackageService {
  PackageService._();
  static final PackageService instance = PackageService._();

  final _dio = ApiClient.instance.dio;

  Future<ServicePackage> getById(String id) async {
    try {
      final response = await _dio.get('/api/v1/packages/$id');
      return ServicePackage.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.toApiException();
    }
  }
}
