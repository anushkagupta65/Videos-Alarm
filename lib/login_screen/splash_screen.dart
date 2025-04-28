import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:videos_alarm_app/Controller/Sub_controller.dart';
import 'package:videos_alarm_app/app_store/secure_store.dart';
import 'package:videos_alarm_app/components/app_style.dart';
import 'package:videos_alarm_app/components/constant.dart';
import 'package:videos_alarm_app/login_screen/login_screen.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';
import 'package:videos_alarm_app/screens/banner_video_list.dart';
import 'package:videos_alarm_app/screens/check_subs_controller.dart';

class SplashScreen extends StatefulWidget {
  static String tag = '/SplashScreen';

  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  final VideoController videoController = Get.put(VideoController());
  final SubscriptionController subscriptionController =
      Get.find<SubscriptionController>();

  void navigationToDashboard() {
    Future.delayed(
      
      const Duration(seconds: 2), () async {
      User? currentUser = FirebaseAuth.instance.currentUser;
      SubscriptionService().checkSubscriptionStatus();

      videoController.checkUserActiveStatus();

      if (currentUser == null) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => LogInScreen()));
      } else {
        SubscriptionService().checkSubscriptionStatus();

        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => BottomBarTabs()));
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
      backgroundColor: darkColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 300,
              height: 300,
              child: Image.asset(darkAppLogo),
            ),
            const SizedBox(height: 20), // Spacing between logo and text
            Text(
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