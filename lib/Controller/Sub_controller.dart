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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_popup/smart_popup.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:videos_alarm_app/Controller/sub.model.dart';
import 'package:videos_alarm_app/screens/banner_video_list.dart';
import 'package:videos_alarm_app/screens/confirmation_screen.dart';

class SubscriptionController extends GetxController {
  var isAvailable = false.obs;
  var isProcessing = false.obs;
  RxString subscriptionType = "".obs;

  late InAppPurchase inAppPurchase;
  Razorpay? _razorpay;
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
    if (Platform.isAndroid) {
      _razorpay = Razorpay();
      _razorpay?.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleRazorpaySuccess);
      _razorpay?.on(Razorpay.EVENT_PAYMENT_ERROR, _handleRazorpayError);
    }

    await _initializeBillingClient();
    await _checkAvailability();
    await loadProductDetails();
    await checkSubscriptionStatus();

    if (!nowactive.value) {
      print(
          "\n\n subscription controller ---- No active subscription, attempting to restore purchases");
      await restorePurchases();
    }

    final Stream<List<PurchaseDetails>> purchaseUpdated =
        inAppPurchase.purchaseStream;
    purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        print("\n\n subscription controller ---- Purchase stream done");
        isProcessing.value = false;
      },
      onError: (error) {
        print(
            "\n\n subscription controller ---- Error in purchase stream: $error");
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
      print(
          "\n\n subscription controller ---- Error checking subscription status: $e");
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

    if (Platform.isIOS) {
      _startInAppPurchase();
    } else {
      _showPaymentOptions();
    }
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
                      icon: Icons.store,
                      title: 'via In-App Purchase',
                      methods: const [
                        'BHIM UPI',
                        'Visa',
                        'Mastercard',
                        'PayPal',
                        'and more'
                      ],
                      onTap: () => _startInAppPurchase(),
                    ),
                    if (Platform.isAndroid) ...[
                      const SizedBox(height: 8),
                      _buildPaymentOption(
                        icon: Icons.payment,
                        title: 'via Razorpay',
                        methods: const [
                          'UPI',
                          'Paytm',
                          'Visa',
                          'Mastercard',
                          'and more'
                        ],
                        onTap: () => _startRazorpayPayment(),
                      ),
                    ],
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

  Future<void> _startRazorpayPayment() async {
    if (!Platform.isAndroid) {
      return; // Prevent Razorpay execution on non-Android platforms
    }

    String productId = androidBasicPlanId;
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
      print(
          "\n\n subscription controller ---- Starting Razorpay payment for product: $productId");
      print(
          "  Subscription price from productDetails: '${productDetails.price}'");
      int amountInPaise = _parsePriceToPaise(productDetails.price);
      print(
          "\n\n subscription controller ----   Calculated amount in paise for Razorpay: $amountInPaise");
      isProcessing.value = true;

      // Call the method to create a Razorpay order
      await _createRazorpayOrder(amountInPaise, productId);
    } catch (e) {
      print(
          "\n\n subscription controller ---- Error initiating Razorpay payment: $e");
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

  Future<void> _createRazorpayOrder(int amountInPaise, String productId) async {
    final razorpayKeyId = dotenv.env['razorpay_live_key_id'];
    final razorpayKeySecret = dotenv.env['razorpay_live_key_secret'];

    if (razorpayKeyId == null || razorpayKeyId.isEmpty) {
      throw Exception("Razorpay key ID not found");
    }
    if (razorpayKeySecret == null || razorpayKeySecret.isEmpty) {
      throw Exception("Razorpay key secret not found");
    }

    Map<String, dynamic> body = {
      "amount": amountInPaise, // Amount is already in paise
      "currency": "INR",
      "receipt": "receipt#$productId",
      "payment_capture": 1, // Ensures automatic capture
    };

    var response = await http.post(
      Uri.https("api.razorpay.com", "/v1/orders"),
      body: jsonEncode(body),
      headers: {
        'Content-Type': 'application/json',
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$razorpayKeyId:$razorpayKeySecret'))}',
      },
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      print(
          "\n\n subscription controller ---- Razorpay Order Creation Response: $responseData");
      // Extract the order_id from the response
      String orderId = responseData['id'];

      _openCheckout(orderId, amountInPaise, productId);
    } else {
      print(
          "\n\n subscription controller ---- Failed to create Razorpay order: ${response.body}");
      isProcessing.value = false;
      Get.dialog(
        SmartPopup(
          title: "Order Creation Error",
          subTitle: "Something went wrong while creating the order.",
          primaryButtonText: "OK",
          primaryButtonTap: () => Get.back(),
          popType: PopType.error,
        ),
      );
    }
  }

  void _openCheckout(String orderId, int amountInPaise, String productId) {
    final razorpayKeyId = dotenv.env['razorpay_live_key_id'];
    if (razorpayKeyId == null || razorpayKeyId.isEmpty) {
      isProcessing.value = false;
      Get.dialog(
        SmartPopup(
          title: "Error",
          subTitle: "Razorpay key not found.",
          primaryButtonText: "OK",
          primaryButtonTap: () => Get.back(),
          popType: PopType.error,
        ),
      );
      return;
    }

    var options = {
      'key': razorpayKeyId,
      'amount': amountInPaise,
      'name': 'Video Alarm Subscription',
      'description': 'Subscription for Video Alarm',
      'order_id': orderId,
      'prefill': {
        'contact': FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
        'email': FirebaseAuth.instance.currentUser?.email ?? '',
      },
      'notes': {'product_id': productId},
    };

    try {
      print(
          "\n\n subscription controller ---- Opening Razorpay Checkout with options: $options");
      _razorpay?.open(options);
    } catch (e) {
      print(
          "\n\n subscription controller ---- Error opening Razorpay Checkout: $e");
      isProcessing.value = false;
      Get.dialog(
        SmartPopup(
          title: "Checkout Error",
          subTitle: "Failed to open payment checkout: $e",
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
      print(
          "\n\n subscription controller ---- Starting In-App Purchase for product: $productId");
      isProcessing.value = true;
      if (Platform.isIOS) {
        await inAppPurchase.buyConsumable(
            purchaseParam: PurchaseParam(productDetails: productDetails));
      } else {
        await inAppPurchase.buyNonConsumable(
            purchaseParam: PurchaseParam(productDetails: productDetails));
      }
    } catch (e) {
      print(
          "\n\n subscription controller ---- Error initiating in-app purchase: $e");
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
      print(
          "\n\n subscription controller ---- PaymentSuccessResponse received:");
      print(
          "\n\n subscription controller ----   paymentId: ${response.paymentId}");
      print("\n\n subscription controller ----   orderId: ${response.orderId}");
      print(
          "\n\n subscription controller ----   signature: ${response.signature}");

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print("\n\n subscription controller ---- No user logged in");
        isProcessing.value = false;
        throw Exception("No user logged in");
      }

      String productId = androidBasicPlanId;
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
        'releaseDate': userData['releaseDate'] ?? FieldValue.serverTimestamp(),
        'lastLogin': userData['lastLogin'] ?? FieldValue.serverTimestamp(),
        'name': userData['name'] ??
            FirebaseAuth.instance.currentUser?.displayName ??
            '',
        'phone': userData['phone'] ??
            FirebaseAuth.instance.currentUser?.phoneNumber ??
            '',
      }, SetOptions(merge: true));

      print(
          "\n\n subscription controller ---- Successfully saved subscription to Firestore for user: $userId");

      await checkSubscriptionStatus();

      SubscriptionPlan? plan = SubscriptionPlan.getById(productId);

      isProcessing.value = false;

      Get.dialog(
        SmartPopup(
          title: "Purchase Successful!",
          subTitle:
              'You are now subscribed to ${plan?.name ?? "plan"}.\nPayment ID: ${response.paymentId}',
          primaryButtonText: "OK",
          primaryButtonTap: () {
            Get.back();
            Get.offAll(() => Confirmation());
          },
          popType: PopType.success,
        ),
      );
    } catch (e) {
      print("\n\n subscription controller ---- Subscription save error: $e");
      print(
          "\n\n subscription controller ---- Stack trace: ${StackTrace.current}");
      isProcessing.value = false;
      Get.dialog(
        SmartPopup(
          title: "Error",
          subTitle: "$e",
          primaryButtonText: "OK",
          primaryButtonTap: () => Get.back(),
          popType: PopType.error,
        ),
      );
    }
  }

  void _handleRazorpayError(PaymentFailureResponse response) {
    print(
        "\n\n subscription controller ---- Razorpay payment error: ${response.message}");
    isProcessing.value = false;
    // Get.dialog(
    //   SmartPopup(
    //     title: "Payment Failed",
    //     subTitle: response.message ?? "An error occurred during payment.",
    //     popType: PopType.error,
    //   ),
    // );
  }

  int _parsePriceToPaise(String price) {
    print(
        "\n\n subscription controller ---- Parsing price for subscription amount verification:");
    print("\n\n subscription controller ----   Input price string: '$price'");
    String cleanPrice = price.replaceAll(RegExp(r'[^\d.]'), '');
    print(
        "\n\n subscription controller ----   Cleaned price string: '$cleanPrice'");
    double priceInRupees = double.parse(cleanPrice);
    print(
        "\n\n subscription controller ----   Parsed price in rupees: $priceInRupees");
    int priceInPaise = (priceInRupees * 100).toInt();
    print(
        "\n\n subscription controller ----   Final price in paise: $priceInPaise");
    return priceInPaise;
  }

  Future<bool> verifyIOSPurchase(PurchaseDetails purchaseDetails) async {
    try {
      final String receiptData =
          purchaseDetails.verificationData.serverVerificationData;
      if (receiptData.isEmpty) {
        print("\n\n subscription controller ---- Empty receipt data");
        return false;
      }

      bool isValid = await _validateReceipt(receiptData, isSandbox: false);

      if (!isValid) {
        print(
            "\n\n subscription controller ---- Production validation failed. Attempting sandbox validation.");
        isValid = await _validateReceipt(receiptData, isSandbox: true);
      }

      return isValid;
    } catch (e) {
      print(
          "\n\n subscription controller ---- Error verifying iOS purchase: $e");
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
        print(
            "\n\n subscription controller ---- HTTP error: ${response.statusCode}");
        print(
            "\n\n subscription controller ---- Response body: ${response.body}");
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
          print("\n\n subscription controller ---- Purchase is pending");
          _showPendingUI();
        } else if (purchaseDetails.status == PurchaseStatus.error) {
          print(
              "\n\n subscription controller ---- Purchase error: ${purchaseDetails.error?.message}");
          if (purchaseDetails.error?.code == 'itemAlreadyOwned') {
            print(
                "\n\n subscription controller ---- Item already owned, treating as a restore");
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
          print(
              "\n\n subscription controller ---- Purchase successful or restored");
          await _handleSuccessfulPurchase(purchaseDetails);
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          print("\n\n subscription controller ---- Purchase canceled");
          isProcessing.value = false;
        }

        if (purchaseDetails.pendingCompletePurchase) {
          print("\n\n subscription controller ---- Completing purchase");
          await inAppPurchase.completePurchase(purchaseDetails);
        }
      } catch (e) {
        print(
            "\n\n subscription controller ---- Error processing purchase update: $e");
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
    print(
        "\n\n subscription controller ---- Handling purchase error: ${error?.message}");
    isProcessing.value = false;
    String errorMessage = error?.message ?? "An unknown error occurred";

  }

  Future<void> _handleSuccessfulPurchase(
      PurchaseDetails purchaseDetails) async {
    print(
        "\n\n subscription controller ---- Handling successful purchase for: ${purchaseDetails.productID}");
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
        print("\n\n subscription controller ---- iOS verification error: $e");
        isValid = false;
      }
    } else {
      try {
        if (purchaseDetails.transactionDate != null) {
          int timestamp = int.parse(purchaseDetails.transactionDate!);
          purchaseDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else {
          print(
              "\n\n subscription controller ---- Transaction date is null, using current time");
          purchaseDate = DateTime.now();
        }
      } catch (e) {
        print(
            "\n\n subscription controller ---- Error parsing transaction date: $e, using current time");
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
        print("\n\n subscription controller ---- No user logged in");
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
        'releaseDate': userData['releaseDate'] ?? FieldValue.serverTimestamp(),
        'lastLogin': userData['lastLogin'] ?? FieldValue.serverTimestamp(),
        'name': userData['name'] ??
            FirebaseAuth.instance.currentUser?.displayName ??
            '',
        'phone': userData['phone'] ??
            FirebaseAuth.instance.currentUser?.phoneNumber ??
            '',
      }, SetOptions(merge: true));

      print(
          "\n\n subscription controller ---- Successfully saved subscription to Firestore for user: $userId");

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
      print(
          "\n\n subscription controller ---- Error processing successful purchase: $e");
      print(
          "\n\n subscription controller ---- Stack trace: ${StackTrace.current}");
      isProcessing.value = false;

      Get.dialog(
        SmartPopup(
          buttonAlignment: ButtonAlignment.horizontal,
          title: "Processing Error",
          subTitle: '$e',
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
        print(
            "\n\n subscription controller ---- HTTP error: ${response.statusCode}");
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
      print("\n\n subscription controller ---- Error parsing receipt info: $e");
      return null;
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
      print(
          "\n\n subscription controller ---- Error getting subscription details: $e");
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
          print(
              "\n\n subscription controller ---- Subscription expired, set status to inactive");
        }
      }
    } catch (e) {
      print(
          "\n\n subscription controller ---- Error checking subscription expiry: $e");
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
    // Check if the user is a test user via SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isTestUser = prefs.getBool('isTestUser') ?? false;

    // Skip restoration for test user
    if (isTestUser) {
      print(
          "\n\n subscription controller ---- Test user detected, skipping purchase restoration");
      isProcessing.value = false; // Reset processing state
      return;
    }

    try {
      print(
          "\n\n subscription controller ---- Attempting to restore purchases");
      isProcessing.value = true;
      await inAppPurchase.restorePurchases();
      await checkSubscriptionStatus();
    } catch (e) {
      print("\n\n subscription controller ---- Error restoring purchases: $e");
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
      print(
          "\n\n subscription controller ---- Finished restorePurchases, resetting isProcessing");
      isProcessing.value = false;
    }
  }

  @override
  void onClose() {
    _razorpay?.clear();
    super.onClose();
  }
}

// import 'dart:convert';
// import 'dart:io';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:in_app_purchase/in_app_purchase.dart';
// import 'package:intl/intl.dart';
// import 'package:smart_popup/smart_popup.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:videos_alarm_app/Controller/sub.model.dart';
// import 'package:videos_alarm_app/screens/banner_video_list.dart';

// class SubscriptionController extends GetxController {
//   var isAvailable = false.obs;
//   var isProcessing = false.obs;
//   RxString subscriptionType = "".obs;

//   late InAppPurchase inAppPurchase;
//   var nowactive = true.obs;
//   RxString planName = 'Unknown Plan'.obs;
//   RxString price = '\₹99.00'.obs;

//   final Rx<Map<String, ProductDetails>> productDetailsMap =
//       Rx<Map<String, ProductDetails>>({});

//   // Product IDs for both platforms
//   static const String androidBasicPlanId = 'vip_plan_id';
//   static const String iosPremiumPlanId = 'com.videosalarm.subscription.premium';

//   @override
//   void onInit() async {
//     super.onInit();
//     inAppPurchase = InAppPurchase.instance;
//     await _initializeBillingClient();
//     await _checkAvailability();
//     await loadProductDetails();
//     await getDetails();

//     final Stream<List<PurchaseDetails>> purchaseUpdated =
//         inAppPurchase.purchaseStream;
//     purchaseUpdated.listen(
//       (purchaseDetailsList) {
//         _listenToPurchaseUpdated(purchaseDetailsList);
//       },
//       onDone: () {
//         print("\n\n subscription controller ---- Purchase stream done");
//       },
//       onError: (error) {
//         print(
//             "\n\n subscription controller ---- Error in purchase stream: $error");
//         isProcessing.value = false;
//       },
//     );
//   }

//   Future<void> _initializeBillingClient() async {
//     try {
//       final isBillingAvailable = await inAppPurchase.isAvailable();
//       print('Billing client available: $isBillingAvailable');
//       if (!isBillingAvailable) {
//         print('Billing client is not available');
//         return;
//       }
//     } catch (e) {
//       print('Error initializing billing client: $e');
//     }
//   }

//   Future<void> _checkAvailability() async {
//     try {
//       isAvailable.value = await inAppPurchase.isAvailable();
//       print('In-app purchase available: ${isAvailable.value}');
//     } catch (e) {
//       print('Error checking availability: $e');
//     }
//   }

//   Future<void> loadProductDetails() async {
//     final Set<String> productIds = {
//       Platform.isIOS ? iosPremiumPlanId : androidBasicPlanId,
//     };

//     try {
//       print('Querying product details for: $productIds');
//       final ProductDetailsResponse response =
//           await inAppPurchase.queryProductDetails(productIds);

//       if (response.notFoundIDs.isNotEmpty) {
//         print('Products not found: ${response.notFoundIDs}');
//       }

//       if (response.productDetails.isEmpty) {
//         print('No product details found');
//         return;
//       }

//       final Map<String, ProductDetails> detailsMap = {
//         for (var detail in response.productDetails) detail.id: detail
//       };
//       productDetailsMap.value = detailsMap;

//       for (var detail in response.productDetails) {
//         print('Product ID: ${detail.id}');
//         print('Product Title: ${detail.title}');
//         print('Product Description: ${detail.description}');
//         print('Product Price: ${detail.price}');
//       }
//     } catch (e) {
//       print('Error loading product details: $e');
//     }
//   }

//   Future<void> getDetails() async {
//     try {
//       User? currentUser = FirebaseAuth.instance.currentUser;
//       if (currentUser == null) {
//         print("\n\n subscription controller ---- No user is logged in");
//         return;
//       }

//       String userId = currentUser.uid;
//       DocumentSnapshot userDoc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(userId)
//           .get();

//       if (userDoc.exists) {
//         Map<String, dynamic>? userData =
//             userDoc.data() as Map<String, dynamic>?;
//         if (userData != null) {
//           subscriptionType.value = userData['SubscriptionType'] ?? 'None';
//           print(
//               "\n\n subscription controller ---- Current subscription type: ${subscriptionType.value}");

//           if (userData['Active'] == true) {
//             nowactive.value = true;

//             // Get plan details
//             SubscriptionPlan? plan =
//                 SubscriptionPlan.getById(subscriptionType.value);
//             planName.value = plan?.name ?? 'Unknown Plan';

//             // Get price from product details if available
//             final productDetails =
//                 productDetailsMap.value[subscriptionType.value];
//             price.value = productDetails?.price ?? '\₹99.00';
//           } else {
//             nowactive.value = false;
//           }
//         }
//       } else {
//         print("\n\n subscription controller ---- User document does not exist");
//       }
//     } catch (e) {
//       print(
//           "\n\n subscription controller ---- Error getting subscription details: $e");
//     }
//   }

//   Future<void> purchaseSubscription() async {
//     if (!isAvailable.value) {
//       // Get.snackbar("Error", "In-app purchase is not available");
//       return;
//     }

//     String productId = Platform.isIOS ? iosPremiumPlanId : androidBasicPlanId;
//     final ProductDetails? productDetails = productDetailsMap.value[productId];

//     if (productDetails == null) {
//       // Get.snackbar("Error", "Product details not found. Please try again later.");
//       return;
//     }

//     try {
//       isProcessing.value = true;

//       // For iOS, we need to use different purchase method
//       if (Platform.isIOS) {
//         await inAppPurchase.buyConsumable(
//             purchaseParam: PurchaseParam(productDetails: productDetails));
//       } else {
//         await inAppPurchase.buyNonConsumable(
//             purchaseParam: PurchaseParam(productDetails: productDetails));
//       }

//       // Don't set isProcessing to false here, it will be set in the purchase listener
//     } catch (e) {
//       isProcessing.value = false;
//       print("\n\n subscription controller ---- Error initiating purchase: $e");
//       // Get.snackbar("Purchase Error", "Failed to initiate purchase. Please try again.");
//     }
//   }

//   Future<bool> verifyIOSPurchase(PurchaseDetails purchaseDetails) async {
//     try {
//       final String receiptData =
//           purchaseDetails.verificationData.serverVerificationData;
//       if (receiptData.isEmpty) {
//         print("\n\n subscription controller ---- Empty receipt data");
//         return false;
//       }

//       // DEVELOPMENT MODE: Uncomment for testing and comment out for production
//       // print("\n\n subscription controller ---- Development mode: Skipping receipt validation");
//       // return true;

//       // PRODUCTION MODE: Validate receipt with Apple's servers
//       bool isValid = await _validateReceipt(receiptData, isSandbox: false);

//       // If validation fails with "Sandbox receipt used in production," validate against the test environment
//       if (!isValid) {
//         print(
//             "\n\n subscription controller ---- Production validation failed. Attempting sandbox validation.");
//         isValid = await _validateReceipt(receiptData, isSandbox: true);
//       }

//       return isValid;
//     } catch (e) {
//       print(
//           "\n\n subscription controller ---- Error verifying iOS purchase: $e");
//       return false;
//     }
//   }

//   Future<bool> _validateReceipt(String receiptData,
//       {required bool isSandbox}) async {
//     final String url = isSandbox
//         ? "https://sandbox.itunes.apple.com/verifyReceipt"
//         : "https://buy.itunes.apple.com/verifyReceipt";

//     final Map<String, dynamic> requestBody = {
//       'receipt-data': receiptData,
//       'password':
//           'fde1c8b51a044cd78dbe1bfa073dd77f', // Replace with your App Store Connect shared secret
//       'exclude-old-transactions': true
//     };

//     try {
//       final http.Response response = await http.post(
//         Uri.parse(url),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode(requestBody),
//       );

//       if (response.statusCode != 200) {
//         print(
//             "\n\n subscription controller ---- HTTP error: ${response.statusCode}");
//         print(
//             "\n\n subscription controller ---- Response body: ${response.body}");
//         return false;
//       }

//       final Map<String, dynamic> result = json.decode(response.body);

//       if (result['status'] == 0) {
//         print(
//             "iOS purchase verified successfully against ${isSandbox ? 'sandbox' : 'production'}: $result");
//         return true;
//       } else if (result['status'] == 21007 && !isSandbox) {
//         print(
//             "Sandbox receipt used in production environment. Needs validation against sandbox.");
//         return false; // Signal to try sandbox.
//       } else {
//         print(
//             "iOS purchase verification failed against ${isSandbox ? 'sandbox' : 'production'}: ${result['status']}");
//         return false;
//       }
//     } catch (e) {
//       print(
//           "Error validating receipt against ${isSandbox ? 'sandbox' : 'production'}: $e");
//       return false;
//     }
//   }

//   Future<void> _listenToPurchaseUpdated(
//       List<PurchaseDetails> purchaseDetailsList) async {
//     for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
//       try {
//         print(
//             "Purchase update: ${purchaseDetails.status} for ${purchaseDetails.productID}");

//         if (purchaseDetails.status == PurchaseStatus.pending) {
//           print("\n\n subscription controller ---- Purchase is pending");
//           _showPendingUI();
//         } else if (purchaseDetails.status == PurchaseStatus.error) {
//           print(
//               "\n\n subscription controller ---- Purchase error: ${purchaseDetails.error?.message}");
//           _handleError(purchaseDetails.error);
//         } else if (purchaseDetails.status == PurchaseStatus.purchased ||
//             purchaseDetails.status == PurchaseStatus.restored) {
//           print(
//               "\n\n subscription controller ---- Purchase successful or restored");
//           await _handleSuccessfulPurchase(purchaseDetails);
//         } else if (purchaseDetails.status == PurchaseStatus.canceled) {
//           print("\n\n subscription controller ---- Purchase canceled");
//           isProcessing.value = false;
//         }

//         if (purchaseDetails.pendingCompletePurchase) {
//           print("\n\n subscription controller ---- Completing purchase");
//           await inAppPurchase.completePurchase(purchaseDetails);
//         }
//       } catch (e) {
//         print(
//             "\n\n subscription controller ---- Error processing purchase update: $e");
//         isProcessing.value = false;
//       }
//     }
//   }

//   void _showPendingUI() {}

//   void _handleError(IAPError? error) {
//     isProcessing.value = false;
//     String errorMessage = error?.message ?? "An unknown error occurred";
//     print("\n\n subscription controller ---- Purchase error: $errorMessage");

//     Get.dialog(
//       SmartPopup(
//         buttonAlignment: ButtonAlignment.horizontal,
//         title: "Purchase Failed",
//         subTitle: errorMessage,
//         primaryButtonText: "OK",
//         popType: PopType.error,
//         animationType: AnimationType.scale,
//         primaryButtonTap: () {
//           Get.back();
//         },
//       ),
//     );
//   }

//   Future<void> _handleSuccessfulPurchase(
//       PurchaseDetails purchaseDetails) async {
//     bool isValid = true;

//     if (Platform.isIOS) {
//       try {
//         isValid = await verifyIOSPurchase(purchaseDetails);
//       } catch (e) {
//         print("\n\n subscription controller ---- iOS verification error: $e");
//         isProcessing.value = false;
//         return;
//       }
//     }

//     if (!isValid) {
//       isProcessing.value = false;
//       return;
//     }

//     try {
//       DateTime purchaseDate;
//       try {
//         if (purchaseDetails.transactionDate != null) {
//           int timestamp = int.parse(purchaseDetails.transactionDate!);
//           purchaseDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
//         } else {
//           print(
//               "\n\n subscription controller ---- Transaction date is null, using current time");
//           purchaseDate = DateTime.now();
//         }
//       } catch (e) {
//         print(
//             "\n\n subscription controller ---- Error parsing transaction date: $e, using current time");
//         purchaseDate = DateTime.now();
//       }

//       DateTime expiryDate =
//           _getSubscriptionExpiryDate(purchaseDetails.productID, purchaseDate);

//       String purchaseToken = Platform.isIOS
//           ? purchaseDetails.verificationData.localVerificationData
//           : purchaseDetails.purchaseID ?? '';

//       await _updateUserActiveStatus(
//         purchaseDetails.productID,
//         purchaseToken,
//         purchaseDate,
//         expiryDate,
//       );

//       await getDetails(); // Refresh subscription details

//       SubscriptionPlan? plan =
//           SubscriptionPlan.getById(purchaseDetails.productID);
//       final productDetails = productDetailsMap.value[purchaseDetails.productID];

//       String statusMessage = purchaseDetails.status == PurchaseStatus.purchased
//           ? "Purchase Successful!"
//           : "Subscription Restored!";

//       isProcessing.value = false;

//       Get.dialog(
//         SmartPopup(
//           buttonAlignment: ButtonAlignment.horizontal,
//           title: statusMessage,
//           subTitle:
//               'You have successfully subscribed to ${plan?.name ?? "plan"} for ${productDetails?.price ?? "\₹99.00"}.',
//           primaryButtonText: "OK",
//           primaryButtonTap: () {
//             Get.back();
//             // Navigate to main screen only after user acknowledges the success
//             Get.offAll(() => BottomBarTabs());
//           },
//           popType: PopType.success,
//           animationType: AnimationType.size,
//         ),
//       );
//     } catch (e) {
//       print(
//           "\n\n subscription controller ---- Error processing successful purchase: $e");
//       isProcessing.value = false;

//       Get.dialog(
//         SmartPopup(
//           buttonAlignment: ButtonAlignment.horizontal,
//           title: "Processing Error",
//           subTitle:
//               'An error occurred while processing your subscription. Please contact support.',
//           primaryButtonText: "OK",
//           primaryButtonTap: () {
//             Get.back();
//           },
//           popType: PopType.error,
//           animationType: AnimationType.scale,
//         ),
//       );
//     }
//   }

//   Future<void> _updateUserActiveStatus(String productId, String purchaseToken,
//       DateTime purchaseDate, DateTime expiryDate) async {
//     User? currentUser = FirebaseAuth.instance.currentUser;

//     if (currentUser != null) {
//       String userId = currentUser.uid;

//       try {
//         DocumentSnapshot userDoc = await FirebaseFirestore.instance
//             .collection('users')
//             .doc(userId)
//             .get();

//         if (userDoc.exists) {
//           await FirebaseFirestore.instance
//               .collection('users')
//               .doc(userId)
//               .update({
//             'Active': true,
//             'SubscriptionStartDate': purchaseDate,
//             'SubscriptionExpiryDate': expiryDate,
//             'SubscriptionType': productId,
//             'PurchaseToken': purchaseToken,
//             'updatedAt': FieldValue.serverTimestamp(),
//           });
//           print(
//               "\n\n subscription controller ---- User status updated in Firestore");
//         } else {
//           print("\n\n subscription controller ---- User document not found");
//           await FirebaseFirestore.instance.collection('users').doc(userId).set({
//             'Active': true,
//             'SubscriptionStartDate': purchaseDate,
//             'SubscriptionExpiryDate': expiryDate,
//             'SubscriptionType': productId,
//             'PurchaseToken': purchaseToken,
//             'userId': userId,
//             'releaseDate': FieldValue.serverTimestamp(),
//             'updatedAt': FieldValue.serverTimestamp(),
//           });
//           print(
//               "\n\n subscription controller ---- Created new user document with subscription info");
//         }
//       } catch (e) {
//         print(
//             "\n\n subscription controller ---- Error updating user status: $e");
//         throw Exception("Failed to update user status: $e");
//       }
//     } else {
//       print("\n\n subscription controller ---- No user logged in");
//       throw Exception("No user logged in");
//     }
//   }

//   DateTime _getSubscriptionExpiryDate(String productId, DateTime purchaseDate) {
//     SubscriptionPlan? plan = SubscriptionPlan.getById(productId);
//     if (plan != null) {
//       return purchaseDate.add(Duration(days: plan.durationInDays));
//     }
//     return purchaseDate.add(const Duration(days: 365)); // Default to 1 year
//   }

//   Future<Map<String, dynamic>?> getCurrentSubscriptionDetails() async {
//     User? currentUser = FirebaseAuth.instance.currentUser;

//     if (currentUser != null) {
//       String userId = currentUser.uid;

//       try {
//         DocumentSnapshot userDoc = await FirebaseFirestore.instance
//             .collection('users')
//             .doc(userId)
//             .get();

//         if (userDoc.exists) {
//           Map<String, dynamic>? userData =
//               userDoc.data() as Map<String, dynamic>?;
//           if (userData == null) return null;

//           if (!userData.containsKey('SubscriptionExpiryDate')) {
//             return null; // No subscription data
//           }

//           DateTime expiryDate =
//               (userData['SubscriptionExpiryDate'] as Timestamp).toDate();
//           String subscriptionType = userData['SubscriptionType'] ?? 'None';
//           bool isActive = userData['Active'] ?? false;

//           final productDetails = productDetailsMap.value[subscriptionType];
//           SubscriptionPlan? plan = SubscriptionPlan.getById(subscriptionType);

//           planName.value = plan?.name ?? 'No Subscription';
//           price.value = productDetails?.price ?? '\₹99.00';

//           if (isActive) {
//             return {
//               'planName': planName.value,
//               'price': price.value,
//               'description': getSubscriptionDescription(subscriptionType),
//               'expiryDate': DateFormat('yyyy-MM-dd').format(expiryDate),
//             };
//           }
//         }
//       } catch (e) {
//         print(
//             "\n\n subscription controller ---- Error getting subscription details: $e");
//       }
//     }

//     return null;
//   }

//   String getSubscriptionDescription(String productId) {
//     return SubscriptionPlan.getDescriptionById(productId);
//   }

//   Future<void> checkSubscriptionExpiry() async {
//     try {
//       User? currentUser = FirebaseAuth.instance.currentUser;
//       if (currentUser != null) {
//         String userId = currentUser.uid;
//         DocumentSnapshot userDoc = await FirebaseFirestore.instance
//             .collection('users')
//             .doc(userId)
//             .get();

//         if (userDoc.exists) {
//           Map<String, dynamic>? userData =
//               userDoc.data() as Map<String, dynamic>?;
//           if (userData == null) return;

//           if (userData.containsKey('SubscriptionExpiryDate')) {
//             DateTime expiryDate =
//                 (userData['SubscriptionExpiryDate'] as Timestamp).toDate();
//             if (DateTime.now().isAfter(expiryDate)) {
//               await FirebaseFirestore.instance
//                   .collection('users')
//                   .doc(userId)
//                   .update({
//                 'Active': false,
//                 'updatedAt': FieldValue.serverTimestamp(),
//               });
//               nowactive.value = false;
//               print(
//                   "\n\n subscription controller ---- Subscription expired, set Active to false");
//             }
//           }
//         }
//       }
//     } catch (e) {
//       print(
//           "\n\n subscription controller ---- Error checking subscription expiry: $e");
//     }
//   }

//   Future<void> openCancellationPage() async {
//     String url = '';
//     if (Platform.isIOS) {
//       url = 'itms-apps://apps.apple.com/account/subscriptions';
//     } else if (Platform.isAndroid) {
//       url = 'https://play.google.com/store/account/subscriptions';
//     }

//     try {
//       if (await canLaunchUrl(Uri.parse(url))) {
//         await launchUrl(Uri.parse(url));
//       } else {
//         throw 'Could not launch $url';
//       }
//     } catch (e) {
//       print('Error opening cancellation page: $e');
//       // Get.snackbar("Error", "Could not open subscription settings.");
//     }
//   }

//   Future<void> restorePurchases() async {
//     try {
//       print(
//           "\n\n subscription controller ---- Attempting to restore purchases");
//       isProcessing.value = true;
//       await inAppPurchase.restorePurchases();
//     } catch (e) {
//       isProcessing.value = false;
//       print("\n\n subscription controller ---- Error restoring purchases: $e");
//     }
//   }
// }
