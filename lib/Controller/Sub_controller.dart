import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:smart_popup/smart_popup.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:videos_alarm_app/Controller/sub.model.dart';
import 'package:videos_alarm_app/screens/banner_video_list.dart';

class SubscriptionController extends GetxController {
  var isAvailable = false.obs;
  var isProcessing = false.obs;
  RxString subscriptionType = "".obs;

  late InAppPurchase inAppPurchase;
  late Razorpay _razorpay;
  var nowactive = true.obs;
  RxString planName = 'Unknown Plan'.obs;
  RxString price = '\₹99.00'.obs;

  final Rx<Map<String, ProductDetails>> productDetailsMap =
      Rx<Map<String, ProductDetails>>({});

  static const String androidBasicPlanId = 'vip_plan_id';
  static const String iosPremiumPlanId = 'com.videosalarm.subscription.premium';

  @override
  void onInit() async {
    super.onInit();
    // Load .env file
    await dotenv.load(fileName: ".env");

    inAppPurchase = InAppPurchase.instance;
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleRazorpaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleRazorpayError);

    await _initializeBillingClient();
    await _checkAvailability();
    await loadProductDetails();
    await checkSubscriptionStatus();

    if (!nowactive.value) {
      print("No active subscription, attempting to restore purchases");
      await restorePurchases();
    }

    final Stream<List<PurchaseDetails>> purchaseUpdated =
        inAppPurchase.purchaseStream;
    purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        print("Purchase stream done");
        isProcessing.value = false;
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

  Future<void> checkSubscriptionStatus() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      nowactive.value = false;
      subscriptionType.value = "";
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final sub = doc.data();
      if (sub != null && sub.containsKey('SubscriptionExpiryDate')) {
        final expiryDate =
            (sub['SubscriptionExpiryDate'] as Timestamp).toDate();
        final isActive = DateTime.now().isBefore(expiryDate);
        subscriptionType.value = sub['SubscriptionType'] ?? '';
        planName.value =
            SubscriptionPlan.getById(subscriptionType.value)?.name ??
                "Unknown Plan";
        final productDetails = productDetailsMap.value[subscriptionType.value];
        price.value = productDetails?.price ?? '\₹99.00';
        nowactive.value = isActive;
      } else {
        nowactive.value = false;
        subscriptionType.value = "";
        planName.value = "Unknown Plan";
      }
    } catch (e) {
      print("Error checking subscription status: $e");
      nowactive.value = false;
      subscriptionType.value = "";
    }
  }

  Future<void> getDetails() async {
    await checkSubscriptionStatus();
  }

  Future<void> purchaseSubscription() async {
    if (!isAvailable.value) {
      Get.dialog(
        SmartPopup(
          title: "Error",
          subTitle: "In-app purchase is not available",
          primaryButtonText: "OK",
          primaryButtonTap: () => Get.back(),
          popType: PopType.error,
        ),
      );
      return;
    }

    _showPaymentOptions();
  }

  void _showPaymentOptions() {
    Get.bottomSheet(
      SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Choose how to check out',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose who will manage all aspects of your purchase. Benefits and available forms of payment may vary.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _buildPaymentOption(
                      icon: Icons.payment,
                      title: 'Direct Payment',
                      methods: const [
                        'UPI',
                        'Paytm',
                        'Visa',
                        'Mastercard',
                        'and more'
                      ],
                      onTap: () => _startRazorpayPayment(),
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentOption(
                      icon: Icons.store,
                      title: Platform.isIOS ? 'Apple Pay' : 'Google Play',
                      methods: const [
                        'BHIM UPI',
                        'Visa',
                        'Mastercard',
                        'PayPal',
                        'and more'
                      ],
                      onTap: () => _startInAppPurchase(),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required List<String> methods,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        Get.back();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: methods
                        .map((method) => Text(
                              method,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startRazorpayPayment() async {
    String productId = Platform.isIOS ? iosPremiumPlanId : androidBasicPlanId;
    final ProductDetails? productDetails = productDetailsMap.value[productId];

    if (productDetails == null) {
      Get.dialog(
        SmartPopup(
          title: "Error",
          subTitle: "Product details not found. Please try again later.",
          primaryButtonText: "OK",
          primaryButtonTap: () => Get.back(),
          popType: PopType.error,
        ),
      );
      return;
    }

    try {
      print("Starting Razorpay payment for product: $productId");
      isProcessing.value = true;
      final razorpayKeyId = dotenv.env['razorpay_live_key_id'];
      if (razorpayKeyId == null || razorpayKeyId.isEmpty) {
        throw Exception("Razorpay key ID not found in .env file");
      }
      var options = {
        'key': razorpayKeyId,
        'amount': _parsePriceToPaise(productDetails.price),
        'name': 'Video Alarm Subscription',
        'prefill': {
          'contact': FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
          'email': FirebaseAuth.instance.currentUser?.email ?? '',
        },
        'notes': {'product_id': productId},
      };
      _razorpay.open(options);
    } catch (e) {
      print("Error initiating Razorpay payment: $e");
      isProcessing.value = false;
      Get.dialog(
        SmartPopup(
          title: "Payment Error",
          subTitle: "Failed to initiate payment: $e",
          primaryButtonText: "OK",
          primaryButtonTap: () => Get.back(),
          popType: PopType.error,
        ),
      );
    }
  }

  void _startInAppPurchase() async {
    String productId = Platform.isIOS ? iosPremiumPlanId : androidBasicPlanId;
    final ProductDetails? productDetails = productDetailsMap.value[productId];

    if (productDetails == null) {
      Get.dialog(
        SmartPopup(
          title: "Error",
          subTitle: "Product details not found. Please try again later.",
          primaryButtonText: "OK",
          primaryButtonTap: () => Get.back(),
          popType: PopType.error,
        ),
      );
      return;
    }

    try {
      print("Starting In-App Purchase for product: $productId");
      isProcessing.value = true;
      if (Platform.isIOS) {
        await inAppPurchase.buyConsumable(
            purchaseParam: PurchaseParam(productDetails: productDetails));
      } else {
        await inAppPurchase.buyNonConsumable(
            purchaseParam: PurchaseParam(productDetails: productDetails));
      }
    } catch (e) {
      print("Error initiating in-app purchase: $e");
      isProcessing.value = false;
      Get.dialog(
        SmartPopup(
          title: "Purchase Error",
          subTitle: "Failed to initiate purchase. Please try again.",
          primaryButtonText: "OK",
          primaryButtonTap: () => Get.back(),
          popType: PopType.error,
        ),
      );
    }
  }

  void _handleRazorpaySuccess(PaymentSuccessResponse response) async {
    try {
      print("PaymentSuccessResponse received:");
      print("  paymentId: ${response.paymentId}");
      print("  orderId: ${response.orderId}");
      print("  signature: ${response.signature}");

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print("No user logged in");
        isProcessing.value = false;
        throw Exception("No user logged in");
      }

      String productId = Platform.isIOS ? iosPremiumPlanId : androidBasicPlanId;
      DateTime purchaseDate = DateTime.now();
      DateTime expiryDate = _getSubscriptionExpiryDate(productId, purchaseDate);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final userData = userDoc.data() ?? {};

      if (response.paymentId == null) {
        throw Exception("Payment ID is null");
      }

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'Active': true,
        'SubscriptionType': productId,
        'SubscriptionStartDate': Timestamp.fromDate(purchaseDate),
        'SubscriptionExpiryDate': Timestamp.fromDate(expiryDate),
        'PurchaseToken': response.paymentId!,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': userData['createdAt'] ?? FieldValue.serverTimestamp(),
        'lastLogin': userData['lastLogin'] ?? FieldValue.serverTimestamp(),
        'name': userData['name'] ??
            FirebaseAuth.instance.currentUser?.displayName ??
            '',
        'phone': userData['phone'] ??
            FirebaseAuth.instance.currentUser?.phoneNumber ??
            '',
      }, SetOptions(merge: true));

      print("Successfully saved subscription to Firestore for user: $userId");

      await checkSubscriptionStatus();

      SubscriptionPlan? plan = SubscriptionPlan.getById(productId);
      final productDetails = productDetailsMap.value[productId];

      isProcessing.value = false;

      Get.dialog(
        SmartPopup(
          title: "Purchase Successful!",
          subTitle:
              'You are now subscribed to ${plan?.name ?? "plan"}.\nPayment ID: ${response.paymentId}',
          primaryButtonText: "OK",
          primaryButtonTap: () {
            Get.back();
            Get.offAll(() => BottomBarTabs());
          },
          popType: PopType.success,
        ),
      );
    } catch (e) {
      print("Subscription save error: $e");
      print("Stack trace: ${StackTrace.current}");
      isProcessing.value = false;
      Get.dialog(
        SmartPopup(
          title: "Error",
          subTitle: "Could not save subscription: $e. Please contact support.",
          primaryButtonText: "OK",
          primaryButtonTap: () => Get.back(),
          popType: PopType.error,
        ),
      );
    }
  }

  void _handleRazorpayError(PaymentFailureResponse response) {
    print("Razorpay payment error: ${response.message}");
    isProcessing.value = false;
    Get.dialog(
      SmartPopup(
        title: "Payment Failed",
        subTitle: response.message ?? "An error occurred during payment.",
        popType: PopType.error,
      ),
    );
  }

  int _parsePriceToPaise(String price) {
    String cleanPrice = price.replaceAll(RegExp(r'[^\d.]'), '');
    double priceInRupees = double.parse(cleanPrice);
    return (priceInRupees * 100).toInt();
  }

  Future<bool> verifyIOSPurchase(PurchaseDetails purchaseDetails) async {
    try {
      final String receiptData =
          purchaseDetails.verificationData.serverVerificationData;
      if (receiptData.isEmpty) {
        print("Empty receipt data");
        return false;
      }

      bool isValid = await _validateReceipt(receiptData, isSandbox: false);

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

  Future<bool> _validateReceipt(String receiptData,
      {required bool isSandbox}) async {
    final String url = isSandbox
        ? "https://sandbox.itunes.apple.com/verifyReceipt"
        : "https://buy.itunes.apple.com/verifyReceipt";

    final Map<String, dynamic> requestBody = {
      'receipt-data': receiptData,
      'password': 'fde1c8b51a044cd78dbe1bfa073dd77f',
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
        List<dynamic> inAppPurchases = result['latest_receipt_info'] ?? [];
        for (var purchase in inAppPurchases) {
          if (purchase['product_id'] == iosPremiumPlanId) {
            int expiresDateMs = int.parse(purchase['expires_date_ms'] ?? '0');
            DateTime expiryDate =
                DateTime.fromMillisecondsSinceEpoch(expiresDateMs);
            if (expiryDate.isAfter(DateTime.now())) {
              print(
                  "Found active subscription in ${isSandbox ? 'sandbox' : 'production'}: $purchase");
              return true;
            }
          }
        }
        print(
            "No active subscription found in ${isSandbox ? 'sandbox' : 'production'}");
        return false;
      } else if (result['status'] == 21007 && !isSandbox) {
        print(
            "Sandbox receipt used in production environment. Needs validation against sandbox.");
        return false;
      } else {
        print(
            "iOS purchase verification failed against ${isSandbox ? 'sandbox' : 'production'}: ${result['status']}");
        return false;
      }
    } catch (e) {
      print(
          "Error validating receipt against ${isSandbox ? 'sandbox' : 'production'}: $e");
      return false;
    }
  }

  Future<void> _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      try {
        print(
            "Purchase update: ${purchaseDetails.status} for ${purchaseDetails.productID}");

        if (purchaseDetails.status == PurchaseStatus.pending) {
          print("Purchase is pending");
          _showPendingUI();
        } else if (purchaseDetails.status == PurchaseStatus.error) {
          print("Purchase error: ${purchaseDetails.error?.message}");
          if (purchaseDetails.error?.code == 'itemAlreadyOwned') {
            print("Item already owned, treating as a restore");
            if (Platform.isIOS) {
              bool isValid = await verifyIOSPurchase(purchaseDetails);
              if (isValid) {
                await _handleSuccessfulPurchase(purchaseDetails);
              } else {
                _handleError(IAPError(
                  source: 'storekit',
                  code: 'invalid_receipt',
                  message: 'Invalid receipt for already owned item',
                ));
              }
            } else {
              await _handleSuccessfulPurchase(purchaseDetails);
            }
          } else {
            _handleError(purchaseDetails.error);
          }
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
    Get.dialog(
      SmartPopup(
        title: "Processing",
        subTitle: "Your payment is being processed. Please wait...",
        primaryButtonText: "",
        popType: PopType.info,
      ),
      barrierDismissible: false,
    );
  }

  void _handleError(IAPError? error) {
    print("Handling purchase error: ${error?.message}");
    isProcessing.value = false;
    String errorMessage = error?.message ?? "An unknown error occurred";

    Get.dialog(
      SmartPopup(
        buttonAlignment: ButtonAlignment.horizontal,
        title: "Purchase Failed",
        subTitle: errorMessage,
        primaryButtonText: "OK",
        primaryButtonTap: () {
          Get.back();
        },
        popType: PopType.error,
        animationType: AnimationType.scale,
      ),
    );
  }

  Future<void> _handleSuccessfulPurchase(
      PurchaseDetails purchaseDetails) async {
    print("Handling successful purchase for: ${purchaseDetails.productID}");
    bool isValid = true;

    DateTime purchaseDate = DateTime.now();
    DateTime expiryDate =
        _getSubscriptionExpiryDate(purchaseDetails.productID, purchaseDate);

    if (Platform.isIOS) {
      try {
        isValid = await verifyIOSPurchase(purchaseDetails);
        if (isValid && purchaseDetails.status == PurchaseStatus.restored) {
          final String receiptData =
              purchaseDetails.verificationData.serverVerificationData;
          final receiptInfo = await _getReceiptInfo(receiptData);
          if (receiptInfo != null) {
            purchaseDate = receiptInfo['purchaseDate'];
            expiryDate = receiptInfo['expiryDate'];
          } else {
            isValid = false;
          }
        } else if (isValid) {
          if (purchaseDetails.transactionDate != null) {
            int timestamp = int.parse(purchaseDetails.transactionDate!);
            purchaseDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          }
          expiryDate = _getSubscriptionExpiryDate(
              purchaseDetails.productID, purchaseDate);
        }
      } catch (e) {
        print("iOS verification error: $e");
        isValid = false;
      }
    } else {
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
      expiryDate =
          _getSubscriptionExpiryDate(purchaseDetails.productID, purchaseDate);
    }

    if (!isValid) {
      isProcessing.value = false;
      _handleError(IAPError(
        source: Platform.isIOS ? 'storekit' : 'playstore',
        code: 'invalid_purchase',
        message: 'Invalid purchase or receipt',
      ));
      return;
    }

    try {
      String purchaseToken = Platform.isIOS
          ? purchaseDetails.verificationData.localVerificationData
          : purchaseDetails.purchaseID ?? '';

      if (purchaseToken.isEmpty) {
        throw Exception("Purchase token is empty");
      }

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print("No user logged in");
        isProcessing.value = false;
        throw Exception("No user logged in");
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final userData = userDoc.data() ?? {};

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'Active': true,
        'SubscriptionType': purchaseDetails.productID,
        'SubscriptionStartDate': Timestamp.fromDate(purchaseDate),
        'SubscriptionExpiryDate': Timestamp.fromDate(expiryDate),
        'PurchaseToken': purchaseToken,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': userData['createdAt'] ?? FieldValue.serverTimestamp(),
        'lastLogin': userData['lastLogin'] ?? FieldValue.serverTimestamp(),
        'name': userData['name'] ??
            FirebaseAuth.instance.currentUser?.displayName ??
            '',
        'phone': userData['phone'] ??
            FirebaseAuth.instance.currentUser?.phoneNumber ??
            '',
      }, SetOptions(merge: true));

      print("Successfully saved subscription to Firestore for user: $userId");

      await checkSubscriptionStatus();

      SubscriptionPlan? plan =
          SubscriptionPlan.getById(purchaseDetails.productID);
      final productDetails = productDetailsMap.value[purchaseDetails.productID];

      String statusMessage = purchaseDetails.status == PurchaseStatus.purchased
          ? "Purchase Successful!"
          : "Subscription Restored!";

      isProcessing.value = false;

      Get.dialog(
        SmartPopup(
          buttonAlignment: ButtonAlignment.horizontal,
          title: statusMessage,
          subTitle:
              'You have successfully subscribed to ${plan?.name ?? "plan"} for ${productDetails?.price ?? "\₹99.00"}.',
          primaryButtonText: "OK",
          primaryButtonTap: () {
            Get.back();
            Get.offAll(() => BottomBarTabs());
          },
          popType: PopType.success,
          animationType: AnimationType.size,
        ),
      );
    } catch (e) {
      print("Error processing successful purchase: $e");
      print("Stack trace: ${StackTrace.current}");
      isProcessing.value = false;

      Get.dialog(
        SmartPopup(
          buttonAlignment: ButtonAlignment.horizontal,
          title: "Processing Error",
          subTitle: 'Could not save subscription: $e. Please contact support.',
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

  Future<Map<String, dynamic>?> _getReceiptInfo(String receiptData) async {
    final bool isSandbox = false;
    final String url = isSandbox
        ? "https://sandbox.itunes.apple.com/verifyReceipt"
        : "https://buy.itunes.apple.com/verifyReceipt";

    final Map<String, dynamic> requestBody = {
      'receipt-data': receiptData,
      'password': 'fde1c8b51a044cd78dbe1bfa073dd77f',
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
        return null;
      }

      final Map<String, dynamic> result = json.decode(response.body);

      if (result['status'] == 0) {
        List<dynamic> inAppPurchases = result['latest_receipt_info'] ?? [];
        for (var purchase in inAppPurchases) {
          if (purchase['product_id'] == iosPremiumPlanId) {
            int purchaseDateMs = int.parse(purchase['purchase_date_ms'] ?? '0');
            int expiresDateMs = int.parse(purchase['expires_date_ms'] ?? '0');
            return {
              'purchaseDate':
                  DateTime.fromMillisecondsSinceEpoch(purchaseDateMs),
              'expiryDate': DateTime.fromMillisecondsSinceEpoch(expiresDateMs),
            };
          }
        }
      } else if (result['status'] == 21007 && !isSandbox) {
        return await _getReceiptInfo(receiptData);
      }
      return null;
    } catch (e) {
      print("Error parsing receipt info: $e");
      return null;
    }
  }

  Future<void> _updateUserActiveStatus(String productId, String purchaseToken,
      DateTime purchaseDate, DateTime expiryDate) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print("No user logged in");
      throw Exception("No user logged in");
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final userData = userDoc.data() ?? {};

      if (purchaseToken.isEmpty) {
        throw Exception("Purchase token is empty");
      }

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'Active': true,
        'SubscriptionType': productId,
        'SubscriptionStartDate': Timestamp.fromDate(purchaseDate),
        'SubscriptionExpiryDate': Timestamp.fromDate(expiryDate),
        'PurchaseToken': purchaseToken,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': userData['createdAt'] ?? FieldValue.serverTimestamp(),
        'lastLogin': userData['lastLogin'] ?? FieldValue.serverTimestamp(),
        'name': userData['name'] ??
            FirebaseAuth.instance.currentUser?.displayName ??
            '',
        'phone': userData['phone'] ??
            FirebaseAuth.instance.currentUser?.phoneNumber ??
            '',
      }, SetOptions(merge: true));

      print("User subscription status updated in Firestore for user: $userId");
    } catch (e) {
      print("Error updating user subscription status: $e");
      print("Stack trace: ${StackTrace.current}");
      throw Exception("Failed to update user subscription status: $e");
    }
  }

  DateTime _getSubscriptionExpiryDate(String productId, DateTime purchaseDate) {
    SubscriptionPlan? plan = SubscriptionPlan.getById(productId);
    if (plan != null) {
      return purchaseDate.add(Duration(days: plan.durationInDays));
    }
    return purchaseDate.add(const Duration(days: 30));
  }

  Future<Map<String, dynamic>?> getCurrentSubscriptionDetails() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final sub = doc.data();
      if (sub != null && sub.containsKey('SubscriptionExpiryDate')) {
        final expiryDate =
            (sub['SubscriptionExpiryDate'] as Timestamp).toDate();
        final subscriptionType = sub['SubscriptionType'] ?? 'None';
        final isActive = DateTime.now().isBefore(expiryDate);

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

    return null;
  }

  String getSubscriptionDescription(String productId) {
    return SubscriptionPlan.getDescriptionById(productId);
  }

  Future<void> checkSubscriptionExpiry() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final sub = doc.data();
      if (sub != null && sub.containsKey('SubscriptionExpiryDate')) {
        final expiryDate =
            (sub['SubscriptionExpiryDate'] as Timestamp).toDate();
        if (DateTime.now().isAfter(expiryDate)) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'Active': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          nowactive.value = false;
          print("Subscription expired, set status to inactive");
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
      Get.dialog(
        SmartPopup(
          title: "Error",
          subTitle: "Could not open subscription settings.",
          primaryButtonText: "OK",
          primaryButtonTap: () => Get.back(),
          popType: PopType.error,
        ),
      );
    }
  }

  Future<void> restorePurchases() async {
    try {
      print("Attempting to restore purchases");
      isProcessing.value = true;
      await inAppPurchase.restorePurchases();
      await checkSubscriptionStatus();
      Get.snackbar("Done", "Subscription status refreshed.");
    } catch (e) {
      print("Error restoring purchases: $e");
      Get.dialog(
        SmartPopup(
          title: "Error",
          subTitle: "Failed to restore purchases. Please try again.",
          primaryButtonText: "OK",
          primaryButtonTap: () => Get.back(),
          popType: PopType.error,
        ),
      );
    } finally {
      print("Finished restorePurchases, resetting isProcessing");
      isProcessing.value = false;
    }
  }

  @override
  void onClose() {
    _razorpay.clear();
    super.onClose();
  }
}
