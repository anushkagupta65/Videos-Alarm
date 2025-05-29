// import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
// // import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:get/get.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:videos_alarm_app/Controller/Sub_controller.dart';
// import 'package:videos_alarm_app/login_screen/splash_screen.dart';
// import 'package:videos_alarm_app/screens/Vid_controller.dart';
// import 'package:videos_alarm_app/screens/live_videos.dart';
// import 'package:videos_alarm_app/screens/view_video.dart';
// import 'app_store/app_pref.dart';

// // Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
// //   await Firebase.initializeApp();
// //   await NotificationService.backgroundHandler(message);
// // }

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   try {
//     print('Starting initialization');
//     await Firebase.initializeApp();
//     print('Firebase initialized');
//     // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//     // print('FCM background handler set');
//     // await NotificationService().initialize();
//     // print('NotificationService initialized');
//     await AppPref.initSessionManager();
//     print('Session manager initialized');
//     Get.put(SubscriptionController());
//     print('SubscriptionController initialized');
//     Get.put(LiveVideosController());
//     print('LiveVideosController initialized');
//     Get.put(VideoController());
//     print('VideoController initialized');
//     await _initDynamicLinks();
//     print('Dynamic Links initialized');
//     await dotenv.load(fileName: ".env");

//     // // Subscribe to FCM topics
//     // FirebaseMessaging messaging = FirebaseMessaging.instance;
//     // await messaging.subscribeToTopic('new_blogs');
//     // await messaging.subscribeToTopic('new_videos');
//     // await messaging.subscribeToTopic('new_live_videos');
//     // print('Subscribed to FCM topics: new_blogs, new_videos, new_live_videos');

//     runApp(const MyApp());
//     print('App running');
//   } catch (e) {
//     print('Initialization error: $e');
//   }
// }

// Future<void> _initDynamicLinks() async {
//   try {
//     final PendingDynamicLinkData? initialLink =
//         await FirebaseDynamicLinks.instance.getInitialLink();
//     if (initialLink != null) {
//       _handleDeepLink(initialLink.link);
//     }
//     FirebaseDynamicLinks.instance.onLink.listen(
//         (PendingDynamicLinkData dynamicLinkData) {
//       _handleDeepLink(dynamicLinkData.link);
//     }, onError: (Object error) {
//       print('Error handling dynamic link: $error');
//     }, onDone: () {
//       print('Link stream closed');
//     });
//   } catch (e) {
//     print('Error initializing dynamic links: $e');
//   }
// }

// void _handleDeepLink(Uri? deepLink) {
//   if (deepLink != null) {
//     print('Received deep link: $deepLink');
//     if (deepLink.host != 'https://www.videosalarmsapp.com/') {
//       print('Invalid Dynamic Link domain: ${deepLink.host}');
//       return;
//     }
//     final videoId = deepLink.queryParameters['videoId'];
//     if (videoId != null) {
//       print('Navigating to video with videoId: $videoId');
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         Get.toNamed('/view_video', arguments: {
//           'videoId': videoId,
//         });
//       });
//     } else {
//       print('Missing videoId in deep link');
//     }
//   }
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return GetMaterialApp(
//       theme: ThemeData(
//         textTheme: GoogleFonts.aBeeZeeTextTheme().copyWith(
//           bodyMedium: GoogleFonts.aBeeZee(textStyle: const TextStyle()),
//         ),
//       ),
//       debugShowCheckedModeBanner: false,
//       title: "VideosAlarm",
//       home: const SplashScreen(),
//       getPages: [
//         GetPage(
//           name: '/view_video',
//           page: () => const ViewVideo(),
//         ),
//       ],
//     );
//   }
// }

import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:videos_alarm_app/Controller/Sub_controller.dart';
import 'package:videos_alarm_app/login_screen/splash_screen.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';
import 'package:videos_alarm_app/screens/live_videos.dart';
import 'package:videos_alarm_app/screens/view_video.dart';
import 'app_store/app_pref.dart';

// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   await NotificationService.backgroundHandler(message);
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print('Starting initialization');
    await Firebase.initializeApp();
    print('Firebase initialized');

    // Initialize Firebase Analytics
    FirebaseAnalytics analytics = FirebaseAnalytics.instance;
    await analytics.setAnalyticsCollectionEnabled(true);
    print('Firebase Analytics initialized');

    // Log app open event
    await analytics.logAppOpen();
    print('Logged app open event');

    // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    // print('FCM background handler set');
    // await NotificationService().initialize();
    // print('NotificationService initialized');
    await AppPref.initSessionManager();
    print('Session manager initialized');
    Get.put(SubscriptionController());
    print('SubscriptionController initialized');
    Get.put(LiveVideosController());
    print('LiveVideosController initialized');
    Get.put(VideoController());
    print('VideoController initialized');
    await _initDynamicLinks(analytics);
    print('Dynamic Links initialized');
    await dotenv.load(fileName: ".env");

    // // Subscribe to FCM topics
    // FirebaseMessaging messaging = FirebaseMessaging.instance;
    // await messaging.subscribeToTopic('new_blogs');
    // await messaging.subscribeToTopic('new_videos');
    // await messaging.subscribeToTopic('new_live_videos');
    // print('Subscribed to FCM topics: new_blogs, new_videos, new_live_videos');

    runApp(const MyApp());
    print('App running');
  } catch (e) {
    print('Initialization error: $e');
  }
}

Future<void> _initDynamicLinks(FirebaseAnalytics analytics) async {
  try {
    final PendingDynamicLinkData? initialLink =
        await FirebaseDynamicLinks.instance.getInitialLink();
    if (initialLink != null) {
      await _handleDeepLink(initialLink.link, analytics);
    }
    FirebaseDynamicLinks.instance.onLink.listen(
        (PendingDynamicLinkData dynamicLinkData) async {
      await _handleDeepLink(dynamicLinkData.link, analytics);
    }, onError: (Object error) {
      print('Error handling dynamic link: $error');
    }, onDone: () {
      print('Link stream closed');
    });
  } catch (e) {
    print('Error initializing dynamic links: $e');
  }
}

Future<void> _handleDeepLink(Uri? deepLink, FirebaseAnalytics analytics) async {
  if (deepLink != null) {
    print('Received deep link: $deepLink');
    // Log deep link event
    await analytics.logEvent(
      name: 'deep_link_received',
      parameters: {
        'link': deepLink.toString(),
      },
    );
    if (deepLink.host != 'https://www.videosalarmsapp.com/') {
      print('Invalid Dynamic Link domain: ${deepLink.host}');
      return;
    }
    final videoId = deepLink.queryParameters['videoId'];
    if (videoId != null) {
      print('Navigating to video with videoId: $videoId');
      // Log video view event
      await analytics.logEvent(
        name: 'view_video',
        parameters: {
          'videoId': videoId,
        },
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.toNamed('/view_video', arguments: {
          'videoId': videoId,
        });
      });
    } else {
      print('Missing videoId in deep link');
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
      // Add navigator observers for analytics
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      getPages: [
        GetPage(
          name: '/view_video',
          page: () => const ViewVideo(),
        ),
      ],
    );
  }
}
