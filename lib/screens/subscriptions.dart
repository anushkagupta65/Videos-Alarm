import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videos_alarm_app/Controller/Sub_controller.dart';
import 'package:videos_alarm_app/components/app_style.dart';
import 'package:videos_alarm_app/screens/Current_sub.dart';
import 'package:videos_alarm_app/screens/Subs_card.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';
import 'dart:io' show Platform;

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({Key? key}) : super(key: key);

  @override
  _SubscriptionsScreenState createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final SubscriptionController subscriptionController =
      Get.find<SubscriptionController>();
  final VideoController videoController = Get.put(VideoController());

  @override
  void initState() {
    super.initState();
    videoController.checkUserActiveStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title:
            Text('Subscription Options', style: TextStyle(color: whiteColor)),
        backgroundColor: Colors.grey[900],
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Obx(() {
                if (videoController.isUserActive.value == false) {
                  return _buildSubscriptionOptions();
                } else {
                  return FutureBuilder<Map<String, dynamic>?>(
                    future:
                        subscriptionController.getCurrentSubscriptionDetails(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data == null) {
                        print(
                            'Problem getting active sub details, showing sub options');
                        return _buildSubscriptionOptions();
                      }

                      final subscriptionData = snapshot.data!;

                      return CurrentSubscriptionCard(
                        planName: subscriptionData['planName'] ?? "Premium",
                        price: subscriptionData['price'] ?? "₹150.00",
                        description: subscriptionData['description'] ??
                            "Enjoy premium access to VideosAlarm!",
                        expiryDate:
                            subscriptionData['expiryDate'] ?? "Not Available",
                      );
                    },
                  );
                }
              }),
            ),
            Obx(() {
              return subscriptionController.isProcessing.value
                  ? Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 30),
        const Text('Get Premium',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color.fromARGB(255, 117, 109, 224),
                fontSize: 28,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text('Unlock all features. Enjoy VideosAlarm without limits!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 18)),
        const SizedBox(height: 24),
        ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: const Text('Unlimited Access',
                style: TextStyle(color: Colors.white)),
            subtitle: Text('Unlock all features, no restrictions!',
                style: TextStyle(color: Colors.grey[400]))),
        ListTile(
            leading: const Icon(Icons.movie, color: Colors.red),
            title: const Text('Exclusive Content',
                style: TextStyle(color: Colors.white)),
            subtitle: Text('Get access to Exclusive Movies and Songs!',
                style: TextStyle(color: Colors.grey[400]))),
        ListTile(
            leading: const Icon(Icons.cancel, color: Colors.amber),
            title: const Text('Cancel Anytime',
                style: TextStyle(color: Colors.white)),
            subtitle: Text('No long-term commitment!',
                style: TextStyle(color: Colors.grey[400]))),
        const SizedBox(height: 32),
        SubscriptionPlanCard(
            planId: Platform.isIOS
                ? SubscriptionController.iosPremiumPlanId
                : SubscriptionController.androidBasicPlanId,
            onSubscribe: () {
              subscriptionController.purchaseSubscription().then((_) {
                videoController.checkUserActiveStatus();
              });
            }),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () async {
                final Uri url = Uri.parse(
                    'https://videosalarm.com/videoalarm/terms-and-condition.php');
                if (!await launchUrl(url)) {
                  throw Exception('Could not launch $url');
                }
              },
              child: Text('Terms of Service',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () async {
                final Uri url =
                    Uri.parse('https://videosalarm.com/privacy-policy.html');
                if (!await launchUrl(url)) {
                  throw Exception('Could not launch $url');
                }
              },
              child: Text('Privacy Policy',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            ),
          ],
        ),
      ],
    );
  }
}
