import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPref {
  static late SharedPreferences _prefs;

  static Future<bool> initSessionManager() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      Get.put(_prefs);
      return true;
    } catch (e) {
      print('❌ SharedPreferences initialization error: $e');
      return false;
    }
  }

  static void setUniqueToken() {
    _prefs.setString("unique_token", "unique_token_is_not_empty");
  }

  static String getUniqueToken() {
    return _prefs.getString("unique_token") ?? "";
  }

  static void removeUniqueToken() {
    _prefs.remove("unique_token");
  }

  static Future<bool?> getFirstTimeNotificationRequest() async {
    return _prefs.getBool('firstTimeNotificationRequest');
  }

  static Future<void> setFirstTimeNotificationRequest(bool value) async {
    await _prefs.setBool('firstTimeNotificationRequest', value);
  }

  // Generic method to set a boolean value
  static Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  // Generic method to get a boolean value
  static Future<bool?> getBool(String key) async {
    return _prefs.getBool(key);
  }

  // Specific method to set isAndroidTV flag
  static Future<void> setIsAndroidTV(bool value) async {
    await setBool('isAndroidTV', value);
  }

  // Specific method to get isAndroidTV flag
  static Future<bool> getIsAndroidTV() async {
    return await getBool('isAndroidTV') ?? false;
  }

  // Specific method to set isAndroidPhone flag
  static Future<void> setIsAndroidPhone(bool value) async {
    await setBool('isAndroidPhone', value);
  }

  // Specific method to get isAndroidPhone flag
  static Future<bool> getIsAndroidPhone() async {
    return await getBool('isAndroidPhone') ?? false;
  }
}
