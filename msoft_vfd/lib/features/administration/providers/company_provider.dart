import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../models/company.dart';
import '../models/company_tax_config.dart';
import '../models/license.dart';
import '../models/service_package.dart';
import '../models/tax_type.dart';
import '../services/company_service.dart';
import '../services/license_service.dart';
import '../services/package_service.dart';
import '../services/tax_config_service.dart';

class CompanyProvider extends ChangeNotifier {
  final String companyId;
  CompanyProvider({required this.companyId});

  Company? company;
  ServicePackage? package;
  List<License> licenses = [];
  List<CompanyTaxConfig> taxConfigs = [];
  List<TaxType> taxTypes = [];
  bool loading = false;
  ApiException? error;

  /// The license to show as "current": prefer ACTIVE, then SUSPENDED (still
  /// meaningfully "in force"), otherwise the most recently created one so
  /// there's still something to show (e.g. expired, awaiting renewal).
  License? get currentLicense {
    if (licenses.isEmpty) return null;
    final sorted = [...licenses]..sort((a, b) {
      final ac = a.createdAt;
      final bc = b.createdAt;
      if (ac == null || bc == null) return 0;
      return bc.compareTo(ac);
    });
    return sorted.firstWhere(
      (l) => l.status == LicenseStatus.active,
      orElse: () => sorted.firstWhere(
        (l) => l.status == LicenseStatus.suspended,
        orElse: () => sorted.first,
      ),
    );
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        CompanyService.instance.getById(companyId),
        TaxConfigService.instance.listByCompany(companyId),
        TaxConfigService.instance.listTaxTypes(),
      ]);
      company = results[0] as Company;
      taxConfigs = results[1] as List<CompanyTaxConfig>;
      taxTypes = results[2] as List<TaxType>;

      // Package and license details live at separate endpoints — package is
      // keyed off the id CSP embeds in the company's packageDto, licenses
      // are looked up by companyId directly. Both are optional: a user
      // without PACKAGE_VIEW/LICENSE_VIEW simply won't see those cards. Catch
      // broadly (not just ApiException) so an unexpected response shape
      // can't silently swallow real data via an uncaught parsing error.
      final packageId = company?.packageId;
      if (packageId != null) {
        try {
          package = await PackageService.instance.getById(packageId);
        } catch (e) {
          debugPrint('CompanyProvider: package fetch failed: $e');
          package = null;
        }
      }
      try {
        licenses = await LicenseService.instance.listByCompany(companyId);
      } catch (e) {
        debugPrint('CompanyProvider: license fetch failed: $e');
        licenses = [];
      }
    } on ApiException catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> addTaxConfig(String taxTypeId) async {
    try {
      await TaxConfigService.instance.create(
        CompanyTaxConfigInput(companyId: companyId, taxTypeId: taxTypeId),
      );
      taxConfigs = await TaxConfigService.instance.listByCompany(companyId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeTaxConfig(String id) async {
    try {
      await TaxConfigService.instance.delete(id);
      taxConfigs = await TaxConfigService.instance.listByCompany(companyId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e;
      notifyListeners();
      return false;
    }
  }
}
