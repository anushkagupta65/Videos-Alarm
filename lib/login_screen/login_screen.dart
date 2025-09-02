import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videos_alarm_app/login_screen/register.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';
import 'package:videos_alarm_app/screens/banner_video_list.dart';
import '../components/app_style.dart';
import '../components/constant.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../device_guard.dart';
import '../device_limit_screen.dart';

class LogInScreen extends StatefulWidget {
  const LogInScreen({Key? key}) : super(key: key);

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool agreeTcs = false;
  bool isOtpSent = false;

  final TextEditingController phoneController = TextEditingController();
  List<TextEditingController> otpDigitControllers =
      List.generate(6, (_) => TextEditingController());
  List<FocusNode> otpFocusNodes = List.generate(6, (_) => FocusNode());

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final VideoController videoController = Get.put(VideoController());

  @override
  void dispose() {
    phoneController.dispose();
    for (var controller in otpDigitControllers) {
      controller.dispose();
    }
    for (var focusNode in otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String get _otpFromBoxes {
    return otpDigitControllers.map((controller) => controller.text).join();
  }

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

    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    Map<String, dynamic> body = {
      'phone': phoneNumber,
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode(body),
      );

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
      commToast('OTP sent to $phoneNumber (Simulated)');
      return;
    }

    const String apiUrl = 'http://165.22.215.103:3066/sendOtp';
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    Map<String, dynamic> body = {
      'phone': phoneNumber,
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        setState(() {
          isOtpSent = true;
          isLoading = false;
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
    final String otp = _otpFromBoxes;
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
      Get.offAll(() => BottomBarTabs(initialIndex: 0));
      return;
    }

    const String apiUrl = 'http://165.22.215.103:3066/verifyOtp';
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    Map<String, dynamic> body = {
      'phone': phone,
      'otp': otp,
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        String customToken = responseData['token'];

        UserCredential userCredential =
            await _auth.signInWithCustomToken(customToken);

        User? user = userCredential.user;

        if (user != null) {
          if (!await validateAndAddDevice(user.uid, context)) {
            setState(() {
              isLoading = false;
            });
            Get.off(() => const DeviceLimitScreen());
            return;
          }
          FirebaseFirestore.instance.runTransaction((transaction) async {
            DocumentReference userDocRef =
                FirebaseFirestore.instance.collection('users').doc(user.uid);
            DocumentSnapshot snapshot = await transaction.get(userDocRef);

            if (snapshot.exists) {
              transaction.update(userDocRef, {
                'lastLogin': FieldValue.serverTimestamp(),
              });
            }
          }).then((_) {
            setState(() {
              isLoading = false;
            });
            Get.offAll(() => BottomBarTabs(initialIndex: 0));
          }).catchError((error) {
            commToast("Error updating user data: $error");
            setState(() {
              isLoading = false;
            });
          });
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
        return AlertDialog(
          backgroundColor: darkColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(color: Colors.white12),
          ),
          title: Text(
            "User Not Found",
            style: TextStyle(
              color: whiteColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "It seems you don't have an account. Would you like to register?",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                "Cancel",
                style: TextStyle(color: Colors.white60),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                phoneController.clear();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: greenColor,
                foregroundColor: blackColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text("Register"),
              onPressed: () {
                Navigator.of(context).pop();
                Get.off(() => const Register());
              },
            ),
          ],
        );
      },
    );
  }

  void commToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.grey[800],
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              darkColor.withOpacity(0.8),
              blackColor,
              darkColor.withOpacity(0.8),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding:
                EdgeInsets.symmetric(horizontal: sidePadding, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    margin: EdgeInsets.only(bottom: 48),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: Image.asset(appLogo),
                    ),
                  ),
                  if (!isOtpSent)
                    _buildTextFormField(
                      controller: phoneController,
                      labelText: "Phone Number",
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Enter phone number";
                        } else if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                          return "Enter a valid 10-digit phone number";
                        }
                        return null;
                      },
                    ),
                  if (isOtpSent)
                    AnimatedOpacity(
                      opacity: isOtpSent ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: 8.0, left: 4),
                            child: Text(
                              "OTP sent to ${phoneController.text.trim()}",
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: 8.0, left: 4),
                            child: Text(
                              "Enter OTP",
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          _buildOtpDigitBox(context),
                        ],
                      ),
                    ),
                  SizedBox(height: 20),
                  Theme(
                    data: ThemeData(
                      unselectedWidgetColor: Colors.white70,
                      checkboxTheme: CheckboxThemeData(
                        fillColor: MaterialStateProperty.resolveWith<Color?>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.selected)) {
                              return greenColor;
                            }
                            return Colors.transparent;
                          },
                        ),
                        checkColor: MaterialStateProperty.all(blackColor),
                        side: BorderSide(color: Colors.white70, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    child: CheckboxListTile(
                      value: agreeTcs,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (bool? value) {
                        setState(() {
                          agreeTcs = value!;
                        });
                      },
                      title: _buildTermsAndConditionsText(),
                    ),
                  ),
                  SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate() ||
                                !agreeTcs) {
                              if (!agreeTcs &&
                                  _formKey.currentState!.validate()) {
                                commToast(" Agree to Terms & Conditions");
                              }
                              return;
                            }
                            if (!isOtpSent) {
                              String phoneNumber = phoneController.text.trim();
                              bool userExists =
                                  await checkUserExists(phoneNumber);
                              if (userExists) {
                                sendOtpForLogin(phoneNumber);
                              } else {
                                _showUserNotFoundDialog(context);
                              }
                            } else {
                              verifyOtpAndSignIn();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: greenColor,
                      foregroundColor: blackColor,
                      padding: EdgeInsets.symmetric(vertical: 18),
                      textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                      shadowColor: greenColor.withOpacity(0.5),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(blackColor),
                              strokeWidth: 2,
                            ),
                          )
                        : Text(isOtpSent ? "Verify OTP" : "Send OTP"),
                  ),
                  SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Register(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: greenColor,
                          padding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          "Sign Up",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      cursorColor: blueColor,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(
        fontSize: 16,
        color: whiteColor,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon:
            prefixIcon != null ? Icon(prefixIcon, color: Colors.white70) : null,
        filled: true,
        fillColor: darkColor.withOpacity(0.5),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: blueColor, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2.0),
          borderRadius: BorderRadius.circular(12),
        ),
        errorStyle: TextStyle(color: Colors.redAccent, fontSize: 12),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }

  Widget _buildTermsAndConditionsText() {
    return InkWell(
      onTap: () async {
        final Uri url = Uri.parse(
            'https://videosalarm.com/videoalarm/terms-and-condition.php');
        try {
          if (!await launchUrl(url)) {
            throw Exception('Could not launch $url');
          }
        } catch (e) {
          commToast("Could not open Terms & Conditions.");
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "I agree to the ",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              TextSpan(
                text: "Terms & Conditions",
                style: TextStyle(
                  color: greenColor,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpDigitBox(BuildContext context) {
    return PinCodeTextField(
      appContext: context,
      length: 6,
      controller: TextEditingController(),
      focusNode: null,
      keyboardType: TextInputType.number,
      textStyle: TextStyle(
        fontSize: 20,
        color: whiteColor,
        fontWeight: FontWeight.bold,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      pinTheme: PinTheme(
        shape: PinCodeFieldShape.box,
        fieldHeight: 50,
        fieldWidth: 50,
        activeColor: blueColor,
        inactiveColor: Colors.white30,
        selectedColor: blueColor,
        errorBorderColor: Colors.redAccent,
        activeFillColor: darkColor.withOpacity(0.5),
        inactiveFillColor: darkColor.withOpacity(0.5),
        selectedFillColor: darkColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        borderWidth: 1.0,
        activeBorderWidth: 1.5,
        errorBorderWidth: 1.5,
        selectedBorderWidth: 1.5,
      ),
      enableActiveFill: true,
      onChanged: (value) {
        for (int i = 0; i < otpDigitControllers.length; i++) {
          if (i < value.length) {
            otpDigitControllers[i].text = value[i];
          } else {
            otpDigitControllers[i].text = '';
          }
        }
      },
      onCompleted: (value) {
        FocusScope.of(context).unfocus();
      },
      beforeTextPaste: (text) {
        return RegExp(r'^\d+$').hasMatch(text!) &&
            text.length <= otpDigitControllers.length;
      },
      validator: (value) {
        if (value == null || value.length < otpDigitControllers.length) {
          return "";
        }
        return null;
      },
      errorTextSpace: 0,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      animationType: AnimationType.none,
      cursorColor: blueColor,
    );
  }
}
