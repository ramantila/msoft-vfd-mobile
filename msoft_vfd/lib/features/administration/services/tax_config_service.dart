import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/page_response.dart';
import '../models/company_tax_config.dart';
import '../models/tax_type.dart';

class TaxConfigService {
  TaxConfigService._();
  static final TaxConfigService instance = TaxConfigService._();

  final _dio = ApiClient.instance.dio;

  Future<List<CompanyTaxConfig>> listByCompany(String companyId) async {
    try {
      final response = await _dio.get('/api/v1/company-tax-configs', queryParameters: {
        'companyId': companyId,
        'size': 100,
      });
      return PageResponse.fromJson(
        response.data as Map<String, dynamic>,
        CompanyTaxConfig.fromJson,
      ).content;
    } on DioException catch (e) {
      throw e.toApiException();
    }
  }

  Future<List<TaxType>> listTaxTypes() async {
    try {
      final response =
          await _dio.get('/api/v1/tax-types', queryParameters: {'size': 200});
      return PageResponse.fromJson(
        response.data as Map<String, dynamic>,
        TaxType.fromJson,
      ).content;
    } on DioException catch (e) {
      throw e.toApiException();
    }
  }

  Future<CompanyTaxConfig> create(CompanyTaxConfigInput input) async {
    try {
      final response =
          await _dio.post('/api/v1/company-tax-configs', data: input.toJson());
      return CompanyTaxConfig.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.toApiException();
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/api/v1/company-tax-configs/$id');
    } on DioException catch (e) {
      throw e.toApiException();
    }
  }
}
