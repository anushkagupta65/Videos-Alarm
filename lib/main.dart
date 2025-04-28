import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:videos_alarm_app/Controller/Sub_controller.dart';
import 'package:videos_alarm_app/login_screen/splash_screen.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';
import 'package:videos_alarm_app/screens/live_videos.dart';
import 'package:videos_alarm_app/screens/view_video.dart';
import 'app_store/app_pref.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await AppPref.initSessionManager();
    Get.put(SubscriptionController());
    Get.put(LiveVideosController());
    Get.put(VideoController());
    await _initDynamicLinks();
    runApp(const MyApp());
  } catch (e) {
    debugPrint('Initialization error: $e');
  }
}

Future<void> _initDynamicLinks() async {
  try {
    // Handle initial link (cold start)
    final PendingDynamicLinkData? initialLink =
        await FirebaseDynamicLinks.instance.getInitialLink();
    if (initialLink != null) {
      _handleDeepLink(initialLink.link);
    }

    // Handle foreground links using onLink (deprecated but still supported)
    FirebaseDynamicLinks.instance.onLink.listen(
        (PendingDynamicLinkData dynamicLinkData) {
      _handleDeepLink(dynamicLinkData.link);
    }, onError: (Object error) {
      debugPrint('Error handling dynamic link: $error');
    }, onDone: () {
      debugPrint('Link stream closed');
    });
  } catch (e) {
    debugPrint('Error initializing dynamic links: $e');
  }
}

void _handleDeepLink(Uri? deepLink) {
  if (deepLink != null) {
    debugPrint('Received deep link: $deepLink');

    // Validate the deep link domain
    if (deepLink.host != 'https://www.videosalarmsapp.com/') {
      debugPrint('Invalid Dynamic Link domain: ${deepLink.host}');
      return;
    }

    // Extract query parameters
    final videoId = deepLink.queryParameters['videoId'];

    if (videoId != null) {
      debugPrint('Navigating to video with videoId: $videoId');
      // Navigate after the UI is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.toNamed('/view_video', arguments: {
          'videoId': videoId,
        });
      });
    } else {
      debugPrint('Missing videoId or invitedBy in deep link');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      theme: ThemeData(
        textTheme: GoogleFonts.aBeeZeeTextTheme().copyWith(
          bodyMedium: GoogleFonts.aBeeZee(textStyle: const TextStyle()),
        ),
      ),
      debugShowCheckedModeBanner: false,
      title: "VideosAlarm",
      home: const SplashScreen(),
      getPages: [
        GetPage(
          name: '/view_video',
          page: () => const ViewVideo(), // Ensure ViewVideo accepts arguments
        ),
      ],
    );
  }
}
