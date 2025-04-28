import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:videos_alarm_app/Controller/Sub_controller.dart';
import 'package:videos_alarm_app/components/app_style.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';

class CurrentSubscriptionScreen extends StatefulWidget {
  @override
  _CurrentSubscriptionScreenState createState() =>
      _CurrentSubscriptionScreenState();
}

class _CurrentSubscriptionScreenState extends State<CurrentSubscriptionScreen>
    with WidgetsBindingObserver {
  final SubscriptionController subscriptionController =
      Get.find<SubscriptionController>();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Current Subscription',
          style: TextStyle(color: whiteColor),
        ),
        backgroundColor: Colors.teal,
        iconTheme: IconThemeData(color: whiteColor),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: subscriptionController.getCurrentSubscriptionDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: TextStyle(color: Colors.red)));
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: CurrentSubscriptionCard(
                planName: 'No Subscription',
                price: '₹0.00',
                description:
                    'You do not have an active subscription. Subscribe now to enjoy premium features!',
                expiryDate: 'N/A',
              ),
            );
          }

          var subscriptionData = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: CurrentSubscriptionCard(
              planName: subscriptionData['planName'],
              price: subscriptionData['price'],
              description: subscriptionData['description'],
              expiryDate: subscriptionData['expiryDate'],
            ),
          );
        },
      ),
    );
  }
}

class CurrentSubscriptionCard extends StatelessWidget {
  final String planName;
  final String price;
  final String description;
  final String expiryDate;

  CurrentSubscriptionCard({
    required this.planName,
    required this.price,
    required this.description,
    required this.expiryDate,
  });

  final VideoController videoController = Get.put(VideoController());

  Future<void> openCancellationPage() async {
    String url = '';
    if (Platform.isIOS) {
      url = 'itms-apps://apps.apple.com/account/subscriptions';
    } else if (Platform.isAndroid) {
      url = 'https://play.google.com/store/account/subscriptions';
    }

    print('Opening cancellation page with URL: $url');

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        print('Launching cancellation page...');
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        print('Cannot launch URL: $url');
        throw 'Could not launch $url';
      }
    } catch (e) {
      print('Error opening cancellation page: $e');
    }
  }

  Future<void> checkSubscriptionStatussecond() async {
    print('Checking subscription status...');
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      String userId = currentUser.uid;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        String productId = userDoc['SubscriptionType'] ?? '';
        String purchaseToken = userDoc['PurchaseToken'] ?? '';
        print(productId);
        print(purchaseToken);

        if (productId.isEmpty || purchaseToken.isEmpty) {
          print('No valid subscription data found.');
          return;
        }

        final url = 'http://165.22.215.103:3005/checkSubscriptionStatus';

        try {
          final response = await http.post(
            Uri.parse(url),
            body: json.encode({
              'purchaseToken': purchaseToken,
              'productId': productId,
            }),
            headers: {'Content-Type': 'application/json'},
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);

            final status = data['status'];
            final autoRenewing = data['autoRenewing'] ?? false;
            final canceled = data['canceled'] ?? false;
            final expiryDateMillis = data['expiryDate'];

            DateTime? expiryDateTime;
            if (expiryDateMillis != null) {
              expiryDateTime =
                  DateTime.fromMillisecondsSinceEpoch(int.parse(expiryDateMillis));
            }

            print(expiryDateTime);
            if (canceled) {
              if (expiryDateTime != null &&
                  DateTime.now().isBefore(expiryDateTime)) {
                videoController.isUserActive.value = true;
                print(
                    'Subscription is canceled but still valid until $expiryDateTime.');
              } else {
                videoController.isUserActive.value = false;

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .update({
                  'SubscriptionType': '',
                  'PurchaseToken': '',
                  'Active': false,
                });
              }
            } else if (expiryDateTime != null &&
                DateTime.now().isAfter(expiryDateTime)) {
              print('Subscription has expired.');
              videoController.isUserActive.value = false;

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .update({
                'Active': false,
              });
            } else if (autoRenewing) {
              print('Subscription is active and set to auto-renew.');
              videoController.isUserActive.value = true;
            } else {
              print('Subscription is active but not auto-renewing.');
              videoController.isUserActive.value = true;
            }
          } else {
            print('Error checking subscription status: ${response.body}');
          }
        } catch (e) {
          print('Network error: $e');
        }
      } else {
        print('User document does not exist.');
      }
    } else {
      print('No user logged in.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final SubscriptionController subscriptionController =
        Get.find<SubscriptionController>();

    DateTime? expiryDateTime;
    String formattedExpiryDate = 'N/A';

    try {
      expiryDateTime = DateFormat('yyyy-MM-dd').parse(expiryDate);
      formattedExpiryDate = DateFormat('dd-MM-yyyy').format(expiryDateTime);
    } catch (e) {
      print('Error parsing expiry date: $e');
      formattedExpiryDate = 'N/A';
    }

    checkSubscriptionStatussecond();

    return Material(
      elevation: 5,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 33, 99, 75),
              Color.fromARGB(255, 44, 58, 46),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Text(
                planName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                price,
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: Colors.white.withOpacity(0.7),
                    size: 20,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Expiry Date: $formattedExpiryDate',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (planName != 'No Subscription') {
                      openCancellationPage();
                    } else {
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.teal,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    planName != 'No Subscription'
                        ? 'Manage Subscription'
                        : 'Subscribe Now',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}