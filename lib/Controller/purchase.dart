import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:videos_alarm_app/screens/Vid_controller.dart';

class PurchaseTokenModel {
  final String productId;
  final String purchaseToken;

  PurchaseTokenModel({
    required this.productId,
    required this.purchaseToken,
  });
  final VideoController videoController = Get.put(VideoController());

  // Factory method to create an object from a JSON response
  factory PurchaseTokenModel.fromJson(Map<String, dynamic> json) {
    return PurchaseTokenModel(
      productId: json['productId'],
      purchaseToken: json['purchaseToken'],
    );
  }

  // Method to convert an object to JSON
  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'purchaseToken': purchaseToken,
    };
  }

  // Method to send the purchase token and productId to the backend API

  // Method to send the purchase token and productId to the backend API
  Future<void> checkSubscriptionStatus() async {
    final url = 'http://192.168.1.3/subscription/check-subscription.php';
    final response = await http.post(
      Uri.parse(url),
      body: json.encode({
        'purchaseToken': purchaseToken,
        'productId': productId,
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // Extracting data from the response
      final status = data['status']; // This could be null
      final autoRenewing =
          data['autoRenewing'] ?? false; // Default to false if null
      var canceled = data['canceled'] ?? false; // Default to false if null
      final expiryDateMillis = data['expiryDate'];

      // Parse the expiry date
      DateTime? expiryDate;
      if (expiryDateMillis != null) {
        expiryDate =
            DateTime.fromMillisecondsSinceEpoch(int.parse(expiryDateMillis));
      }

      // Handling the subscription status logic
      if (canceled) {
        print('Subscription has been canceled.');
        videoController.isUserActive.value = false;
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          String userId = currentUser.uid;
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          if (userDoc.exists) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .update({
              'Active': false,
            });

            print('Subscription is canceled');
            // Get.snackbar(
            //   'Subscription Canceled',
            //   'Your subscription has been canceled.',
            //   snackPosition: SnackPosition.BOTTOM,
            //   backgroundColor: Colors.red,
            //   colorText: Colors.white,
            //   duration: Duration(seconds: 3),
            // );
          }
        }
      } else if (expiryDate != null && DateTime.now().isAfter(expiryDate)) {
        print('Subscription has expired.');
      } else if (autoRenewing) {
        print('Subscription is active and set to auto-renew.');
      } else {
        print('Subscription is active but not auto-renewing.');
      }

      // Additional logic based on `status` if needed
      if (status != null) {
        print('Subscription status: $status');
      }
    } else {
      // Handle error
      print('Error here : ${response.body}');
    }
  }
}
