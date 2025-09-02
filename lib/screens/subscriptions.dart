import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videos_alarm_app/Controller/subscription_controller.dart';
import 'package:videos_alarm_app/screens/Current_sub.dart';
import 'package:videos_alarm_app/screens/Subs_card.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io' show Platform;

class SubscriptionsScreen extends StatefulWidget {
  SubscriptionsScreen({Key? key}) : super(key: key);

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Subscription Options'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(8.w),
                child: Obx(() {
                  if (videoController.isUserActive.value == false) {
                    return _buildSubscriptionOptions();
                  } else {
                    return FutureBuilder<Map<String, dynamic>?>(
                      future: subscriptionController
                          .getCurrentSubscriptionDetails(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
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
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : SizedBox.shrink();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 8.h),
        Text('Get Premium',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color.fromARGB(255, 117, 109, 224),
                fontSize: 20.sp,
                fontWeight: FontWeight.bold)),
        SizedBox(height: 8.h),
        Text('Unlock all features. Enjoy VideosAlarm without limits!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18.sp,
            )),
        SizedBox(height: 40.h),
        ListTile(
          leading: Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 24.sp,
          ),
          title: Text(
            'Unlimited Access',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
            ),
          ),
          subtitle: Text(
            'Unlock all features, no restrictions!',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14.sp,
            ),
          ),
        ),
        ListTile(
          leading: Icon(
            Icons.movie,
            color: Colors.red,
            size: 24.sp,
          ),
          title: Text(
            'Exclusive Content',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
            ),
          ),
          subtitle: Text(
            'Get access to Exclusive Movies and Songs!',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14.sp,
            ),
          ),
        ),
        ListTile(
          leading: Icon(
            Icons.cancel,
            color: Colors.amber,
            size: 24.sp,
          ),
          title: Text(
            'Cancel Anytime',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
            ),
          ),
          subtitle: Text(
            'No long-term commitment!',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14.sp,
            ),
          ),
        ),
        SizedBox(height: 40.h),
        SubscriptionPlanCard(
            planId: Platform.isIOS
                ? SubscriptionController.iosPremiumPlanId
                : SubscriptionController.androidBasicPlanId,
            onSubscribe: () {
              subscriptionController.purchaseSubscription().then((_) {
                videoController.checkUserActiveStatus();
              });
            }),
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
              child: Text(
                'Terms of Service',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14.sp,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            TextButton(
              onPressed: () async {
                final Uri url =
                    Uri.parse('https://videosalarm.com/privacy-policy.html');
                if (!await launchUrl(url)) {
                  throw Exception('Could not launch $url');
                }
              },
              child: Text(
                'Privacy Policy',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
