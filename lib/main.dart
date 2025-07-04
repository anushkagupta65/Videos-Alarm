// import 'package:facebook_app_events/facebook_app_events.dart';
// import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_analytics/firebase_analytics.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:get/get.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:videos_alarm_app/Controller/Sub_controller.dart';
// import 'package:videos_alarm_app/screens/Vid_controller.dart';
// import 'package:videos_alarm_app/screens/live_videos.dart';
// import 'package:videos_alarm_app/screens/view_video.dart';
// import 'package:videos_alarm_app/login_screen/splash_screen.dart';
// import 'package:videos_alarm_app/app_store/app_pref.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//     FlutterLocalNotificationsPlugin();

// final FacebookAppEvents facebookAppEvents = FacebookAppEvents();

// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   print('🔄 Handling background message: ${message.messageId}');
// }

// Future<void> setupFlutterNotifications() async {
//   const AndroidInitializationSettings initializationSettingsAndroid =
//       AndroidInitializationSettings('@mipmap/ic_launcher');

//   const AndroidNotificationChannel channel = AndroidNotificationChannel(
//     'high_importance_channel',
//     'High Importance Notifications',
//     description: 'This channel is used for important notifications.',
//     importance: Importance.high,
//   );

//   final InitializationSettings initializationSettings = InitializationSettings(
//     android: initializationSettingsAndroid,
//   );

//   await flutterLocalNotificationsPlugin.initialize(initializationSettings);

//   await flutterLocalNotificationsPlugin
//       .resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin>()
//       ?.createNotificationChannel(channel);
// }

// // Add this new widget for TV navigation
// class TVNavigationWrapper extends StatelessWidget {
//   final Widget child;

//   const TVNavigationWrapper({Key? key, required this.child}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Shortcuts(
//       shortcuts: {
//         LogicalKeySet(LogicalKeyboardKey.arrowUp):
//             DirectionalFocusIntent(TraversalDirection.up),
//         LogicalKeySet(LogicalKeyboardKey.arrowDown):
//             DirectionalFocusIntent(TraversalDirection.down),
//         LogicalKeySet(LogicalKeyboardKey.arrowLeft):
//             DirectionalFocusIntent(TraversalDirection.left),
//         LogicalKeySet(LogicalKeyboardKey.arrowRight):
//             DirectionalFocusIntent(TraversalDirection.right),
//         LogicalKeySet(LogicalKeyboardKey.select): ActivateIntent(),
//         LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent(),
//       },
//       child: Actions(
//         actions: {
//           DirectionalFocusIntent: DirectionalFocusAction(),
//         },
//         child: Focus(
//           autofocus: true,
//           child: child,
//         ),
//       ),
//     );
//   }
// }

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   try {
//     print('🔧 Starting initialization');
//     await Firebase.initializeApp();

//     print('✅ Firebase initialized');

//     // facebookAppEvents.logEvent(name: 'app_launch');
//     // await setupFlutterNotifications();

//     FirebaseAnalytics analytics = FirebaseAnalytics.instance;
//     await analytics.setAnalyticsCollectionEnabled(true);
//     await analytics.logAppOpen();
//     print('✅ Firebase Analytics initialized');

//     FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       RemoteNotification? notification = message.notification;
//       AndroidNotification? android = message.notification?.android;

//       if (notification != null && android != null) {
//         flutterLocalNotificationsPlugin.show(
//           notification.hashCode,
//           notification.title,
//           notification.body,
//           const NotificationDetails(
//             android: AndroidNotificationDetails(
//               'high_importance_channel',
//               'High Importance Notifications',
//               importance: Importance.max,
//               priority: Priority.high,
//               icon: '@mipmap/ic_launcher',
//             ),
//           ),
//         );
//       }
//     });

//     subscribeToNotifications();

//     await AppPref.initSessionManager();
//     print('✅ Session manager initialized');

//     Get.put(SubscriptionController());
//     Get.put(LiveVideosController());
//     Get.put(VideoController());
//     print('✅ Controllers initialized');

//     await _initDynamicLinks(analytics);
//     print('✅ Dynamic Links initialized');

//     await dotenv.load(fileName: ".env");
//     print('✅ .env loaded');

//     runApp(const MyApp());
//     print('🚀 App running');
//   } catch (e) {
//     print('❌ Initialization error: $e');
//   }
// }

// void subscribeToNotifications() {
//   FirebaseMessaging.instance.subscribeToTopic('new-videos');
// }

// Future<void> _initDynamicLinks(FirebaseAnalytics analytics) async {
//   try {
//     final PendingDynamicLinkData? initialLink =
//         await FirebaseDynamicLinks.instance.getInitialLink();
//     if (initialLink != null) {
//       await _handleDeepLink(initialLink.link, analytics);
//     }

//     FirebaseDynamicLinks.instance.onLink.listen(
//         (PendingDynamicLinkData dynamicLinkData) async {
//       await _handleDeepLink(dynamicLinkData.link, analytics);
//     }, onError: (Object error) {
//       print('❌ Error handling dynamic link: $error');
//     });
//   } catch (e) {
//     print('❌ Error initializing dynamic links: $e');
//   }
// }

// Future<void> _handleDeepLink(Uri? deepLink, FirebaseAnalytics analytics) async {
//   if (deepLink == null) return;
//   print('🔗 Received deep link: $deepLink');
//   await analytics.logEvent(
//     name: 'deep_link_received',
//     parameters: {'link': deepLink.toString()},
//   );

//   facebookAppEvents.logEvent(
//     name: 'deep_link_received',
//     parameters: {'link': deepLink.toString()},
//   );

//   if (deepLink.host != 'www.videosalarm.com') {
//     print('❗ Invalid Dynamic Link domain: ${deepLink.host}');
//     Get.offAllNamed('/splash'); // Fallback to splash if domain is invalid
//     return;
//   }

//   final videoId = deepLink.queryParameters['videoId'];
//   if (videoId != null) {
//     print('📹 Navigating to video with videoId: $videoId');
//     await analytics.logEvent(
//       name: 'view_video',
//       parameters: {'videoId': videoId},
//     );
//     facebookAppEvents.logEvent(
//       name: 'view_video',
//       parameters: {'videoId': videoId},
//     );
//     Get.offAllNamed('/view_video', arguments: {'videoId': videoId});
//   } else {
//     print('⚠️ Missing videoId in deep link');
//     Get.offAllNamed('/splash'); // Fallback to splash if no videoId
//   }
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return ScreenUtilInit(
//       designSize: const Size(360, 690),
//       minTextAdapt: false,
//       builder: (context, child) {
//         return GetMaterialApp(
//           navigatorKey: Get.key,
//           theme: ThemeData(
//             textTheme: GoogleFonts.aBeeZeeTextTheme().copyWith(
//               bodyMedium: GoogleFonts.aBeeZee(textStyle: const TextStyle()),
//             ),
//           ),
//           debugShowCheckedModeBanner: false,
//           title: "VideosAlarm",
//           builder: (context, child) {
//             return MediaQuery(
//               data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
//               child:
//                   TVNavigationWrapper(child: child!), // Wrap with TV navigation
//             );
//           },
//           home: const SplashScreen(),
//           navigatorObservers: [
//             FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
//           ],
//           getPages: [
//             GetPage(
//               name: '/view_video',
//               page: () => const ViewVideo(),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }

// import 'dart:async';
// import 'package:app_links/app_links.dart';
// import 'package:facebook_app_events/facebook_app_events.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_analytics/firebase_analytics.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:get/get.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:videos_alarm_app/Controller/Sub_controller.dart';
// import 'package:videos_alarm_app/screens/Vid_controller.dart';
// import 'package:videos_alarm_app/screens/live_videos.dart';
// import 'package:videos_alarm_app/screens/view_video.dart';
// import 'package:videos_alarm_app/login_screen/splash_screen.dart';
// import 'package:videos_alarm_app/app_store/app_pref.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//     FlutterLocalNotificationsPlugin();

// final FacebookAppEvents facebookAppEvents = FacebookAppEvents();

// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   print('🔄 Handling background message: ${message.messageId}');
// }

// Future<void> setupFlutterNotifications() async {
//   const AndroidInitializationSettings initializationSettingsAndroid =
//       AndroidInitializationSettings('@mipmap/ic_launcher');

//   const AndroidNotificationChannel channel = AndroidNotificationChannel(
//     'high_importance_channel',
//     'High Importance Notifications',
//     description: 'This channel is used for important notifications.',
//     importance: Importance.high,
//   );

//   final InitializationSettings initializationSettings = InitializationSettings(
//     android: initializationSettingsAndroid,
//   );

//   await flutterLocalNotificationsPlugin.initialize(initializationSettings);

//   await flutterLocalNotificationsPlugin
//       .resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin>()
//       ?.createNotificationChannel(channel);
// }

// class TVNavigationWrapper extends StatelessWidget {
//   final Widget child;
//   const TVNavigationWrapper({Key? key, required this.child}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Shortcuts(
//       shortcuts: {
//         LogicalKeySet(LogicalKeyboardKey.arrowUp):
//             DirectionalFocusIntent(TraversalDirection.up),
//         LogicalKeySet(LogicalKeyboardKey.arrowDown):
//             DirectionalFocusIntent(TraversalDirection.down),
//         LogicalKeySet(LogicalKeyboardKey.arrowLeft):
//             DirectionalFocusIntent(TraversalDirection.left),
//         LogicalKeySet(LogicalKeyboardKey.arrowRight):
//             DirectionalFocusIntent(TraversalDirection.right),
//         LogicalKeySet(LogicalKeyboardKey.select): ActivateIntent(),
//         LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent(),
//       },
//       child: Actions(
//         actions: {
//           DirectionalFocusIntent: DirectionalFocusAction(),
//         },
//         child: Focus(
//           autofocus: true,
//           child: child,
//         ),
//       ),
//     );
//   }
// }

// StreamSubscription<Uri>? _linkSubscription;

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   try {
//     print('🔧 Starting initialization');
//     await Firebase.initializeApp();
//     print('✅ Firebase initialized');

//     // Request notification permissions
//     await FirebaseMessaging.instance.requestPermission(
//       alert: true,
//       announcement: false,
//       badge: true,
//       carPlay: false,
//       criticalAlert: false,
//       provisional: false,
//       sound: true,
//     );

//     // facebookAppEvents.logEvent(name: 'app_launch');

//     await setupFlutterNotifications();

//     FirebaseAnalytics analytics = FirebaseAnalytics.instance;
//     await analytics.setAnalyticsCollectionEnabled(true);
//     await analytics.logAppOpen();
//     print('✅ Firebase Analytics initialized');

//     FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       RemoteNotification? notification = message.notification;
//       AndroidNotification? android = message.notification?.android;

//       if (notification != null && android != null) {
//         flutterLocalNotificationsPlugin.show(
//           notification.hashCode,
//           notification.title,
//           notification.body,
//           const NotificationDetails(
//             android: AndroidNotificationDetails(
//               'high_importance_channel',
//               'High Importance Notifications',
//               importance: Importance.max,
//               priority: Priority.high,
//               icon: '@mipmap/ic_launcher',
//             ),
//           ),
//         );
//       }
//     });

//     subscribeToNotifications();

//     await AppPref.initSessionManager();
//     print('✅ Session manager initialized');

//     Get.put(SubscriptionController());
//     Get.put(LiveVideosController());
//     Get.put(VideoController());
//     print('✅ Controllers initialized');

//     print('✅ Custom Deep Links initialized');

//     await dotenv.load(fileName: ".env");
//     print('✅ .env loaded');
//     if (defaultTargetPlatform == TargetPlatform.android) {
//       await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
//     }

//     runApp(const MyApp());
//     print('🚀 App running');
//   } catch (e) {
//     print('❌ Initialization error: $e');
//   }
// }

// final _appLinks = AppLinks();

// void subscribeToNotifications() {
//   FirebaseMessaging.instance.subscribeToTopic('new-videos');
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return ScreenUtilInit(
//       designSize: const Size(360, 690),
//       minTextAdapt: false,
//       builder: (context, child) {
//         return GetMaterialApp(
//           theme: ThemeData(
//             textTheme: GoogleFonts.aBeeZeeTextTheme().copyWith(
//               bodyMedium: GoogleFonts.aBeeZee(
//                 textStyle: const TextStyle(),
//               ),
//             ),
//           ),
//           debugShowCheckedModeBanner: false,
//           title: "VideosAlarm",
//           builder: (context, child) {
//             return MediaQuery(
//               data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
//               child: child!,
//             );
//           },
//           home: const TVNavigationWrapper(child: SplashScreen()),
//           navigatorObservers: [
//             FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
//           ],
//         );
//       },
//     );
//   }
// }

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:videos_alarm_app/Controller/Sub_controller.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';
import 'package:videos_alarm_app/screens/live_videos.dart';
import 'package:videos_alarm_app/login_screen/splash_screen.dart';
import 'package:videos_alarm_app/app_store/app_pref.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final FacebookAppEvents facebookAppEvents = FacebookAppEvents();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔄 Handling background message: ${message.messageId}');
}

Future<void> setupFlutterNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

class TVNavigationWrapper extends StatelessWidget {
  final Widget child;
  const TVNavigationWrapper({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowUp):
            DirectionalFocusIntent(TraversalDirection.up),
        LogicalKeySet(LogicalKeyboardKey.arrowDown):
            DirectionalFocusIntent(TraversalDirection.down),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft):
            DirectionalFocusIntent(TraversalDirection.left),
        LogicalKeySet(LogicalKeyboardKey.arrowRight):
            DirectionalFocusIntent(TraversalDirection.right),
        LogicalKeySet(LogicalKeyboardKey.select): ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      child: Actions(
        actions: {
          DirectionalFocusIntent: DirectionalFocusAction(),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

StreamSubscription<Uri>? _linkSubscription;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('🔧 Starting initialization');
    await Firebase.initializeApp();
    print('✅ Firebase initialized');
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // facebookAppEvents.logEvent(name: 'app_launch');
    // await setupFlutterNotifications();

    FirebaseAnalytics analytics = FirebaseAnalytics.instance;
    await analytics.setAnalyticsCollectionEnabled(true);
    await analytics.logAppOpen();
    print('✅ Firebase Analytics initialized');

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });

    subscribeToNotifications();

    await AppPref.initSessionManager();
    print('✅ Session manager initialized');

    Get.put(SubscriptionController());
    Get.put(LiveVideosController());
    Get.put(VideoController());
    print('✅ Controllers initialized');

    print('✅ Custom Deep Links initialized');

    await dotenv.load(fileName: ".env");
    print('✅ .env loaded');
    if (defaultTargetPlatform == TargetPlatform.android) {
      await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
    }

    runApp(const MyApp());
    print('🚀 App running');
  } catch (e) {
    print('❌ Initialization error: $e');
  }
}

final _appLinks = AppLinks();

void subscribeToNotifications() {
  FirebaseMessaging.instance.subscribeToTopic('new-videos');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: false,
      builder: (context, child) {
        return GetMaterialApp(
          theme: ThemeData(
            textTheme: GoogleFonts.aBeeZeeTextTheme().copyWith(
              bodyMedium: GoogleFonts.aBeeZee(
                textStyle: const TextStyle(),
              ),
            ),
          ),
          debugShowCheckedModeBanner: false,
          title: "VideosAlarm",
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
              child: child!,
            );
          },
          home: const TVNavigationWrapper(child: SplashScreen()),
          navigatorObservers: [
            FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
          ],
        );
      },
    );
  }
}
