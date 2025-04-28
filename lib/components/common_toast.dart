import 'package:fluttertoast/fluttertoast.dart';
import 'package:videos_alarm_app/components/app_style.dart';

commToast(String message) {
  Fluttertoast.showToast(
      msg: message,
      // toastLength: Toast.LENGTH_SHORT,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 4,
      backgroundColor: darkColor,
      textColor: whiteColor,
      fontSize: 16.0);
}
