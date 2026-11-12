import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/page_response.dart';
import '../../auth/services/session_manager.dart';
import '../../auth/utils/auth_state.dart';
import '../models/staff.dart';

/// Client for CSP's mobile users API (/api/v1/mobile/users).
class StaffService {
  StaffService._();
  static final StaffService instance = StaffService._();

  static const _base = '/api/v1/mobile/users';

  final _dio = ApiClient.instance.dio;

  // ---- me ----

  Future<StaffDetail> me() => _detail(() => _dio.get('$_base/me'));

  /// Saves my name and refreshes the stored session so the app shows it.
  Future<StaffDetail> updateMe({required String firstName, String? middleName, required String lastName}) async {
    final d = await _detail(() => _dio.put('$_base/me', data: {
          'firstName': firstName,
          'middleName': ?middleName,
          'lastName': lastName,
        }));
    final s = AuthState.session;
    if (s != null) {
      await _apply(Session.fromJson({...s.toJson(), 'firstName': d.user.firstName, 'lastName': d.user.lastName}));
    }
    return d;
  }

  /// Changes my password. The server signs out every session and returns a
  /// new one, which is stored here so this device stays signed in.
  Future<void> changeMyPassword(String currentPassword, String newPassword) async {
    final session = await _call(
        () => _dio.post('$_base/me/password', data: {
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
        (d) => Session.fromJson(d as Map<String, dynamic>));
    await _apply(session);
  }

  Future<void> _apply(Session s) async {
    await SessionManager.instance.save(s);
    AuthState.applySession(s);
  }

  // ---- staff ----

  Future<PageResponse<StaffItem>> list({
    String? query,
    UserRole? role,
    StaffStatus? status,
    int page = 0,
    int size = 30,
  }) =>
      _call(
          () => _dio.get(_base, queryParameters: {
                if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
                'role': ?role?.cspName,
                'status': ?status?.cspName,
                'page': page,
                'size': size,
                'sort': 'firstName,asc',
              }),
          (d) => PageResponse.fromJson(d as Map<String, dynamic>, StaffItem.fromJson));

  Future<StaffSummary> summary() =>
      _call(() => _dio.get('$_base/summary'), (d) => StaffSummary.fromJson(d as Map<String, dynamic>));

  Future<StaffFormOptions> formOptions() =>
      _call(() => _dio.get('$_base/form-options'), (d) => StaffFormOptions.fromJson(d as Map<String, dynamic>));

  Future<StaffDetail> getById(String id) => _detail(() => _dio.get('$_base/$id'));

  Future<StaffDetail> create(StaffInput input) => _detail(() => _dio.post(_base, data: input.toJson()));

  Future<StaffDetail> update(String id, StaffInput input) =>
      _detail(() => _dio.put('$_base/$id', data: input.toJson()));

  Future<StaffDetail> setStatus(String id, StaffStatus status) =>
      _detail(() => _dio.patch('$_base/$id/status', queryParameters: {'status': status.cspName}));

  Future<void> resetPassword(String id, String newPassword) =>
      _call(() => _dio.post('$_base/$id/reset-password', data: {'newPassword': newPassword}), (_) {});

  Future<void> delete(String id) => _call(() => _dio.delete('$_base/$id'), (_) {});

  Future<StaffDetail> _detail(Future<Response<dynamic>> Function() request) =>
      _call(request, (d) => StaffDetail.fromJson(d as Map<String, dynamic>));

  Future<T> _call<T>(Future<Response<dynamic>> Function() request, T Function(dynamic) parse) async {
    try {
      final response = await request();
      return parse(response.data);
    } on DioException catch (e) {
      throw e.toApiException();
    }
  }
}
