import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPref{
  static Future<bool> initSessionManager() async {
    var prefs = await SharedPreferences.getInstance();
    Get.put(prefs);
    return true;
  }

  static setUniqueToken() {SharedPreferences pref = Get.find();pref.setString("unique_token", "unique_token_is_not_empty");}
  static String getUniqueToken() {SharedPreferences pref = Get.find();return pref.getString("unique_token") ?? "";}

  // remove Token
  static removeUniqueToken() {SharedPreferences pref = Get.find();pref.remove("unique_token");}
}