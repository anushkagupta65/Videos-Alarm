import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videos_alarm_app/login_screen/register.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';
import 'package:videos_alarm_app/screens/check_subs_controller.dart';
import 'package:videos_alarm_app/tv_screens/tv_black_screen.dart';
import 'package:videos_alarm_app/tv_screens/tv_bottom_bar_tabs.dart';
import '../components/app_style.dart';
import '../components/constant.dart';

class TVLogInScreen extends StatefulWidget {
  const TVLogInScreen({Key? key}) : super(key: key);

  @override
  State<TVLogInScreen> createState() => _TVLogInScreenState();
}

class _TVLogInScreenState extends State<TVLogInScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool agreeTcs = false;
  bool isOtpSent = false;
  String? phoneErrorText;

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _termsFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();
  final FocusNode _submitFocusNode = FocusNode();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final VideoController videoController = Get.put(VideoController());

  bool _isKeyboardVisible = false;
  TextEditingController? _activeController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_phoneFocusNode);
    });
  }

  @override
  void dispose() {
    phoneController.dispose();
    otpController.dispose();
    _phoneFocusNode.dispose();
    _termsFocusNode.dispose();
    _otpFocusNode.dispose();
    _submitFocusNode.dispose();
    super.dispose();
  }

  void _showKeyboardFor(TextEditingController controller) {
    setState(() {
      _isKeyboardVisible = true;
      _activeController = controller;
    });
  }

  void _hideKeyboard() {
    if (!_isKeyboardVisible) return;
    setState(() {
      _isKeyboardVisible = false;
      if (isOtpSent) {
        _otpFocusNode.requestFocus();
      } else {
        _phoneFocusNode.requestFocus();
      }
    });
  }

  void _validatePhoneNumber(String value) {
    String? validator(String? val) {
      if (val == null || val.isEmpty) return "Enter phone number";
      if (!RegExp(r'^\d{10}$').hasMatch(val)) {
        return "Enter a valid 10-digit phone number";
      }
      return null;
    }

    setState(() => phoneErrorText = validator(value));
  }

  String get _otpFromInput => otpController.text;

  Future<bool> checkUserExists(String phoneNumber) async {
    setState(() {
      isLoading = true;
    });

    if (phoneNumber == '1000000000') {
      setState(() {
        isLoading = false;
      });
      return true;
    }

    const String apiUrl = 'http://165.22.215.103:3066/checkUserExists';
    Map<String, String> headers = {'Content-Type': 'application/json'};
    Map<String, dynamic> body = {'phone': phoneNumber};

    try {
      final response = await http.post(Uri.parse(apiUrl),
          headers: headers, body: jsonEncode(body));
      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return responseData['exists'] ?? false;
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage =
            errorBody['message'] ?? 'Failed to check user existence';
        commToast('Error checking user: $errorMessage');
        return false;
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      commToast('Error checking user: Please try again.');
      print('Error checking user existence: $e');
      return false;
    }
  }

  Future<void> sendOtpForLogin(String phoneNumber) async {
    setState(() {
      isLoading = true;
    });

    if (phoneNumber == '1000000000') {
      setState(() {
        isOtpSent = true;
        isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_otpFocusNode);
      });
      commToast('OTP sent to $phoneNumber (Simulated)');
      return;
    }

    const String apiUrl = 'http://165.22.215.103:3066/sendOtp';
    Map<String, String> headers = {'Content-Type': 'application/json'};
    Map<String, dynamic> body = {'phone': phoneNumber};

    try {
      final response = await http.post(Uri.parse(apiUrl),
          headers: headers, body: jsonEncode(body));
      if (response.statusCode == 200) {
        setState(() {
          isOtpSent = true;
          isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(context).requestFocus(_otpFocusNode);
        });
        commToast('OTP sent to $phoneNumber');
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? 'Failed to send OTP';
        throw Exception(errorMessage);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      commToast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> verifyOtpAndSignIn() async {
    final String otp = _otpFromInput;
    final String phone = phoneController.text.trim();

    if (otp.length != 6) {
      commToast('Please enter the 6-digit OTP');
      return;
    }

    setState(() {
      isLoading = true;
    });

    if (phone == '1000000000' && otp == '000000') {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isTestUser', true);
      setState(() {
        isLoading = false;
      });
      commToast('Login Successful! (Simulated)');

      SubscriptionService subscriptionService = SubscriptionService();
      await subscriptionService.checkSubscriptionStatus();
      if (videoController.isUserActive.value) {
        Get.offAll(() => const TVBottomBarTabs(initialIndex: 0));
      } else {
        Get.offAll(() => const TVBuySubscription());
      }

      return;
    }

    const String apiUrl = 'http://165.22.215.103:3066/verifyOtp';
    Map<String, String> headers = {'Content-Type': 'application/json'};
    Map<String, dynamic> body = {'phone': phone, 'otp': otp};

    try {
      final response = await http.post(Uri.parse(apiUrl),
          headers: headers, body: jsonEncode(body));
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        String customToken = responseData['token'];
        UserCredential userCredential =
            await _auth.signInWithCustomToken(customToken);
        User? user = userCredential.user;

        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'lastLogin': FieldValue.serverTimestamp()});

          setState(() {
            isLoading = false;
          });

          SubscriptionService subscriptionService = SubscriptionService();
          await subscriptionService.checkSubscriptionStatus();
          if (videoController.isUserActive.value) {
            Get.offAll(() => const TVBottomBarTabs(initialIndex: 0));
          } else {
            Get.offAll(() => const TVBuySubscription());
          }
        } else {
          commToast("Failed to log in. Please try again.");
          setState(() {
            isLoading = false;
          });
        }
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? 'OTP verification failed';
        commToast(errorMessage);
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      commToast('OTP verification failed. Please try again.');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showUserNotFoundDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return FocusScope(
          child: AlertDialog(
            backgroundColor: darkColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
              side: const BorderSide(color: Colors.white12, width: 2),
            ),
            title: Text(
              "User Not Found",
              style: TextStyle(
                  color: whiteColor, fontWeight: FontWeight.bold, fontSize: 28),
            ),
            content: const Text(
              "It seems you don't have an account. Would you like to register?",
              style: TextStyle(color: Colors.white70, fontSize: 20),
            ),
            actions: <Widget>[
              TextButton(
                autofocus: true,
                style: ButtonStyle(
                  overlayColor:
                      MaterialStateProperty.all(greenColor.withOpacity(0.2)),
                  shape: MaterialStateProperty.all(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
                  side: MaterialStateProperty.resolveWith<BorderSide>((states) {
                    if (states.contains(MaterialState.focused)) {
                      return BorderSide(color: greenColor, width: 2);
                    }
                    return BorderSide.none;
                  }),
                ),
                child: const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Text("Cancel",
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _phoneFocusNode.requestFocus();
                  phoneController.clear();
                },
              ),
              ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(greenColor),
                  foregroundColor: MaterialStateProperty.all(blackColor),
                  padding: MaterialStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  shape: MaterialStateProperty.all(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
                ),
                child: const Text("Register", style: TextStyle(fontSize: 18)),
                onPressed: () {
                  Navigator.of(context).pop();
                  Get.off(() => const Register());
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void commToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.grey[900],
      textColor: Colors.white,
      fontSize: 20.0,
    );
  }

  void _handleMainAction() async {
    if (phoneErrorText != null) {
      commToast(phoneErrorText!);
      FocusScope.of(context).requestFocus(_phoneFocusNode);
      return;
    }
    if (!agreeTcs) {
      commToast("Please agree to the Terms & Conditions");
      FocusScope.of(context).requestFocus(_termsFocusNode);
      return;
    }

    FocusScope.of(context).unfocus();

    if (!isOtpSent) {
      String phoneNumber = phoneController.text.trim();
      bool userExists = await checkUserExists(phoneNumber);
      if (userExists) {
        sendOtpForLogin(phoneNumber);
      } else {
        _showUserNotFoundDialog(context);
      }
    } else {
      verifyOtpAndSignIn();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isKeyboardVisible) {
          _hideKeyboard();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: blackColor,
        body: Row(
          children: [
            _buildLeftPanel(),
            _buildRightPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftPanel() => Expanded(
        flex: 3,
        child: Container(
          color: blackColor,
          child: Center(
              child: SizedBox(
                  width: 250, height: 250, child: Image.asset(appLogo))),
        ),
      );

  Widget _buildRightPanel() => Expanded(
        flex: 2,
        child: Container(
          color: darkColor,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: isOtpSent
                          ? _buildOtpSection()
                          : _buildPhoneInputSection(),
                    ),
                    const SizedBox(height: 16),
                    if (_isKeyboardVisible)
                      _buildTvKeyboard()
                    else ...[
                      _buildTermsCheckbox(),
                      const SizedBox(height: 24),
                      _buildMainActionButton(),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildPhoneInputSection() => Column(
        key: const ValueKey('phone-section'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Log In",
              style: TextStyle(
                  color: whiteColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildPhoneInputField(),
        ],
      );

  Widget _buildPhoneInputField() {
    return InkWell(
      focusNode: _phoneFocusNode,
      autofocus: true,
      onTap: () {
        if (_isKeyboardVisible) {
          _hideKeyboard();
        } else {
          _showKeyboardFor(phoneController);
        }
      },
      onFocusChange: (hasFocus) => setState(() {}),
      child: IgnorePointer(
        child: TextField(
          controller: phoneController,
          readOnly: true,
          style: TextStyle(fontSize: 18, color: whiteColor),
          decoration: InputDecoration(
            labelText: "Phone Number",
            labelStyle: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w400,
                fontSize: 16),
            prefixIcon:
                Icon(Icons.phone_outlined, color: Colors.white70, size: 20),
            filled: true,
            fillColor: blackColor.withOpacity(0.5),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: _phoneFocusNode.hasFocus
                        ? blueColor
                        : Colors.transparent,
                    width: 2.5),
                borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: blueColor, width: 2.5),
                borderRadius: BorderRadius.circular(12)),
            errorText: phoneErrorText,
            errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpSection() => Column(
        key: const ValueKey('otp-section'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0, left: 4),
            child: Text("OTP sent to ${phoneController.text.trim()}",
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0, left: 4),
            child: Text("Enter OTP",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 24)),
          ),
          _buildOtpDigitBox(context),
        ],
      );

  Widget _buildOtpDigitBox(BuildContext context) {
    bool isFocused = _otpFocusNode.hasFocus;

    return InkWell(
      focusNode: _otpFocusNode,
      autofocus: true,
      onTap: () {
        if (_isKeyboardVisible) {
          _hideKeyboard();
        } else {
          _showKeyboardFor(otpController);
        }
      },
      onFocusChange: (hasFocus) => setState(() {}),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: IgnorePointer(
        child: PinCodeTextField(
          appContext: context,
          length: 6,
          controller: otpController,
          readOnly: true,
          keyboardType: TextInputType.none,
          textStyle: TextStyle(
              fontSize: 20, color: whiteColor, fontWeight: FontWeight.bold),
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            fieldHeight: 52,
            fieldWidth: 42,
            // For the box with the cursor (ready for input)
            selectedColor: blueColor,
            selectedFillColor: blackColor.withOpacity(0.7),
            // For boxes that are already filled with a digit
            activeColor: Colors.white70,
            activeFillColor: blackColor.withOpacity(0.5),
            // For empty boxes without the cursor
            inactiveColor: isFocused ? blueColor : Colors.white30,
            inactiveFillColor: blackColor.withOpacity(0.5),

            borderRadius: BorderRadius.circular(12),
            borderWidth: isFocused ? 2 : 1.5,
            selectedBorderWidth: 2.5,
            activeBorderWidth: 1.5,
            inactiveBorderWidth: isFocused ? 2.0 : 1.5,
          ),
          enableActiveFill: true,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
        ),
      ),
    );
  }

  Widget _buildTvKeyboard() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: TvKeyboard(
        onKeyTap: (char) {
          if (_activeController == null) return;
          int maxLength = _activeController == phoneController ? 10 : 6;
          if (_activeController!.text.length < maxLength) {
            setState(() {
              _activeController!.text += char;
              if (_activeController == phoneController) {
                _validatePhoneNumber(phoneController.text);
              }
            });
          }
          if (_activeController == otpController &&
              _activeController!.text.length == 6) {
            _hideKeyboard();
            _termsFocusNode.requestFocus();
          }
        },
        onBackspace: () {
          if (_activeController != null && _activeController!.text.isNotEmpty) {
            setState(() {
              _activeController!.text = _activeController!.text
                  .substring(0, _activeController!.text.length - 1);
              if (_activeController == phoneController) {
                _validatePhoneNumber(phoneController.text);
              }
            });
          }
        },
        onClear: () {
          if (_activeController != null) {
            setState(() {
              _activeController!.clear();
              if (_activeController == phoneController) {
                _validatePhoneNumber('');
              }
            });
          }
        },
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Focus(
      focusNode: _termsFocusNode,
      onKey: (node, event) {
        if (_isKeyboardVisible) return KeyEventResult.handled;
        if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          isOtpSent
              ? _otpFocusNode.requestFocus()
              : _phoneFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _submitFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          setState(() => agreeTcs = !agreeTcs);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (context) {
        final bool hasFocus = Focus.of(context).hasFocus;
        return InkWell(
          onTap: () => setState(() => agreeTcs = !agreeTcs),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color:
                  hasFocus ? greenColor.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: hasFocus ? greenColor : Colors.transparent, width: 2),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Row(
              children: [
                Checkbox(
                  value: agreeTcs,
                  onChanged: (value) =>
                      setState(() => agreeTcs = value ?? false),
                  activeColor: greenColor,
                  checkColor: blackColor,
                  side: const BorderSide(color: Colors.white70, width: 2),
                ),
                Expanded(child: _buildTermsAndConditionsText()),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTermsAndConditionsText() => InkWell(
        onTap: () async {
          final Uri url = Uri.parse(
              'https://videosalarm.com/videoalarm/terms-and-condition.php');
          if (!await launchUrl(url)) {
            commToast("Could not open Terms & Conditions.");
          }
        },
        child: RichText(
          text: TextSpan(
            style: TextStyle(fontFamily: 'AppStyle'),
            children: [
              TextSpan(
                  text: "I agree to the ",
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              TextSpan(
                  text: "Terms & Conditions",
                  style: TextStyle(
                      color: greenColor,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      fontSize: 14)),
            ],
          ),
        ),
      );

  Widget _buildMainActionButton() => Focus(
        focusNode: _submitFocusNode,
        onKey: (node, event) {
          if (_isKeyboardVisible) return KeyEventResult.handled;
          if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _termsFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            if (!isLoading) _handleMainAction();
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
              onPressed: isLoading ? null : _handleMainAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: greenColor,
                foregroundColor: blackColor,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: hasFocus ? 10 : 5,
              ),
              child: isLoading
                  ? SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(blackColor),
                          strokeWidth: 3))
                  : Text(isOtpSent ? "Verify OTP" : "Send OTP",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          );
        }),
      );
}

class TvKeyboard extends StatelessWidget {
  final ValueChanged<String> onKeyTap;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const TvKeyboard({
    Key? key,
    required this.onKeyTap,
    required this.onBackspace,
    required this.onClear,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildKeyboardRow(['1', '2', '3']),
            const SizedBox(height: 12),
            _buildKeyboardRow(['4', '5', '6']),
            const SizedBox(height: 12),
            _buildKeyboardRow(['7', '8', '9']),
            const SizedBox(height: 12),
            _buildKeyboardRow(['CLEAR', '0', 'DEL']),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboardRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key == 'DEL') {
          return _buildSpecialKey(
            icon: Icons.backspace_outlined,
            onPressed: onBackspace,
          );
        } else if (key == 'CLEAR') {
          return _buildSpecialKey(
            label: "CLEAR",
            onPressed: onClear,
            autofocus: true,
          );
        }
        return _buildNumberKey(key, onPressed: () => onKeyTap(key));
      }).toList(),
    );
  }

  Widget _buildNumberKey(String text, {required VoidCallback onPressed}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: _KeyboardButton(
          onPressed: onPressed,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey(
      {IconData? icon,
      String? label,
      required VoidCallback onPressed,
      bool autofocus = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: _KeyboardButton(
          autofocus: autofocus,
          onPressed: onPressed,
          child: label != null
              ? Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white))
              : Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _KeyboardButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final bool autofocus;

  const _KeyboardButton({
    Key? key,
    required this.child,
    required this.onPressed,
    this.autofocus = false,
  }) : super(key: key);

  @override
  __KeyboardButtonState createState() => __KeyboardButtonState();
}

class __KeyboardButtonState extends State<_KeyboardButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      onKey: (node, event) {
        if (event is RawKeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _isFocused ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Material(
          color: _isFocused ? Colors.blue.shade700 : const Color(0xFF333333),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 50,
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

// import 'dart:convert';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:pin_code_fields/pin_code_fields.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:videos_alarm_app/login_screen/register.dart';
// import 'package:videos_alarm_app/screens/Vid_controller.dart';
// import 'package:videos_alarm_app/screens/check_subs_controller.dart';
// import 'package:videos_alarm_app/tv_screens/tv_black_screen.dart';
// import 'package:videos_alarm_app/tv_screens/tv_bottom_bar_tabs.dart';
// import '../components/app_style.dart';
// import '../components/constant.dart';

// class TVLogInScreen extends StatefulWidget {
//   const TVLogInScreen({Key? key}) : super(key: key);

//   @override
//   State<TVLogInScreen> createState() => _TVLogInScreenState();
// }

// class _TVLogInScreenState extends State<TVLogInScreen> {
//   final _formKey = GlobalKey<FormState>();
//   bool isLoading = false;
//   bool agreeTcs = false;
//   bool isOtpSent = false;
//   String? phoneErrorText;

//   final TextEditingController phoneController = TextEditingController();
//   final TextEditingController otpController = TextEditingController();

//   final FocusNode _phoneFocusNode = FocusNode();
//   final FocusNode _termsFocusNode = FocusNode();
//   final FocusNode _otpFocusNode = FocusNode();
//   final FocusNode _submitFocusNode = FocusNode();

//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final VideoController videoController = Get.put(VideoController());

//   bool _isKeyboardVisible = false;
//   TextEditingController? _activeController;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       FocusScope.of(context).requestFocus(_phoneFocusNode);
//     });
//   }

//   @override
//   void dispose() {
//     phoneController.dispose();
//     otpController.dispose();
//     _phoneFocusNode.dispose();
//     _termsFocusNode.dispose();
//     _otpFocusNode.dispose();
//     _submitFocusNode.dispose();
//     super.dispose();
//   }

//   void _showKeyboardFor(TextEditingController controller) {
//     setState(() {
//       _isKeyboardVisible = true;
//       _activeController = controller;
//     });
//   }

//   void _hideKeyboard() {
//     if (!_isKeyboardVisible) return;
//     setState(() {
//       _isKeyboardVisible = false;
//       if (isOtpSent) {
//         _otpFocusNode.requestFocus();
//       } else {
//         _phoneFocusNode.requestFocus();
//       }
//     });
//   }

//   void _validatePhoneNumber(String value) {
//     String? validator(String? val) {
//       if (val == null || val.isEmpty) return "Enter phone number";
//       if (!RegExp(r'^\d{10}$').hasMatch(val)) {
//         return "Enter a valid 10-digit phone number";
//       }
//       return null;
//     }

//     setState(() => phoneErrorText = validator(value));
//   }

//   String get _otpFromInput => otpController.text;

//   Future<bool> checkUserExists(String phoneNumber) async {
//     setState(() {
//       isLoading = true;
//     });

//     if (phoneNumber == '1000000000') {
//       setState(() {
//         isLoading = false;
//       });
//       return true;
//     }

//     const String apiUrl = 'http://165.22.215.103:3066/checkUserExists';
//     Map<String, String> headers = {'Content-Type': 'application/json'};
//     Map<String, dynamic> body = {'phone': phoneNumber};

//     try {
//       final response = await http.post(Uri.parse(apiUrl),
//           headers: headers, body: jsonEncode(body));
//       setState(() {
//         isLoading = false;
//       });

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> responseData = json.decode(response.body);
//         return responseData['exists'] ?? false;
//       } else {
//         final errorBody = json.decode(response.body);
//         final errorMessage =
//             errorBody['message'] ?? 'Failed to check user existence';
//         commToast('Error checking user: $errorMessage');
//         return false;
//       }
//     } catch (e) {
//       setState(() {
//         isLoading = false;
//       });
//       commToast('Error checking user: Please try again.');
//       print('Error checking user existence: $e');
//       return false;
//     }
//   }

//   Future<void> sendOtpForLogin(String phoneNumber) async {
//     setState(() {
//       isLoading = true;
//     });

//     if (phoneNumber == '1000000000') {
//       setState(() {
//         isOtpSent = true;
//         isLoading = false;
//       });
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         FocusScope.of(context).requestFocus(_otpFocusNode);
//       });
//       commToast('OTP sent to $phoneNumber (Simulated)');
//       return;
//     }

//     const String apiUrl = 'http://165.22.215.103:3066/sendOtp';
//     Map<String, String> headers = {'Content-Type': 'application/json'};
//     Map<String, dynamic> body = {'phone': phoneNumber};

//     try {
//       final response = await http.post(Uri.parse(apiUrl),
//           headers: headers, body: jsonEncode(body));
//       if (response.statusCode == 200) {
//         setState(() {
//           isOtpSent = true;
//           isLoading = false;
//         });
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           FocusScope.of(context).requestFocus(_otpFocusNode);
//         });
//         commToast('OTP sent to $phoneNumber');
//       } else {
//         final errorBody = json.decode(response.body);
//         final errorMessage = errorBody['message'] ?? 'Failed to send OTP';
//         throw Exception(errorMessage);
//       }
//     } catch (e) {
//       setState(() {
//         isLoading = false;
//       });
//       commToast(e.toString().replaceFirst('Exception: ', ''));
//     }
//   }

//   Future<void> verifyOtpAndSignIn() async {
//     final String otp = _otpFromInput;
//     final String phone = phoneController.text.trim();

//     if (otp.length != 6) {
//       commToast('Please enter the 6-digit OTP');
//       return;
//     }

//     setState(() {
//       isLoading = true;
//     });

//     if (phone == '1000000000' && otp == '000000') {
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       await prefs.setBool('isTestUser', true);
//       setState(() {
//         isLoading = false;
//       });
//       commToast('Login Successful! (Simulated)');

//       SubscriptionService subscriptionService = SubscriptionService();
//       await subscriptionService.checkSubscriptionStatus();
//       if (videoController.isUserActive.value) {
//         Get.offAll(() => const TVBottomBarTabs(initialIndex: 0));
//       } else {
//         Get.offAll(() => const TVBuySubscription());
//       }

//       return;
//     }

//     const String apiUrl = 'http://165.22.215.103:3066/verifyOtp';
//     Map<String, String> headers = {'Content-Type': 'application/json'};
//     Map<String, dynamic> body = {'phone': phone, 'otp': otp};

//     try {
//       final response = await http.post(Uri.parse(apiUrl),
//           headers: headers, body: jsonEncode(body));
//       if (response.statusCode == 200) {
//         final Map<String, dynamic> responseData = json.decode(response.body);
//         String customToken = responseData['token'];
//         UserCredential userCredential =
//             await _auth.signInWithCustomToken(customToken);
//         User? user = userCredential.user;

//         if (user != null) {
//           await FirebaseFirestore.instance
//               .collection('users')
//               .doc(user.uid)
//               .update({'lastLogin': FieldValue.serverTimestamp()});

//           setState(() {
//             isLoading = false;
//           });

//           SubscriptionService subscriptionService = SubscriptionService();
//           await subscriptionService.checkSubscriptionStatus();
//           if (videoController.isUserActive.value) {
//             Get.offAll(() => const TVBottomBarTabs(initialIndex: 0));
//           } else {
//             Get.offAll(() => const TVBuySubscription());
//           }
//         } else {
//           commToast("Failed to log in. Please try again.");
//           setState(() {
//             isLoading = false;
//           });
//         }
//       } else {
//         final errorBody = json.decode(response.body);
//         final errorMessage = errorBody['message'] ?? 'OTP verification failed';
//         commToast(errorMessage);
//         setState(() {
//           isLoading = false;
//         });
//       }
//     } catch (e) {
//       commToast('OTP verification failed. Please try again.');
//       setState(() {
//         isLoading = false;
//       });
//     }
//   }

//   void _showUserNotFoundDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return FocusScope(
//           child: AlertDialog(
//             backgroundColor: darkColor,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(16.0),
//               side: const BorderSide(color: Colors.white12, width: 2),
//             ),
//             title: Text(
//               "User Not Found",
//               style: TextStyle(
//                   color: whiteColor, fontWeight: FontWeight.bold, fontSize: 28),
//             ),
//             content: const Text(
//               "It seems you don't have an account. Would you like to register?",
//               style: TextStyle(color: Colors.white70, fontSize: 20),
//             ),
//             actions: <Widget>[
//               TextButton(
//                 autofocus: true,
//                 style: ButtonStyle(
//                   overlayColor:
//                       MaterialStateProperty.all(greenColor.withOpacity(0.2)),
//                   shape: MaterialStateProperty.all(RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8))),
//                   side: MaterialStateProperty.resolveWith<BorderSide>((states) {
//                     if (states.contains(MaterialState.focused)) {
//                       return BorderSide(color: greenColor, width: 2);
//                     }
//                     return BorderSide.none;
//                   }),
//                 ),
//                 child: const Padding(
//                   padding:
//                       EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
//                   child: Text("Cancel",
//                       style: TextStyle(color: Colors.white, fontSize: 18)),
//                 ),
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                   _phoneFocusNode.requestFocus();
//                   phoneController.clear();
//                 },
//               ),
//               ElevatedButton(
//                 style: ButtonStyle(
//                   backgroundColor: MaterialStateProperty.all(greenColor),
//                   foregroundColor: MaterialStateProperty.all(blackColor),
//                   padding: MaterialStateProperty.all(
//                       const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
//                   shape: MaterialStateProperty.all(RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8))),
//                 ),
//                 child: const Text("Register", style: TextStyle(fontSize: 18)),
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                   Get.off(() => const Register());
//                 },
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   void commToast(String message) {
//     Fluttertoast.showToast(
//       msg: message,
//       toastLength: Toast.LENGTH_SHORT,
//       gravity: ToastGravity.BOTTOM,
//       backgroundColor: Colors.grey[900],
//       textColor: Colors.white,
//       fontSize: 20.0,
//     );
//   }

//   void _handleMainAction() async {
//     if (phoneErrorText != null) {
//       commToast(phoneErrorText!);
//       FocusScope.of(context).requestFocus(_phoneFocusNode);
//       return;
//     }
//     if (!agreeTcs) {
//       commToast("Please agree to the Terms & Conditions");
//       FocusScope.of(context).requestFocus(_termsFocusNode);
//       return;
//     }

//     FocusScope.of(context).unfocus();

//     if (!isOtpSent) {
//       String phoneNumber = phoneController.text.trim();
//       bool userExists = await checkUserExists(phoneNumber);
//       if (userExists) {
//         sendOtpForLogin(phoneNumber);
//       } else {
//         _showUserNotFoundDialog(context);
//       }
//     } else {
//       verifyOtpAndSignIn();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: () async {
//         if (_isKeyboardVisible) {
//           _hideKeyboard();
//           return false;
//         }
//         return true;
//       },
//       child: Scaffold(
//         backgroundColor: blackColor,
//         body: Row(
//           children: [
//             _buildLeftPanel(),
//             _buildRightPanel(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildLeftPanel() => Expanded(
//         flex: 3,
//         child: Container(
//           color: blackColor,
//           child: Center(
//               child: SizedBox(
//                   width: 250, height: 250, child: Image.asset(appLogo))),
//         ),
//       );

//   Widget _buildRightPanel() => Expanded(
//         flex: 2,
//         child: Container(
//           color: darkColor,
//           child: Center(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     AnimatedSwitcher(
//                       duration: const Duration(milliseconds: 300),
//                       transitionBuilder: (child, animation) =>
//                           FadeTransition(opacity: animation, child: child),
//                       child: isOtpSent
//                           ? _buildOtpSection()
//                           : _buildPhoneInputSection(),
//                     ),
//                     const SizedBox(height: 16),
//                     if (_isKeyboardVisible)
//                       _buildTvKeyboard()
//                     else ...[
//                       _buildTermsCheckbox(),
//                       const SizedBox(height: 24),
//                       _buildMainActionButton(),
//                     ]
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       );

//   Widget _buildPhoneInputSection() => Column(
//         key: const ValueKey('phone-section'),
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text("Log In",
//               style: TextStyle(
//                   color: whiteColor,
//                   fontSize: 32,
//                   fontWeight: FontWeight.bold)),
//           const SizedBox(height: 24),
//           _buildPhoneInputField(),
//         ],
//       );

//   Widget _buildPhoneInputField() {
//     return InkWell(
//       focusNode: _phoneFocusNode,
//       autofocus: true,
//       onTap: () {
//         if (_isKeyboardVisible) {
//           _hideKeyboard();
//         } else {
//           _showKeyboardFor(phoneController);
//         }
//       },
//       onFocusChange: (hasFocus) => setState(() {}),
//       child: IgnorePointer(
//         child: TextField(
//           controller: phoneController,
//           readOnly: true,
//           style: TextStyle(fontSize: 18, color: whiteColor),
//           decoration: InputDecoration(
//             labelText: "Phone Number",
//             labelStyle: const TextStyle(
//                 color: Colors.white70,
//                 fontWeight: FontWeight.w400,
//                 fontSize: 16),
//             prefixIcon:
//                 Icon(Icons.phone_outlined, color: Colors.white70, size: 20),
//             filled: true,
//             fillColor: blackColor.withOpacity(0.5),
//             enabledBorder: OutlineInputBorder(
//                 borderSide: BorderSide(
//                     color: _phoneFocusNode.hasFocus
//                         ? blueColor
//                         : Colors.transparent,
//                     width: 2.5),
//                 borderRadius: BorderRadius.circular(12)),
//             focusedBorder: OutlineInputBorder(
//                 borderSide: BorderSide(color: blueColor, width: 2.5),
//                 borderRadius: BorderRadius.circular(12)),
//             errorText: phoneErrorText,
//             errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 14),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildOtpSection() => Column(
//         key: const ValueKey('otp-section'),
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Padding(
//             padding: const EdgeInsets.only(bottom: 12.0, left: 4),
//             child: Text("OTP sent to ${phoneController.text.trim()}",
//                 style: const TextStyle(color: Colors.white70, fontSize: 14)),
//           ),
//           const Padding(
//             padding: EdgeInsets.only(bottom: 16.0, left: 4),
//             child: Text("Enter OTP",
//                 style: TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.w500,
//                     fontSize: 24)),
//           ),
//           _buildOtpDigitBox(context),
//         ],
//       );

//   Widget _buildOtpDigitBox(BuildContext context) {
//     return InkWell(
//       focusNode: _otpFocusNode,
//       autofocus: true,
//       onTap: () {
//         if (_isKeyboardVisible) {
//           _hideKeyboard();
//         } else {
//           _showKeyboardFor(otpController);
//         }
//       },
//       onFocusChange: (hasFocus) => setState(() {}),
//       child: IgnorePointer(
//         child: PinCodeTextField(
//           appContext: context,
//           length: 6,
//           controller: otpController,
//           readOnly: true,
//           keyboardType: TextInputType.none,
//           textStyle: TextStyle(
//               fontSize: 20, color: whiteColor, fontWeight: FontWeight.bold),
//           pinTheme: PinTheme(
//             shape: PinCodeFieldShape.box,
//             fieldHeight: 52,
//             fieldWidth: 42,
//             activeColor: _otpFocusNode.hasFocus ? blueColor : Colors.white30,
//             inactiveColor: Colors.white30,
//             selectedColor: blueColor,
//             activeFillColor: blackColor.withOpacity(0.5),
//             inactiveFillColor: blackColor.withOpacity(0.5),
//             selectedFillColor: blackColor.withOpacity(0.7),
//             borderRadius: BorderRadius.circular(12),
//             borderWidth: 1.5,
//             activeBorderWidth: 2.5,
//           ),
//           enableActiveFill: true,
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         ),
//       ),
//     );
//   }

//   Widget _buildTvKeyboard() {
//     return Padding(
//       padding: const EdgeInsets.only(top: 16.0),
//       child: TvKeyboard(
//         onKeyTap: (char) {
//           if (_activeController == null) return;
//           int maxLength = _activeController == phoneController ? 10 : 6;
//           if (_activeController!.text.length < maxLength) {
//             setState(() {
//               _activeController!.text += char;
//               if (_activeController == phoneController) {
//                 _validatePhoneNumber(phoneController.text);
//               }
//             });
//           }
//           if (_activeController == otpController &&
//               _activeController!.text.length == 6) {
//             _hideKeyboard();
//             _termsFocusNode.requestFocus();
//           }
//         },
//         onBackspace: () {
//           if (_activeController != null && _activeController!.text.isNotEmpty) {
//             setState(() {
//               _activeController!.text = _activeController!.text
//                   .substring(0, _activeController!.text.length - 1);
//               if (_activeController == phoneController) {
//                 _validatePhoneNumber(phoneController.text);
//               }
//             });
//           }
//         },
//         onClear: () {
//           if (_activeController != null) {
//             setState(() {
//               _activeController!.clear();
//               if (_activeController == phoneController) {
//                 _validatePhoneNumber('');
//               }
//             });
//           }
//         },
//       ),
//     );
//   }

//   Widget _buildTermsCheckbox() {
//     return Focus(
//       focusNode: _termsFocusNode,
//       onKey: (node, event) {
//         if (_isKeyboardVisible) return KeyEventResult.handled;
//         if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
//         if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
//           isOtpSent
//               ? _otpFocusNode.requestFocus()
//               : _phoneFocusNode.requestFocus();
//           return KeyEventResult.handled;
//         }
//         if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
//           _submitFocusNode.requestFocus();
//           return KeyEventResult.handled;
//         }
//         if (event.logicalKey == LogicalKeyboardKey.select ||
//             event.logicalKey == LogicalKeyboardKey.enter) {
//           setState(() => agreeTcs = !agreeTcs);
//           return KeyEventResult.handled;
//         }
//         return KeyEventResult.ignored;
//       },
//       child: Builder(builder: (context) {
//         final bool hasFocus = Focus.of(context).hasFocus;
//         return InkWell(
//           onTap: () => setState(() => agreeTcs = !agreeTcs),
//           child: AnimatedContainer(
//             duration: const Duration(milliseconds: 150),
//             decoration: BoxDecoration(
//               color:
//                   hasFocus ? greenColor.withOpacity(0.1) : Colors.transparent,
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(
//                   color: hasFocus ? greenColor : Colors.transparent, width: 2),
//             ),
//             padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
//             child: Row(
//               children: [
//                 Checkbox(
//                   value: agreeTcs,
//                   onChanged: (value) =>
//                       setState(() => agreeTcs = value ?? false),
//                   activeColor: greenColor,
//                   checkColor: blackColor,
//                   side: const BorderSide(color: Colors.white70, width: 2),
//                 ),
//                 Expanded(child: _buildTermsAndConditionsText()),
//               ],
//             ),
//           ),
//         );
//       }),
//     );
//   }

//   Widget _buildTermsAndConditionsText() => InkWell(
//         onTap: () async {
//           final Uri url = Uri.parse(
//               'https://videosalarm.com/videoalarm/terms-and-condition.php');
//           if (!await launchUrl(url)) {
//             commToast("Could not open Terms & Conditions.");
//           }
//         },
//         child: RichText(
//           text: TextSpan(
//             style: TextStyle(fontFamily: 'AppStyle'),
//             children: [
//               TextSpan(
//                   text: "I agree to the ",
//                   style: TextStyle(color: Colors.white70, fontSize: 14)),
//               TextSpan(
//                   text: "Terms & Conditions",
//                   style: TextStyle(
//                       color: greenColor,
//                       fontWeight: FontWeight.w600,
//                       decoration: TextDecoration.underline,
//                       fontSize: 14)),
//             ],
//           ),
//         ),
//       );

//   Widget _buildMainActionButton() => Focus(
//         focusNode: _submitFocusNode,
//         onKey: (node, event) {
//           if (_isKeyboardVisible) return KeyEventResult.handled;
//           if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
//           if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
//             _termsFocusNode.requestFocus();
//             return KeyEventResult.handled;
//           }
//           if (event.logicalKey == LogicalKeyboardKey.select ||
//               event.logicalKey == LogicalKeyboardKey.enter) {
//             if (!isLoading) _handleMainAction();
//             return KeyEventResult.handled;
//           }
//           return KeyEventResult.ignored;
//         },
//         child: Builder(builder: (context) {
//           final bool hasFocus = Focus.of(context).hasFocus;
//           return AnimatedContainer(
//             duration: const Duration(milliseconds: 200),
//             transform: hasFocus
//                 ? (Matrix4.identity()..scale(1.05))
//                 : Matrix4.identity(),
//             transformAlignment: Alignment.center,
//             child: ElevatedButton(
//               onPressed: isLoading ? null : _handleMainAction,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: greenColor,
//                 foregroundColor: blackColor,
//                 padding: const EdgeInsets.symmetric(vertical: 18),
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12)),
//                 elevation: hasFocus ? 10 : 5,
//               ),
//               child: isLoading
//                   ? SizedBox(
//                       width: 28,
//                       height: 28,
//                       child: CircularProgressIndicator(
//                           valueColor: AlwaysStoppedAnimation<Color>(blackColor),
//                           strokeWidth: 3))
//                   : Text(isOtpSent ? "Verify OTP" : "Send OTP",
//                       style: const TextStyle(
//                           fontSize: 18, fontWeight: FontWeight.bold)),
//             ),
//           );
//         }),
//       );
// }

// class TvKeyboard extends StatelessWidget {
//   final ValueChanged<String> onKeyTap;
//   final VoidCallback onBackspace;
//   final VoidCallback onClear;

//   const TvKeyboard({
//     Key? key,
//     required this.onKeyTap,
//     required this.onBackspace,
//     required this.onClear,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Container(
//         width: 350,
//         padding: const EdgeInsets.all(16.0),
//         decoration: BoxDecoration(
//           color: const Color(0xFF1A1A1A),
//           borderRadius: BorderRadius.circular(16),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: <Widget>[
//             _buildKeyboardRow(['1', '2', '3']),
//             const SizedBox(height: 12),
//             _buildKeyboardRow(['4', '5', '6']),
//             const SizedBox(height: 12),
//             _buildKeyboardRow(['7', '8', '9']),
//             const SizedBox(height: 12),
//             _buildKeyboardRow(['CLEAR', '0', 'DEL']),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildKeyboardRow(List<String> keys) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//       children: keys.map((key) {
//         if (key == 'DEL') {
//           return _buildSpecialKey(
//             icon: Icons.backspace_outlined,
//             onPressed: onBackspace,
//           );
//         } else if (key == 'CLEAR') {
//           return _buildSpecialKey(
//             label: "CLEAR",
//             onPressed: onClear,
//             autofocus: true,
//           );
//         }
//         return _buildNumberKey(key, onPressed: () => onKeyTap(key));
//       }).toList(),
//     );
//   }

//   Widget _buildNumberKey(String text, {required VoidCallback onPressed}) {
//     return Expanded(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//         child: _KeyboardButton(
//           onPressed: onPressed,
//           child: Text(
//             text,
//             style: const TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//               color: Colors.white,
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSpecialKey(
//       {IconData? icon,
//       String? label,
//       required VoidCallback onPressed,
//       bool autofocus = false}) {
//     return Expanded(
//       child: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: _KeyboardButton(
//           autofocus: autofocus,
//           onPressed: onPressed,
//           child: label != null
//               ? Text(label,
//                   style: const TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white))
//               : Icon(icon, color: Colors.white, size: 20),
//         ),
//       ),
//     );
//   }
// }

// class _KeyboardButton extends StatefulWidget {
//   final Widget child;
//   final VoidCallback onPressed;
//   final bool autofocus;

//   const _KeyboardButton({
//     Key? key,
//     required this.child,
//     required this.onPressed,
//     this.autofocus = false,
//   }) : super(key: key);

//   @override
//   __KeyboardButtonState createState() => __KeyboardButtonState();
// }

// class __KeyboardButtonState extends State<_KeyboardButton> {
//   bool _isFocused = false;

//   @override
//   Widget build(BuildContext context) {
//     return Focus(
//       autofocus: widget.autofocus,
//       onFocusChange: (hasFocus) {
//         setState(() {
//           _isFocused = hasFocus;
//         });
//       },
//       onKey: (node, event) {
//         if (event is RawKeyDownEvent &&
//             (event.logicalKey == LogicalKeyboardKey.select ||
//                 event.logicalKey == LogicalKeyboardKey.enter)) {
//           widget.onPressed();
//           return KeyEventResult.handled;
//         }
//         return KeyEventResult.ignored;
//       },
//       child: AnimatedScale(
//         scale: _isFocused ? 1.15 : 1.0,
//         duration: const Duration(milliseconds: 150),
//         child: Material(
//           color: _isFocused ? Colors.blue.shade700 : const Color(0xFF333333),
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           child: InkWell(
//             onTap: widget.onPressed,
//             borderRadius: BorderRadius.circular(12),
//             child: SizedBox(
//               height: 50,
//               child: Center(child: widget.child),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
