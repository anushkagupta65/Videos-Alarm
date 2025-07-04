// import 'package:flutter/foundation.dart';
// import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';

// // class DynamicLinkService {
// //   Future<String> createShareVideoLink({
// //     required String videoId,
// //     required String videoTitle,
// //     required String videoDescription,
// //     String? thumbnailUrl,
// //   }) async {
// //     try {
// //       final Uri deepLink = Uri.parse(
// //         'https://www.videosalarm.com',
// //       );
// //       final DynamicLinkParameters parameters = DynamicLinkParameters(
// //         uriPrefix: 'https://videosalarmsapp.page.link',
// //         link: deepLink,
// //         androidParameters: AndroidParameters(
// //           packageName: 'com.videosalarm.app',
// //         ),
// //         iosParameters: IOSParameters(
// //           bundleId: 'videos.alarm.app',
// //           minimumVersion: '1.0.0', // Add minimum iOS version
// //           appStoreId: '6459475100', // ✅ Your real App Store ID
// //           fallbackUrl: Uri.parse(
// //               'https://apps.apple.com/app/id6459475100'), // optional but good
// //           ipadBundleId: 'videos.alarm.app', // Explicitly set iPad bundle ID
// //         ),
// //         socialMetaTagParameters: SocialMetaTagParameters(
// //           title: videoTitle,
// //           description: videoDescription,
// //           imageUrl: thumbnailUrl != null ? Uri.parse(thumbnailUrl) : null,
// //         ),
// //       );
// //       final Uri longDynamicLink =
// //           // ignore: deprecated_member_use
// //           await FirebaseDynamicLinks.instance.buildLink(parameters);
// //       debugPrint(' DEBUG POINT === Long Dynamic Link: $longDynamicLink');

// //       final ShortDynamicLink shortLink =
// //           // ignore: deprecated_member_use
// //           await FirebaseDynamicLinks.instance.buildShortLink(
// //         parameters,
// //         shortLinkType: ShortDynamicLinkType.unguessable,
// //       );

// //       return shortLink.shortUrl.toString();
// //     } catch (e, stackTrace) {
// //       debugPrint(' DEBUG POINT === Error Type: ${e.runtimeType}');
// //       debugPrint(' DEBUG POINT === StackTrace: $stackTrace');
// //       rethrow;
// //     }
// //   }
// // }

// class DynamicLinkService {
//   Future<String> createShareVideoLink({
//     required String videoId,
//     required String videoTitle,
//     required String videoDescription,
//     String? thumbnailUrl,
//   }) async {
//     try {
//       final Uri deepLink = Uri.parse(
//         'https://www.videosalarm.com?videoId=$videoId',
//       );
//       final DynamicLinkParameters parameters = DynamicLinkParameters(
//         uriPrefix: 'https://videosalarmsapp.page.link',
//         link: deepLink,
//         androidParameters: AndroidParameters(
//           packageName: 'com.videosalarm.app',
//         ),
//         iosParameters: IOSParameters(
//           bundleId: 'videos.alarm.app',
//           minimumVersion: '1.0.0',
//           appStoreId: '6459475100',
//           fallbackUrl: Uri.parse('https://apps.apple.com/app/id6459475100'),
//           ipadBundleId: 'videos.alarm.app',
//         ),
//         socialMetaTagParameters: SocialMetaTagParameters(
//           title: videoTitle,
//           description: videoDescription,
//           imageUrl: thumbnailUrl != null ? Uri.parse(thumbnailUrl) : null,
//         ),
//       );
//       final Uri longDynamicLink =
//           // ignore: deprecated_member_use
//           await FirebaseDynamicLinks.instance.buildLink(parameters);
//       debugPrint(' DEBUG POINT === Long Dynamic Link: $longDynamicLink');

//       final ShortDynamicLink shortLink =
//           // ignore: deprecated_member_use
//           await FirebaseDynamicLinks.instance.buildShortLink(
//         parameters,
//         shortLinkType: ShortDynamicLinkType.unguessable,
//       );

//       return shortLink.shortUrl.toString();
//     } catch (e, stackTrace) {
//       debugPrint(' DEBUG POINT === Error Type: ${e.runtimeType}');
//       debugPrint(' DEBUG POINT === StackTrace: $stackTrace');
//       rethrow;
//     }
//   }
// }

import 'package:flutter/foundation.dart';

class DynamicLinkService {
  static const String _serverHost = 'videosalarm.com';
  static const String _serverScheme = 'https';

  String createShareVideoLink({
    required String videoId,
  }) {
    try {
      final String path = '/api/share/video/$videoId';

      final Uri shareLink = Uri(
        scheme: _serverScheme,
        host: _serverHost,
        path: path,
      );

      final urlString = shareLink.toString();
      debugPrint('DEBUG === Generated Share Link: $urlString');
      return urlString;
    } catch (e, stackTrace) {
      debugPrint('DEBUG === Error creating link: $e');
      debugPrint('DEBUG === StackTrace: $stackTrace');
      return 'https://www.videosalarm.com';
    }
  }
}
