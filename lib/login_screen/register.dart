import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/Get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_alarm_app/login_screen/login_screen.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';
import 'package:videos_alarm_app/screens/banner_video_list.dart';
import 'package:videos_alarm_app/device_guard.dart';
import '../components/app_style.dart';
import '../components/common_toast.dart';
import '../components/constant.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class Register extends StatefulWidget {
  const Register({Key? key}) : super(key: key);

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool agreeTcs = false;
  bool isOtpSent = false;
  bool isVerifyingOtp = false;

  // Controllers for First Name, Last Name, Phone
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  // Controllers and FocusNodes for OTP digits
  List<TextEditingController> otpDigitControllers =
      List.generate(6, (_) => TextEditingController());
  List<FocusNode> otpFocusNodes = List.generate(6, (_) => FocusNode());

  // Not strictly needed for registration logic itself, but kept if used elsewhere
  final VideoController videoController = Get.put(VideoController());

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    for (var controller in otpDigitControllers) {
      controller.dispose();
    }
    for (var focusNode in otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  // Function to get the complete OTP string from the separate digit controllers
  String get _otpFromBoxes {
    return otpDigitControllers.map((controller) => controller.text).join();
  }

  // Function to show dialog for already registered user
  void _showAlreadyRegisteredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: darkColor,
          title: Text(
            "Number Already Registered",
            style: TextStyle(
              color: whiteColor,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          content: Text(
            "This number has already been registered. Kindly login with the same phone number.",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Get.off(() => const LogInScreen());
              },
              style: TextButton.styleFrom(
                foregroundColor: greenColor,
              ),
              child: Text(
                "Go to Login",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  // --- OTP Sending Logic ---
  Future<void> sendOtp(String phoneNumber) async {
    setState(() {
      isLoading = true;
    });

    // Check if the phone number is already registered in Firestore
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phoneNumber)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          isLoading = false;
        });
        _showAlreadyRegisteredDialog();
        return;
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      commToast('Error checking phone number. Please try again.');
      return;
    }

    // Check for the special demo number
    if (phoneNumber == '1000000000') {
      setState(() {
        isOtpSent = true;
        isLoading = false;
      });
      commToast('OTP sent to $phoneNumber (Simulated)');
      return;
    }

    // Use real API endpoint for non-demo numbers
    const String apiUrl = 'http://165.22.215.103:3066/sendOtp';

    Map<String, String> headers = {'Content-Type': 'application/json'};
    Map<String, dynamic> body = {'phone': phoneNumber};

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
      commToast('Failed to send OTP. Please try again.');
    }
  }

  Future<void> verifyOtpAndRegister() async {
    final String otp = _otpFromBoxes;
    final String phone = phoneController.text.trim();
    final String firstName = firstNameController.text.trim();
    final String lastName = lastNameController.text.trim();
    final String fullName =
        '$firstName $lastName'; // Combine first and last name

    if (otp.length != 6) {
      commToast('Please enter the 6-digit OTP');
      return;
    }
    if (firstName.isEmpty) {
      commToast('Please enter your first name');
      return;
    }
    if (lastName.isEmpty) {
      commToast('Please enter your last name');
      return;
    }

    setState(() {
      isVerifyingOtp = true;
    });

    // Demo Phone Number & OTP
    if (phone == '1000000000' && otp == '000000') {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isTestUser', true);
      setState(() {
        isVerifyingOtp = false;
      });
      commToast('Registration Successful! (Simulated)');
      Get.offAll(() => BottomBarTabs(initialIndex: 0));
      return;
    }

    const String apiUrl = 'http://165.22.215.103:3066/verifyOtp';
    Map<String, String> headers = {'Content-Type': 'application/json'};
    Map<String, dynamic> body = {'phone': phone, 'otp': otp};

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
            await FirebaseAuth.instance.signInWithCustomToken(customToken);
        User? user = userCredential.user;

        if (user != null) {
          FirebaseFirestore.instance.runTransaction((transaction) async {
            DocumentReference userDocRef =
                FirebaseFirestore.instance.collection('users').doc(user.uid);

            transaction.set(userDocRef, {
              'name': fullName,
              'phone': phone,
              'releaseDate': FieldValue.serverTimestamp(),
              'lastLogin': FieldValue.serverTimestamp(),
            });
          }).then((_) async {
            // Directly store device info for new user
            await validateAndAddDevice(user.uid, context);
            setState(() {
              isVerifyingOtp = false;
            });
            commToast('Registration Successful!');
            Get.offAll(() => BottomBarTabs(initialIndex: 0));
          }).catchError((error) {
            commToast("Error saving user data: $error");
            setState(() {
              isVerifyingOtp = false;
            });
          });
        } else {
          commToast("Failed to register. Please try again.");
          setState(() {
            isVerifyingOtp = false;
          });
        }
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? 'OTP verification failed';
        commToast(errorMessage);
        setState(() {
          isVerifyingOtp = false;
        });
      }
    } catch (e) {
      commToast('Registration failed. Please try again.');
      setState(() {
        isVerifyingOtp = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: whiteColor),
        title: Text(
          "Create Account",
          style: TextStyle(
            color: whiteColor,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
      ),
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
        padding: EdgeInsets.symmetric(horizontal: sidePadding, vertical: 32),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    margin: EdgeInsets.only(bottom: 48),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: Image.asset(appLogo),
                    ),
                  ),

                  // First Name Input
                  _buildTextFormField(
                    controller: firstNameController,
                    labelText: "First Name",
                    prefixIcon: Icons.person_outline,
                    validator: (value) => value == null || value.isEmpty
                        ? "Enter your first name"
                        : null,
                    readOnly: isOtpSent,
                    capitalizeFirst: true, // Enable first letter capitalization
                  ),
                  SizedBox(height: 20),

                  // Last Name Input
                  _buildTextFormField(
                    controller: lastNameController,
                    labelText: "Last Name",
                    prefixIcon: Icons.person_outline,
                    validator: (value) => value == null || value.isEmpty
                        ? "Enter your last name"
                        : null,
                    readOnly: isOtpSent,
                    capitalizeFirst: true, // Enable first letter capitalization
                  ),
                  SizedBox(height: 20),

                  // Phone Number Input
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
                    readOnly: isOtpSent,
                  ),
                  SizedBox(height: 20),

                  // OTP Input (Shown only after OTP is sent)
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
                  if (isOtpSent) SizedBox(height: 20),

                  // Terms and Conditions
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

                  // Action Button (Send OTP / Verify OTP & Register)
                  ElevatedButton(
                    onPressed: isLoading || isVerifyingOtp
                        ? null
                        : () {
                            if (!_formKey.currentState!.validate() ||
                                !agreeTcs) {
                              if (!agreeTcs &&
                                  _formKey.currentState!.validate()) {
                                commToast("Agree to Terms & Conditions");
                              }
                              return;
                            }
                            if (!isOtpSent) {
                              sendOtp(phoneController.text.trim());
                            } else {
                              verifyOtpAndRegister();
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
                    child: isOtpSent && isVerifyingOtp
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(blackColor),
                              strokeWidth: 2,
                            ),
                          )
                        : isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(blackColor),
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(isOtpSent
                                ? "Verify OTP & Register"
                                : "Send OTP"),
                  ),
                  SizedBox(height: 40),

                  // Link to Login Screen
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account?",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Get.off(() => const LogInScreen());
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: greenColor,
                          padding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          "Sign In",
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

  // --- Helper Widgets ---
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
    bool readOnly = false,
    bool capitalizeFirst = false, // New parameter for capitalization
  }) {
    return TextFormField(
      controller: controller,
      cursorColor: blueColor,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      style: TextStyle(
        fontSize: 16,
        color: readOnly ? Colors.white54 : whiteColor,
      ),
      inputFormatters: capitalizeFirst
          ? [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                if (newValue.text.isEmpty) return newValue;
                String newText = newValue.text.trimLeft();
                if (newText.isNotEmpty) {
                  newText = newText[0].toUpperCase() +
                      newText.substring(1).toLowerCase();
                }
                return TextEditingValue(
                  text: newText,
                  selection: TextSelection.collapsed(offset: newText.length),
                );
              }),
            ]
          : null,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon:
            prefixIcon != null ? Icon(prefixIcon, color: Colors.white70) : null,
        filled: true,
        fillColor:
            readOnly ? darkColor.withOpacity(0.3) : darkColor.withOpacity(0.5),
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
                  decorationColor: greenColor,
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
