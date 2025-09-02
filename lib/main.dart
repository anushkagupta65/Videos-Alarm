import 'dart:async';
import 'dart:io'; // NEW: Import for checking the platform (iOS/Android)
import 'package:app_links/app_links.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:in_app_purchase/in_app_purchase.dart'; // NEW: Import for InAppPurchase instance
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart'; // NEW: Imports for iOS StoreKit 2 initialization
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:videos_alarm_app/login_screen/splash_screen.dart';
import 'package:videos_alarm_app/app_store/app_pref.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';
import 'package:videos_alarm_app/screens/live_videos.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final FacebookAppEvents facebookAppEvents = FacebookAppEvents();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔄 [Background] Handling background message: ${message.messageId}');
}

Future<void> setupFlutterNotifications() async {
  print('🔧 [Notifications] Setting up notifications');
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
  print('✅ [Notifications] Setup completed');
}

void onDidReceiveNotificationResponse(NotificationResponse response) {
  print('📩 [Notification] Tapped: ${response.payload}');
}

Future<void> requestIOSPermissions() async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    print('🔧 [IOS] Requesting permissions');
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    print('✅ [IOS] Permissions requested');
  }
}

Future<void> requestFirebasePermissions() async {
  print('🔧 [Firebase] Requesting messaging permissions');
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
  print('✅ [Firebase] Permission status: ${settings.authorizationStatus}');
  String? token = await messaging.getToken();
  print('🔑 [Firebase] FCM Token: $token');
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
        LogicalKeySet(LogicalKeyboardKey.goBack): BackIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): BackIntent(),
      },
      child: Actions(
        actions: {
          DirectionalFocusIntent: DirectionalFocusAction(),
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (intent) {
              final focusNode = FocusScope.of(context).focusedChild;
              if (focusNode != null && focusNode.context != null) {
                final widget = focusNode.context!.widget;
                if (widget is IconButton) {
                  widget.onPressed?.call();
                } else if (widget is BottomNavigationBar) {
                  widget.onTap?.call(widget.currentIndex);
                } else if (widget is MaterialButton) {
                  widget.onPressed?.call();
                }
              }
              return null;
            },
          ),
          BackIntent: CallbackAction<BackIntent>(
            onInvoke: (intent) {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                SystemNavigator.pop();
              }
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Focus(
            autofocus: true,
            onFocusChange: (hasFocus) {
              if (hasFocus) {
                print('🎯 [TVWrapper] Gained focus');
              }
            },
            child: child,
          ),
        ),
      ),
    );
  }
}

class BackIntent extends Intent {}

// ignore: unused_element
StreamSubscription<Uri>? _linkSubscription;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print('🔧 [Main] Starting initialization');
    await Firebase.initializeApp();
    print('✅ [Main] Firebase initialized');
    facebookAppEvents.logEvent(name: 'app_launch');
    await setupFlutterNotifications();
    await requestIOSPermissions();
    await requestFirebasePermissions();
    FirebaseAnalytics analytics = FirebaseAnalytics.instance;
    await analytics.setAnalyticsCollectionEnabled(true);
    await analytics.logAppOpen();
    print('✅ [Main] Firebase Analytics initialized');
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📬 [Messaging] Received foreground message: ${message.messageId}');
      RemoteNotification? notification = message.notification;
      // ignore: unused_local_variable
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
    Get.put(LiveVideosController());
    Get.put(VideoController());
    print('✅ Controllers initialized');

    print('✅ Custom Deep Links initialized');

    await dotenv.load(fileName: ".env");
    print('✅ .env loaded');

    // ========================================================================
    // NEW: Initialize StoreKit 2 payment queue delegate for iOS
    // This is required for in_app_purchase version 3.2.3 and higher to
    // correctly handle transactions on iOS.
    // ========================================================================
    if (Platform.isIOS) {
      final InAppPurchaseStoreKitPlatformAddition iapStoreKitPlatformAddition =
          InAppPurchase.instance
              .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iapStoreKitPlatformAddition
          .setDelegate(ExamplePaymentQueueDelegate());
      print('✅ [iOS] StoreKit 2 delegate initialized.');
    }
    // ========================================================================

    runApp(const MyApp());
    print('🚀 [Main] App running');
  } catch (e) {
    print('❌ [Main] Initialization error: $e');
  }
}

// ignore: unused_element
final _appLinks = AppLinks();

void subscribeToNotifications() {
  FirebaseMessaging.instance.subscribeToTopic('new-videos');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    print('🌐 [MyApp] Building app widget');
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
          home: const SplashScreen(),
          navigatorObservers: [
            FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
          ],
        );
      },
    );
  }
}

// ========================================================================
// NEW: Required Delegate Class for iOS StoreKit 2
// This handles transactions that occur when the app is in the background
// or is launched from a purchase notification.
// ========================================================================
class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
      SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    // Return true to allow the transaction to proceed in your app.
    // You can add logic here to defer or deny transactions if needed.
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    // Return false to prevent the standard iOS price increase consent sheet.
    // Set to true if you want iOS to handle this automatically.
    return false;
  }
}
// ========================================================================
