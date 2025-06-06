import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_alarm_app/login_screen/login_screen.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';
import 'package:videos_alarm_app/screens/banner_video_list.dart';
import '../components/app_style.dart';
import '../components/common_toast.dart';
import '../components/constant.dart';
import 'package:flutter/services.dart'; // Import for input formatters
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http; // Import for API calls

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
  bool isVerifyingOtp = false; // New flag for Verify OTP button loader

  // Controllers for Name, Phone
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  // Controllers and FocusNodes for OTP digits
  List<TextEditingController> otpDigitControllers =
      List.generate(6, (_) => TextEditingController());
  List<FocusNode> otpFocusNodes = List.generate(6, (_) => FocusNode());

  // Not strictly needed for registration logic itself, but kept if used elsewhere
  final VideoController videoController = Get.put(VideoController());

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    // Dispose all OTP digit controllers and focus nodes
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

  // --- OTP Sending Logic ---
  Future<void> sendOtp(String phoneNumber) async {
    setState(() {
      isLoading = true;
    });

    // Check for the special demo number
    if (phoneNumber == '1000000000') {
      setState(() {
        isOtpSent = true;
        isLoading = false;
      });
      commToast('OTP sent to $phoneNumber (Simulated)');
      return; // Exit early - use simulated OTP
    }

    // Use real API endpoint for non-demo numbers
    const String apiUrl =
        'http://165.22.215.103:3066/sendOtp'; // Ensure IP/Port is right

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
          isOtpSent = true; // Set flag to show OTP field
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
    final String otp = _otpFromBoxes; // Get OTP from the digit boxes
    final String phone = phoneController.text.trim();
    final String name = nameController.text.trim(); // Get name

    if (otp.length != 6) {
      commToast('Please enter the 6-digit OTP');
      return;
    }
    if (name.isEmpty) {
      commToast('Please enter your name');
      return;
    }

    setState(() {
      isVerifyingOtp = true; // Set loader for Verify OTP
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

        // Sign in with Firebase using the custom token
        UserCredential userCredential =
            await FirebaseAuth.instance.signInWithCustomToken(customToken);
        User? user = userCredential.user;

        if (user != null) {
          // Using a transaction for robust Firestore updates
          FirebaseFirestore.instance.runTransaction((transaction) async {
            DocumentReference userDocRef =
                FirebaseFirestore.instance.collection('users').doc(user.uid);

            // For registration, always set the user data (new user)
            transaction.set(userDocRef, {
              'name': name,
              'phone': phone,
              'releaseDate': FieldValue.serverTimestamp(),
              'lastLogin': FieldValue.serverTimestamp(),
            });
          }).then((_) {
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

  // --- OTP Verification and Registration Logic ---
  // Future<void> verifyOtpAndRegister() async {
  //   final String otp = _otpFromBoxes; // Get OTP from the digit boxes
  //   final String phone = phoneController.text.trim();
  //   final String name = nameController.text.trim(); // Get name

  //   if (otp.length != 6) {
  //     commToast('Please enter the 6-digit OTP');
  //     return;
  //   }
  //   if (name.isEmpty) {
  //     commToast('Please enter your name');
  //     return;
  //   }

  //   setState(() {
  //     isLoading = true;
  //   });

  //   // Demo Phone Number
  //   if (phone == '1000000000' && otp == '000000') {
  //     setState(() {
  //       isLoading = false;
  //     });
  //     commToast('Registration Successful! (Simulated)');
  //     Get.offAll(() => BottomBarTabs(initialIndex: 0));
  //     return; // Exit early
  //   }

  //   // REAL Number Verification
  //   const String apiUrl = 'http://165.22.215.103:3066/verifyOtp';
  //   Map<String, String> headers = {'Content-Type': 'application/json'};
  //   Map<String, dynamic> body = {'phone': phone, 'otp': otp};

  //   try {
  //     final response = await http.post(
  //       Uri.parse(apiUrl),
  //       headers: headers,
  //       body: jsonEncode(body),
  //     );

  //     if (response.statusCode == 200) {
  //       // You would likely receive a success message or some data here
  //       setState(() {
  //         isLoading = false;
  //       });
  //       commToast('Registration Successful!'); // Adjust message if needed
  //       Get.offAll(() => BottomBarTabs(initialIndex: 0));
  //     } else {
  //       final errorBody = json.decode(response.body);
  //       final errorMessage = errorBody['message'] ?? 'OTP verification failed';
  //       commToast(errorMessage);
  //       setState(() {
  //         isLoading = false;
  //       });
  //     }
  //   } catch (e) {
  //     commToast('Registration failed. Please try again.');
  //     setState() {
  //       isLoading = false;
  //     }
  //   }
  // }

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
            begin: Alignment.topLeft, // Consistent gradient
            end: Alignment.bottomRight,
            colors: [
              darkColor.withOpacity(0.8),
              blackColor,
              darkColor.withOpacity(0.8),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        padding: EdgeInsets.symmetric(
            horizontal: sidePadding, vertical: 32), // Consistent padding
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
                    margin: EdgeInsets.only(bottom: 48), // Consistent margin
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 120, // Consistent logo size
                      height: 120,
                      child: Image.asset(blackAppLogo),
                    ),
                  ),

                  // Name Input
                  _buildTextFormField(
                    controller: nameController,
                    labelText: "Full Name",
                    prefixIcon: Icons.person_outline,
                    validator: (value) => value == null || value.isEmpty
                        ? "Enter your name"
                        : null,
                    readOnly: isOtpSent, // Make read-only after OTP is sent
                  ),
                  SizedBox(height: 20), // Consistent spacing

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
                    readOnly: isOtpSent, // Make read-only after OTP is sent
                  ),
                  SizedBox(height: 20), // Consistent spacing

                  // OTP Input (Shown only after OTP is sent)
                  if (isOtpSent)
                    AnimatedOpacity(
                      opacity: isOtpSent ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            // Message about OTP sent
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
                            // Label for OTP input
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
                  if (isOtpSent)
                    SizedBox(
                        height:
                            20), // Consistent spacing only if OTP section is visible

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
                  SizedBox(height: 32), // Consistent spacing

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
                            // Decide action based on whether OTP has been sent
                            if (!isOtpSent) {
                              sendOtp(phoneController.text.trim());
                            } else {
                              verifyOtpAndRegister();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: greenColor,
                      foregroundColor: blackColor,
                      padding: EdgeInsets.symmetric(
                          vertical: 18), // Consistent padding
                      textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            12), // Consistent border radius
                      ),
                      elevation: 5, // Added elevation for depth
                      shadowColor: greenColor.withOpacity(0.5), // Subtle shadow
                    ),
                    child: isOtpSent && isVerifyingOtp
                        ? SizedBox(
                            width: 20, // Consistent size for indicator
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(blackColor),
                              strokeWidth: 2, // Thinner progress indicator
                            ),
                          )
                        : isLoading
                            ? SizedBox(
                                width: 20, // Consistent size for indicator
                                height: 20,
                                child: CircularProgressIndicator(
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(blackColor),
                                  strokeWidth: 2, // Thinner progress indicator
                                ),
                              )
                            : Text(isOtpSent
                                ? "Verify OTP & Register"
                                : "Send OTP"), // Dynamic text
                  ),
                  SizedBox(height: 40), // Consistent spacing

                  // Link to Login Screen
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account?",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15, // Consistent font size
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Get.off(
                              () => const LogInScreen()); // Use GetX navigation
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: greenColor,
                          padding: EdgeInsets.symmetric(
                              horizontal: 8), // Consistent padding
                        ),
                        child: Text(
                          "Sign In",
                          style: TextStyle(
                            fontSize: 15, // Consistent font size
                            fontWeight: FontWeight.w700, // Bolder
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

  // --- Helper Widgets (Updated with consistent styling) ---

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
    bool readOnly = false, // Added readOnly parameter
  }) {
    return TextFormField(
      controller: controller,
      cursorColor: blueColor, // Keep accent color for cursor
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly, // Use the parameter here
      style: TextStyle(
        fontSize: 16,
        color: readOnly ? Colors.white54 : whiteColor, // Dim text if read-only
      ),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
          color: Colors.white70, // Slightly muted label
          fontWeight: FontWeight.w400,
        ),
        prefixIcon:
            prefixIcon != null ? Icon(prefixIcon, color: Colors.white70) : null,
        filled: true,
        fillColor: readOnly
            ? darkColor.withOpacity(0.3)
            : darkColor.withOpacity(0.5), // Different fill if read-only
        border: OutlineInputBorder(
          borderSide: BorderSide.none, // No border in unfocused state
          borderRadius: BorderRadius.circular(12), // Consistent border radius
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
              color: blueColor, width: 1.5), // Accent border when focused
          borderRadius: BorderRadius.circular(12), // Consistent border radius
        ),
        errorBorder: OutlineInputBorder(
          // Explicit error border
          borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
          borderRadius: BorderRadius.circular(12), // Consistent border radius
        ),
        focusedErrorBorder: OutlineInputBorder(
          // Error border when focused
          borderSide: BorderSide(color: Colors.red, width: 2.0),
          borderRadius: BorderRadius.circular(12), // Consistent border radius
        ),
        errorStyle: TextStyle(
            color: Colors.redAccent,
            fontSize: 12), // Slightly smaller error text
        contentPadding: EdgeInsets.symmetric(
            horizontal: 16, vertical: 14), // Added content padding
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
        // Added padding for better touch area
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: RichText(
          // Using RichText for more flexibility in styling
          text: TextSpan(
            children: [
              TextSpan(
                text: "I agree to the ",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14, // Consistent font size
                ),
              ),
              TextSpan(
                text: "Terms & Conditions",
                style: TextStyle(
                  color: greenColor, // Accent color for link
                  fontWeight: FontWeight.w600, // Bolder
                  decoration: TextDecoration.underline,
                  decorationColor:
                      greenColor, // Make underline match text color
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
      focusNode: null, // Optional: manage focus externally if needed
      keyboardType: TextInputType.number,
      textStyle: TextStyle(
        fontSize: 20,
        color: whiteColor, // White digit text
        fontWeight: FontWeight.bold,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly, // Only allow digits
      ],
      pinTheme: PinTheme(
        shape: PinCodeFieldShape.box,
        fieldHeight: 50, // Match original height
        fieldWidth: 50, // Match original width
        activeColor: blueColor, // Accent border when focused
        inactiveColor: Colors.white30, // Subtle border when unfocused
        selectedColor: blueColor, // Border when selected
        errorBorderColor: Colors.redAccent, // Error border
        activeFillColor: darkColor.withOpacity(0.5), // Consistent fill color
        inactiveFillColor: darkColor.withOpacity(0.5), // Consistent fill color
        selectedFillColor: darkColor.withOpacity(0.5), // Consistent fill color
        borderRadius: BorderRadius.circular(12), // Consistent border radius
        borderWidth: 1.0, // Default border width
        activeBorderWidth: 1.5, // Focused border width
        errorBorderWidth: 1.5, // Error border width
        selectedBorderWidth: 1.5, // Selected border width
      ),
      enableActiveFill: true, // Enable fill color
      onChanged: (value) {
        // Handle OTP input changes
        // You can update your controllers or state here if needed
        for (int i = 0; i < otpDigitControllers.length; i++) {
          if (i < value.length) {
            otpDigitControllers[i].text = value[i];
          } else {
            otpDigitControllers[i].text = '';
          }
        }
      },
      onCompleted: (value) {
        // When all boxes are filled, unfocus the keyboard
        FocusScope.of(context).unfocus();
      },
      beforeTextPaste: (text) {
        // Allow pasting only if it's numeric and matches length
        return RegExp(r'^\d+$').hasMatch(text!) &&
            text.length <= otpDigitControllers.length;
      },
      validator: (value) {
        if (value == null || value.length < otpDigitControllers.length) {
          return "";
        }
        return null;
      },
      errorTextSpace: 0, // Hide default error text
      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Space boxes evenly
      animationType: AnimationType.none, // Disable animations for simplicity
      cursorColor: blueColor, // Match focused border color
    );
  }
}
