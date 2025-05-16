import 'package:flutter/foundation.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';

class DynamicLinkService {
  Future<String> createShareVideoLink({
    required String videoId,
    required String videoTitle,
    required String videoDescription,
    String? thumbnailUrl,
  }) async {
    try {
      final Uri deepLink = Uri.parse(
        'https://www.myvideosalarm.com/video?videoId=${Uri.encodeComponent(videoId)}',
      );
      final DynamicLinkParameters parameters = DynamicLinkParameters(
        uriPrefix: 'https://videosalarmsapp.page.link',
        link: deepLink,
        androidParameters: const AndroidParameters(
          packageName: 'com.videosalarm.app',
        ),
        iosParameters: const IOSParameters(
          bundleId: 'video.alarm.app',
        ),
        socialMetaTagParameters: SocialMetaTagParameters(
          title: videoTitle,
          description: videoDescription,
          imageUrl: thumbnailUrl != null ? Uri.parse(thumbnailUrl) : null,
        ),
      );
      final Uri longDynamicLink =
          // ignore: deprecated_member_use
          await FirebaseDynamicLinks.instance.buildLink(parameters);
      debugPrint(' DEBUG POINT === Long Dynamic Link: $longDynamicLink');

      final ShortDynamicLink shortLink =
          // ignore: deprecated_member_use
          await FirebaseDynamicLinks.instance.buildShortLink(
        parameters,
        shortLinkType: ShortDynamicLinkType.unguessable,
      );

      return shortLink.shortUrl.toString();
    } catch (e, stackTrace) {
      debugPrint(' DEBUG POINT === Error Type: ${e.runtimeType}');
      debugPrint(' DEBUG POINT === StackTrace: $stackTrace');
      rethrow;
    }
  }
}
