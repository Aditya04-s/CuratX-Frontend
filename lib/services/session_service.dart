import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _kUserId = 'curatx_user_id';
  static const _kUserName = 'curatx_user_name';
  static const _kUserEmail = 'curatx_user_email';
  static const _kHasOnboarded = 'curatx_has_onboarded';

  static Future<void> saveSession({
    required String userId,
    required String name,
    required String email,
    required bool hasOnboarded,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, userId);
    await prefs.setString(_kUserName, name);
    await prefs.setString(_kUserEmail, email);
    await prefs.setBool(_kHasOnboarded, hasOnboarded);
  }

  static Future<void> setHasOnboarded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasOnboarded, value);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserId);
  }

  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserName) ?? 'CuratX User';
  }

  static Future<bool> getHasOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kHasOnboarded) ?? false;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kUserName);
    await prefs.remove(_kUserEmail);
    await prefs.remove(_kHasOnboarded);
  }
}