import 'dart:async';
import 'dart:io'; // For platform checking
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smart_popup/smart_popup.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';

class SubscriptionService {
  final VideoController videoController = Get.find<VideoController>();

  Future<void> checkSubscriptionStatus() async {
    print('Checking subscription status...');
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      print('No user logged in.');
      videoController.isUserActive.value = false;
      return;
    }

    String userId = currentUser.uid;

    try {
      // Fetch the user document from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        print('User document does not exist.');
        videoController.isUserActive.value = false;
        return;
      }

      String productId = userDoc['SubscriptionType'] ?? '';
      String purchaseToken = userDoc['PurchaseToken'] ?? '';
      print('productId: $productId');
      print('purchaseToken: $purchaseToken');

      // Check if productId or purchaseToken is empty
      if (productId.isEmpty || purchaseToken.isEmpty) {
        print('No valid subscription data found.');
        videoController.isUserActive.value = false;
        return;
      }

      // Handle platform-specific logic without server-side validation
      if (Platform.isIOS) {
        await _checkIOSSubscription(userDoc, userId);
      } else {
        await _checkAndroidSubscription(userDoc, userId);
      }
    } catch (e) {

    }
  }

  Future<void> _checkIOSSubscription(DocumentSnapshot userDoc, String userId) async {
    try {
      // Check if subscription expiry date exists in Firestore
      if (!userDoc.data().toString().contains('SubscriptionExpiryDate')) {
        print('No subscription expiry date found for iOS.');
        videoController.isUserActive.value = false;
        return;
      }

      DateTime expiryDate = (userDoc['SubscriptionExpiryDate'] as Timestamp).toDate();
      bool isActive = userDoc['Active'] ?? false;
      print('iOS expiryDate: $expiryDate');

      if (isActive && DateTime.now().isBefore(expiryDate)) {
        videoController.isUserActive.value = true;
        print('iOS subscription is active until $expiryDate.');
      } else {
        videoController.isUserActive.value = false;
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'Active': false,
          'SubscriptionType': '',
          'PurchaseToken': '',
        });
        print('iOS subscription has expired or is inactive.');

        Get.dialog(
          SmartPopup(
            buttonAlignment: ButtonAlignment.horizontal,
            title: "Subscription Ended",
            subTitle: "Your iOS subscription has expired.",
            primaryButtonText: "OK",
            popType: PopType.warning,
            animationType: AnimationType.slide,
          ),
        );
      }
    } catch (e) {
      print('Error checking iOS subscription: $e');
      videoController.isUserActive.value = false;
    }
  }

  Future<void> _checkAndroidSubscription(DocumentSnapshot userDoc, String userId) async {
    try {
      // Check if subscription expiry date exists in Firestore
      if (!userDoc.data().toString().contains('SubscriptionExpiryDate')) {
        print('No subscription expiry date found for Android.');
        videoController.isUserActive.value = false;
        return;
      }

      DateTime expiryDate = (userDoc['SubscriptionExpiryDate'] as Timestamp).toDate();
      bool isActive = userDoc['Active'] ?? false;
      print('Android expiryDate: $expiryDate');

      if (isActive && DateTime.now().isBefore(expiryDate)) {
        // Subscription is still active
        videoController.isUserActive.value = true;
        print('Android subscription is active until $expiryDate.');
      } else {
        // Subscription has expired or is marked inactive
        videoController.isUserActive.value = false;
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'Active': false,
          'SubscriptionType': '',
          'PurchaseToken': '',
        });
        print('Android subscription has expired or is inactive.');

        Get.dialog(
          SmartPopup(
            buttonAlignment: ButtonAlignment.horizontal,
            title: "Subscription Ended",
            subTitle: "Your Android subscription has expired.",
            primaryButtonText: "OK",
            popType: PopType.warning,
            animationType: AnimationType.slide,
          ),
        );
      }
    } catch (e) {
      print('Error checking Android subscription: $e');
      videoController.isUserActive.value = false;
    }
  }
}