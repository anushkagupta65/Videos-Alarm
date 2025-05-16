// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// class NotificationService {
//   static final NotificationService _instance = NotificationService._internal();
//   factory NotificationService() => _instance;
//   NotificationService._internal();

//   final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   static const String _channelId = 'videos_alarm_channel';
//   static const String _channelName = 'VideosAlarm Notifications';
//   static const String _channelDescription = 'Notifications for new videos';

//   Future<void> initialize() async {
//     print('Starting NotificationService initialization');
//     const AndroidInitializationSettings androidSettings =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
//     const InitializationSettings initializationSettings =
//         InitializationSettings(android: androidSettings);
//     await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
//     print('Local notifications initialized');

//     const AndroidNotificationChannel channel = AndroidNotificationChannel(
//       _channelId,
//       _channelName,
//       description: _channelDescription,
//       importance: Importance.high,
//     );
//     await _flutterLocalNotificationsPlugin
//         .resolvePlatformSpecificImplementation<
//             AndroidFlutterLocalNotificationsPlugin>()
//         ?.createNotificationChannel(channel);
//     print('Notification channel created');

//     FirebaseMessaging messaging = FirebaseMessaging.instance;
//     NotificationSettings settings = await messaging.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//     );
//     print('Notification permission requested: ${settings.authorizationStatus}');

//     if (settings.authorizationStatus == AuthorizationStatus.authorized) {
//       print('User granted notification permission');
//     } else {
//       print('User denied notification permission');
//     }

//     await FirebaseMessaging.instance.subscribeToTopic('all');
//     print('Subscribed to topic: all');

//     String? token = await FirebaseMessaging.instance.getToken();
//     print('Device Token: $token');

//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       print('Got a foreground message: ${message.notification?.title}');
//       if (message.notification != null) {
//         _showNotification(
//           title: message.notification!.title ?? 'New Notification',
//           body: message.notification!.body ?? 'Check it out!',
//         );
//       }
//     });
//     print('Foreground message listener set');
//   }

//   Future<void> _showNotification(
//       {required String title, required String body}) async {
//     const AndroidNotificationDetails androidDetails =
//         AndroidNotificationDetails(
//       _channelId,
//       _channelName,
//       channelDescription: _channelDescription,
//       importance: Importance.high,
//       priority: Priority.high,
//       showWhen: true,
//     );
//     const NotificationDetails platformDetails =
//         NotificationDetails(android: androidDetails);

//     await _flutterLocalNotificationsPlugin.show(
//       0,
//       title,
//       body,
//       platformDetails,
//     );
//   }

//   static Future<void> backgroundHandler(RemoteMessage message) async {
//     print('Background message: ${message.notification?.title}');
//   }
// }
