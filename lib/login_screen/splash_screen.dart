import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';
import 'package:videos_alarm_app/components/constant.dart';
import 'package:videos_alarm_app/device_guard.dart';
import 'package:videos_alarm_app/login_screen/login_screen.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';
import 'package:videos_alarm_app/screens/banner_video_list.dart';
import 'package:videos_alarm_app/tv_screens/tv_black_screen.dart';
import 'package:videos_alarm_app/tv_screens/tv_bottom_bar_tabs.dart';
import 'package:videos_alarm_app/tv_screens/tv_login.dart';

class SplashScreen extends StatefulWidget {
  static String tag = '/SplashScreen';
  const SplashScreen({super.key});
  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  void navigationToDashboard() {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final bool isTestUser = prefs.getBool('isTestUser') ?? false;
        final VideoController videoController = Get.put(VideoController());
        Future<Widget> getTargetScreen() async {
          User? currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            // Save userid to SharedPreferences
            await prefs.setString('userId', currentUser.uid);

            if (!await validateAndAddDevice(currentUser.uid, context)) {
              return const SizedBox.shrink();
            }
            final isAndroidTV = await isDeviceAndroidTV();
            if (videoController.isUserActive.value) {
              return isAndroidTV
                  ? const TVBottomBarTabs(initialIndex: 0)
                  : BottomBarTabs(initialIndex: 0);
            } else {
              return isAndroidTV
                  ? const TVBuySubscription()
                  : BottomBarTabs(initialIndex: 0);
            }
          } else if (!isTestUser) {
            final isAndroidTV = await isDeviceAndroidTV();
            return isAndroidTV ? const TVLogInScreen() : const LogInScreen();
          }
          final isAndroidTV = await isDeviceAndroidTV();
          return isAndroidTV
              ? const TVBottomBarTabs(initialIndex: 0)
              : BottomBarTabs(initialIndex: 0);
        }

        final targetScreen = await getTargetScreen();
        Get.off(() => UpgradeAlert(
              showReleaseNotes: false,
              showIgnore: false,
              showLater: false,
              upgrader: Upgrader(
                debugLogging: true,
                debugDisplayAlways: false,
                debugDisplayOnce: false,
              ),
              child: targetScreen,
            ));
      } catch (e) {
        Get.off(() => UpgradeAlert(
              showReleaseNotes: false,
              showIgnore: false,
              showLater: false,
              upgrader: Upgrader(
                debugLogging: true,
                debugDisplayAlways: false,
                debugDisplayOnce: false,
              ),
              child: const TVLogInScreen(),
            ));
      }
    });
  }

  @override
  void initState() {
    super.initState();
    navigationToDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 300,
              height: 300,
              child: Image.asset(appLogo),
            ),
            const SizedBox(height: 20),
            const Text(
              'VideosAlarm',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
