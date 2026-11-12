import '../../../core/network/api_client.dart';
import '../models/session.dart';
import 'session_manager.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Future<Session> login(String phone, String password) async {
    final response = await ApiClient.instance.dio.post(
      '/api/v1/auth/login',
      data: {'phone': phone, 'password': password},
    );
    final session = Session.fromJson(response.data as Map<String, dynamic>);
    await SessionManager.instance.save(session);
    return session;
  }

  Future<void> logout() => SessionManager.instance.clear();
}
