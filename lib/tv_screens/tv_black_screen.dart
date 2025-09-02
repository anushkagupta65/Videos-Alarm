import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_alarm_app/components/app_style.dart';
import 'package:videos_alarm_app/tv_screens/tv_login.dart';

class TVBuySubscription extends StatefulWidget {
  const TVBuySubscription({super.key});

  @override
  State<TVBuySubscription> createState() => _TVPaySubscriptionState();
}

class _TVPaySubscriptionState extends State<TVBuySubscription> {
  final FocusNode _changeAccountFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_changeAccountFocusNode);
    });
  }

  @override
  void dispose() {
    _changeAccountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _logoutAndRedirect() async {
    // Clear Firebase Auth and SharedPreferences
    await FirebaseAuth.instance.signOut();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isTestUser');
    // Navigate to TVLogInScreen
    Get.offAll(() => const TVLogInScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Uhh Ohhh...\n\nTo continue on the TV app,\nPlease subscribe from our mobile app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: whiteColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              Focus(
                focusNode: _changeAccountFocusNode,
                onKey: (node, event) {
                  if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.enter) {
                    _logoutAndRedirect();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Builder(builder: (context) {
                  final bool hasFocus = Focus.of(context).hasFocus;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: hasFocus
                        ? (Matrix4.identity()..scale(1.05))
                        : Matrix4.identity(),
                    transformAlignment: Alignment.center,
                    child: ElevatedButton(
                      onPressed: _logoutAndRedirect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: greenColor,
                        foregroundColor: blackColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: hasFocus ? 10 : 5,
                      ),
                      child: const Text(
                        'Log In with Another Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
