import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
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
  bool _isTimeout = false;
  DateTime? _clickTime;
  bool _isLoading = false;

  final SubscriptionController subscriptionController =
      Get.find<SubscriptionController>();
  final VideoController videoController = Get.put(VideoController()); // Add this line

  bool canClick() {
    return !_isTimeout;
  }

  void startTimeout() {
    setState(() {
      _isTimeout = true;
      _clickTime = DateTime.now();
    });

    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _isTimeout = false;
        });
      }
    });
  }

  void showLoadingIndicator() {
    setState(() {
      _isLoading = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    videoController.checkUserActiveStatus(); // Call it here!
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('Subscription Options', style: TextStyle(color: whiteColor)),
        backgroundColor: Colors.grey[900],
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Obx(() {
              if (videoController.isUserActive.value == false) {
                // Not subscribed, show options
                return _buildSubscriptionOptions();
              } else {
                // User is already considered subscribed.
                return FutureBuilder<Map<String, dynamic>?>(
                  future: subscriptionController.getCurrentSubscriptionDetails(),
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
                      expiryDate: subscriptionData['expiryDate'] ?? "Not Available",
                    );
                  },
                );
              }
            }),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 30),
        Text('Get Premium',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: const Color.fromARGB(255, 117, 109, 224),
                fontSize: 28,
                fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Text('Unlock all features. Enjoy VideosAlarm without limits!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 18)),
        SizedBox(height: 24),
        ListTile(
            leading: Icon(Icons.check_circle, color: Colors.green),
            title: Text('Unlimited Access', style: TextStyle(color: Colors.white)),
            subtitle: Text('Unlock all features, no restrictions!',
                style: TextStyle(color: Colors.grey[400]))),
        ListTile(
            leading: Icon(Icons.movie, color: Colors.red),
            title: Text('Exclusive Content', style: TextStyle(color: Colors.white)),
            subtitle: Text('Get access to Exclusive Movies and Songs!',
                style: TextStyle(color: Colors.grey[400]))),
        ListTile(
            leading: Icon(Icons.cancel, color: Colors.amber),
            title: Text('Cancel Anytime', style: TextStyle(color: Colors.white)),
            subtitle: Text('No long-term commitment!',
                style: TextStyle(color: Colors.grey[400]))),
        SizedBox(height: 32),
        SubscriptionPlanCard(
            planId: Platform.isIOS
                ? SubscriptionController.iosPremiumPlanId
                : SubscriptionController.androidBasicPlanId,
            onSubscribe: canClick()
                ? () {
                    startTimeout();
                    showLoadingIndicator();
                    subscriptionController.purchaseSubscription().then((_) {
                      // After the purchase completes (successfully or not), refresh the status
                      videoController.checkUserActiveStatus();
                    });
                  }
                : () {}),
        Spacer(),
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
            SizedBox(width: 10),
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