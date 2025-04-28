import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:smart_popup/smart_popup.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videos_alarm_app/Controller/sub.model.dart';
import 'package:videos_alarm_app/screens/banner_video_list.dart';

class SubscriptionController extends GetxController {
  var isAvailable = false.obs;
  var isProcessing = false.obs;
  RxString subscriptionType = "".obs;

  late InAppPurchase inAppPurchase;
  var nowactive = true.obs;
  RxString planName = 'Unknown Plan'.obs;
  RxString price = '\₹99.00'.obs;

  final Rx<Map<String, ProductDetails>> productDetailsMap =
      Rx<Map<String, ProductDetails>>({});

  // Product IDs for both platforms
  static const String androidBasicPlanId = 'vip_plan_id';
  static const String iosPremiumPlanId = 'com.videosalarm.subscription.premium';

  @override
  void onInit() async {
    super.onInit();
    inAppPurchase = InAppPurchase.instance;
    await _initializeBillingClient();
    await _checkAvailability();
    await loadProductDetails();
    await getDetails();

    final Stream<List<PurchaseDetails>> purchaseUpdated = 
        inAppPurchase.purchaseStream;
    purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        print("Purchase stream done");
      },
      onError: (error) {
        print("Error in purchase stream: $error");
        isProcessing.value = false;
      },
    );
  }

  Future<void> _initializeBillingClient() async {
    try {
      final isBillingAvailable = await inAppPurchase.isAvailable();
      print('Billing client available: $isBillingAvailable');
      if (!isBillingAvailable) {
        print('Billing client is not available');
        return;
      }
    } catch (e) {
      print('Error initializing billing client: $e');
    }
  }

  Future<void> _checkAvailability() async {
    try {
      isAvailable.value = await inAppPurchase.isAvailable();
      print('In-app purchase available: ${isAvailable.value}');
    } catch (e) {
      print('Error checking availability: $e');
    }
  }

  Future<void> loadProductDetails() async {
    final Set<String> productIds = {
      Platform.isIOS ? iosPremiumPlanId : androidBasicPlanId,
    };

    try {
      print('Querying product details for: $productIds');
      final ProductDetailsResponse response =
          await inAppPurchase.queryProductDetails(productIds);

      if (response.notFoundIDs.isNotEmpty) {
        print('Products not found: ${response.notFoundIDs}');
      }

      if (response.productDetails.isEmpty) {
        print('No product details found');
        return;
      }

      final Map<String, ProductDetails> detailsMap = {
        for (var detail in response.productDetails) detail.id: detail
      };
      productDetailsMap.value = detailsMap;

      for (var detail in response.productDetails) {
        print('Product ID: ${detail.id}');
        print('Product Title: ${detail.title}');
        print('Product Description: ${detail.description}');
        print('Product Price: ${detail.price}');
      }
    } catch (e) {
      print('Error loading product details: $e');
    }
  }

  Future<void> getDetails() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("No user is logged in");
        return;
      }

      String userId = currentUser.uid;
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists) {
        Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null) {
          subscriptionType.value = userData['SubscriptionType'] ?? 'None';
          print("Current subscription type: ${subscriptionType.value}");

          if (userData['Active'] == true) {
            nowactive.value = true;

            // Get plan details
            SubscriptionPlan? plan = SubscriptionPlan.getById(subscriptionType.value);
            planName.value = plan?.name ?? 'Unknown Plan';

            // Get price from product details if available
            final productDetails = productDetailsMap.value[subscriptionType.value];
            price.value = productDetails?.price ?? '\₹99.00';
          } else {
            nowactive.value = false;
          }
        }
      } else {
        print("User document does not exist");
      }
    } catch (e) {
      print("Error getting subscription details: $e");
    }
  }

  Future<void> purchaseSubscription() async {
    if (!isAvailable.value) {
      // Get.snackbar("Error", "In-app purchase is not available");
      return;
    }

    String productId = Platform.isIOS ? iosPremiumPlanId : androidBasicPlanId;
    final ProductDetails? productDetails = productDetailsMap.value[productId];

    if (productDetails == null) {
      // Get.snackbar("Error", "Product details not found. Please try again later.");
      return;
    }

    try {
      isProcessing.value = true;
      
      // For iOS, we need to use different purchase method
      if (Platform.isIOS) {
        await inAppPurchase.buyConsumable(purchaseParam: PurchaseParam(productDetails: productDetails));
      } else {
        await inAppPurchase.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: productDetails));
      }
      
      // Don't set isProcessing to false here, it will be set in the purchase listener
    } catch (e) {
      isProcessing.value = false;
      print("Error initiating purchase: $e");
      // Get.snackbar("Purchase Error", "Failed to initiate purchase. Please try again.");
    }
  }

  Future<bool> verifyIOSPurchase(PurchaseDetails purchaseDetails) async {
    try {
      final String receiptData = purchaseDetails.verificationData.serverVerificationData;
      if (receiptData.isEmpty) {
        print("Empty receipt data");
        return false;
      }

      // DEVELOPMENT MODE: Uncomment for testing and comment out for production
      // print("Development mode: Skipping receipt validation");
      // return true;

      // PRODUCTION MODE: Validate receipt with Apple's servers
      bool isValid = await _validateReceipt(receiptData, isSandbox: false);

      // If validation fails with "Sandbox receipt used in production," validate against the test environment
      if (!isValid) {
        print("Production validation failed. Attempting sandbox validation.");
        isValid = await _validateReceipt(receiptData, isSandbox: true);
      }

      return isValid;
    } catch (e) {
      print("Error verifying iOS purchase: $e");
      return false;
    }
  }

  Future<bool> _validateReceipt(String receiptData, {required bool isSandbox}) async {
    final String url = isSandbox
        ? "https://sandbox.itunes.apple.com/verifyReceipt"
        : "https://buy.itunes.apple.com/verifyReceipt";

    final Map<String, dynamic> requestBody = {
      'receipt-data': receiptData,
      'password': 'fde1c8b51a044cd78dbe1bfa073dd77f', // Replace with your App Store Connect shared secret
      'exclude-old-transactions': true
    };

    try {
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode != 200) {
        print("HTTP error: ${response.statusCode}");
        print("Response body: ${response.body}");
        return false;
      }

      final Map<String, dynamic> result = json.decode(response.body);

      if (result['status'] == 0) {
        print("iOS purchase verified successfully against ${isSandbox ? 'sandbox' : 'production'}: $result");
        return true;
      } else if (result['status'] == 21007 && !isSandbox) {
        print("Sandbox receipt used in production environment. Needs validation against sandbox.");
        return false; // Signal to try sandbox.
      } else {
        print("iOS purchase verification failed against ${isSandbox ? 'sandbox' : 'production'}: ${result['status']}");
        return false;
      }
    } catch (e) {
      print("Error validating receipt against ${isSandbox ? 'sandbox' : 'production'}: $e");
      return false;
    }
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      try {
        print("Purchase update: ${purchaseDetails.status} for ${purchaseDetails.productID}");
        
        if (purchaseDetails.status == PurchaseStatus.pending) {
          print("Purchase is pending");
          _showPendingUI();
        } else if (purchaseDetails.status == PurchaseStatus.error) {
          print("Purchase error: ${purchaseDetails.error?.message}");
          _handleError(purchaseDetails.error);
        } else if (purchaseDetails.status == PurchaseStatus.purchased || 
                  purchaseDetails.status == PurchaseStatus.restored) {
          print("Purchase successful or restored");
          await _handleSuccessfulPurchase(purchaseDetails);
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          print("Purchase canceled");
          isProcessing.value = false;
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          print("Completing purchase");
          await inAppPurchase.completePurchase(purchaseDetails);
        }
      } catch (e) {
        print("Error processing purchase update: $e");
        isProcessing.value = false;
      }
    }
  }

  void _showPendingUI() {
   
  }

  void _handleError(IAPError? error) {
    isProcessing.value = false;
    String errorMessage = error?.message ?? "An unknown error occurred";
    print("Purchase error: $errorMessage");
    
    Get.dialog(
      SmartPopup(
        buttonAlignment: ButtonAlignment.horizontal,
        title: "Purchase Failed",
        subTitle: errorMessage,
        primaryButtonText: "OK",
        popType: PopType.error,
        animationType: AnimationType.scale,
        primaryButtonTap: () {
          Get.back();
        },
      ),
    );
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    bool isValid = true;
    
    if (Platform.isIOS) {
      try {
        isValid = await verifyIOSPurchase(purchaseDetails);
      } catch (e) {
        print("iOS verification error: $e");
        isProcessing.value = false;
        return;
      }
    }

    if (!isValid) {
      isProcessing.value = false;
      return;
    }

    try {
      DateTime purchaseDate;
      try {
        if (purchaseDetails.transactionDate != null) {
          int timestamp = int.parse(purchaseDetails.transactionDate!);
          purchaseDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else {
          print("Transaction date is null, using current time");
          purchaseDate = DateTime.now();
        }
      } catch (e) {
        print("Error parsing transaction date: $e, using current time");
        purchaseDate = DateTime.now();
      }

      DateTime expiryDate = _getSubscriptionExpiryDate(purchaseDetails.productID, purchaseDate);
      
      String purchaseToken = Platform.isIOS
          ? purchaseDetails.verificationData.localVerificationData
          : purchaseDetails.purchaseID ?? '';

      await _updateUserActiveStatus(
        purchaseDetails.productID,
        purchaseToken,
        purchaseDate,
        expiryDate,
      );

      await getDetails(); // Refresh subscription details

      SubscriptionPlan? plan = SubscriptionPlan.getById(purchaseDetails.productID);
      final productDetails = productDetailsMap.value[purchaseDetails.productID];
      
      String statusMessage = purchaseDetails.status == PurchaseStatus.purchased
          ? "Purchase Successful!"
          : "Subscription Restored!";

      isProcessing.value = false;
      
      Get.dialog(
        SmartPopup(
          buttonAlignment: ButtonAlignment.horizontal,
          title: statusMessage,
          subTitle: 'You have successfully subscribed to ${plan?.name ?? "plan"} for ${productDetails?.price ?? "\₹99.00"}.',
          primaryButtonText: "OK",
          primaryButtonTap: () {
            Get.back();
            // Navigate to main screen only after user acknowledges the success
            Get.offAll(() => BottomBarTabs());
          },
          popType: PopType.success,
          animationType: AnimationType.size,
        ),
      );
    } catch (e) {
      print("Error processing successful purchase: $e");
      isProcessing.value = false;
      
      Get.dialog(
        SmartPopup(
          buttonAlignment: ButtonAlignment.horizontal,
          title: "Processing Error",
          subTitle: 'An error occurred while processing your subscription. Please contact support.',
          primaryButtonText: "OK",
          primaryButtonTap: () {
            Get.back();
          },
          popType: PopType.error,
          animationType: AnimationType.scale,
        ),
      );
    }
  }

  Future<void> _updateUserActiveStatus(
      String productId,
      String purchaseToken,
      DateTime purchaseDate,
      DateTime expiryDate) async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      String userId = currentUser.uid;

      try {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance.collection('users').doc(userId).get();

        if (userDoc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(userId).update({
            'Active': true,
            'SubscriptionStartDate': purchaseDate,
            'SubscriptionExpiryDate': expiryDate,
            'SubscriptionType': productId,
            'PurchaseToken': purchaseToken,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print("User status updated in Firestore");
        } else {
          print("User document not found");
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'Active': true,
            'SubscriptionStartDate': purchaseDate,
            'SubscriptionExpiryDate': expiryDate,
            'SubscriptionType': productId,
            'PurchaseToken': purchaseToken,
            'userId': userId,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print("Created new user document with subscription info");
        }
      } catch (e) {
        print("Error updating user status: $e");
        throw Exception("Failed to update user status: $e");
      }
    } else {
      print("No user logged in");
      throw Exception("No user logged in");
    }
  }

  DateTime _getSubscriptionExpiryDate(String productId, DateTime purchaseDate) {
    SubscriptionPlan? plan = SubscriptionPlan.getById(productId);
    if (plan != null) {
      return purchaseDate.add(Duration(days: plan.durationInDays));
    }
    return purchaseDate.add(const Duration(days: 365)); // Default to 1 year
  }

  Future<Map<String, dynamic>?> getCurrentSubscriptionDetails() async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      String userId = currentUser.uid;

      try {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance.collection('users').doc(userId).get();

        if (userDoc.exists) {
          Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
          if (userData == null) return null;
          
          if (!userData.containsKey('SubscriptionExpiryDate')) {
            return null; // No subscription data
          }

          DateTime expiryDate =
              (userData['SubscriptionExpiryDate'] as Timestamp).toDate();
          String subscriptionType = userData['SubscriptionType'] ?? 'None';
          bool isActive = userData['Active'] ?? false;

          final productDetails = productDetailsMap.value[subscriptionType];
          SubscriptionPlan? plan = SubscriptionPlan.getById(subscriptionType);

          planName.value = plan?.name ?? 'No Subscription';
          price.value = productDetails?.price ?? '\₹99.00';

          if (isActive) {
            return {
              'planName': planName.value,
              'price': price.value,
              'description': getSubscriptionDescription(subscriptionType),
              'expiryDate': DateFormat('yyyy-MM-dd').format(expiryDate),
            };
          }
        }
      } catch (e) {
        print("Error getting subscription details: $e");
      }
    }

    return null;
  }

  String getSubscriptionDescription(String productId) {
    return SubscriptionPlan.getDescriptionById(productId);
  }

  Future<void> checkSubscriptionExpiry() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        String userId = currentUser.uid;
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance.collection('users').doc(userId).get();

        if (userDoc.exists) {
          Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
          if (userData == null) return;
          
          if (userData.containsKey('SubscriptionExpiryDate')) {
            DateTime expiryDate =
                (userData['SubscriptionExpiryDate'] as Timestamp).toDate();
            if (DateTime.now().isAfter(expiryDate)) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .update({
                    'Active': false,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
              nowactive.value = false;
              print("Subscription expired, set Active to false");
            }
          }
        }
      }
    } catch (e) {
      print("Error checking subscription expiry: $e");
    }
  }

  Future<void> openCancellationPage() async {
    String url = '';
    if (Platform.isIOS) {
      url = 'itms-apps://apps.apple.com/account/subscriptions';
    } else if (Platform.isAndroid) {
      url = 'https://play.google.com/store/account/subscriptions';
    }

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      print('Error opening cancellation page: $e');
      // Get.snackbar("Error", "Could not open subscription settings.");
    }
  }

  Future<void> restorePurchases() async {
    try {
      print("Attempting to restore purchases");
      isProcessing.value = true;
      await inAppPurchase.restorePurchases();
    } catch (e) {
      isProcessing.value = false;
      print("Error restoring purchases: $e");
    }
  }
}