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

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
  );

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

void onDidReceiveNotificationResponse(NotificationResponse response) {
  print('Notification tapped: ${response.payload}');
}

Future<void> requestIOSPermissions() async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }
}

Future<void> requestFirebasePermissions() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  print('User granted permission: ${settings.authorizationStatus}');

  String? token = await messaging.getToken();
  print('FCM Token: $token');
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

    facebookAppEvents.logEvent(name: 'app_launch');

    await setupFlutterNotifications();
    await requestIOSPermissions();
    await requestFirebasePermissions();

    FirebaseAnalytics analytics = FirebaseAnalytics.instance;
    await analytics.setAnalyticsCollectionEnabled(true);
    await analytics.logAppOpen();
    print('✅ Firebase Analytics initialized');

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data.toString(),
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
