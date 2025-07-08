// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class AppPref{
//   static Future<bool> initSessionManager() async {
//     var prefs = await SharedPreferences.getInstance();
//     Get.put(prefs);
//     return true;
//   }

//   static setUniqueToken() {SharedPreferences pref = Get.find();pref.setString("unique_token", "unique_token_is_not_empty");}
//   static String getUniqueToken() {SharedPreferences pref = Get.find();return pref.getString("unique_token") ?? "";}

//   // remove Token
//   static removeUniqueToken() {SharedPreferences pref = Get.find();pref.remove("unique_token");}
// }

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
}
