import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videos_alarm_app/login_screen/register.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';
import 'package:videos_alarm_app/screens/banner_video_list.dart';
import '../components/app_style.dart';
import '../components/constant.dart';
import 'package:flutter/services.dart'; // Import for input formatters
import 'package:fluttertoast/fluttertoast.dart'; // Import fluttertoast

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

  // Function to get the complete OTP string from the separate digit controllers
  String get _otpFromBoxes {
    return otpDigitControllers.map((controller) => controller.text).join();
  }

  // --- New function to check if user exists ---
  Future<bool> checkUserExists(String phoneNumber) async {
    setState(() {
      isLoading = true;
    });

    // Special Demo Number
    if (phoneNumber == '1002003000') {
      setState(() {
        isLoading = false;
      });
      return true; // Demo user exists
    }

    // Hypothetical API endpoint to check user existence
    const String apiUrl =
        'http://165.22.215.103:3066/checkUserExists'; // Replace with your actual endpoint

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
        return responseData['exists'] ??
            false; // Assuming your API returns a boolean 'exists'
      } else {
        // Handle potential backend errors during the check
        final errorBody = json.decode(response.body);
        final errorMessage =
            errorBody['message'] ?? 'Failed to check user existence';
        commToast('Error checking user: $errorMessage');
        return false; // Assume user doesn't exist or an error occurred
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      commToast('Error checking user: Please try again.');
      print('Error checking user existence: $e');
      return false; // Assume user doesn't exist or an error occurred
    }
  }

  Future<void> sendOtpForLogin(String phoneNumber) async {
    // Renamed function for clarity
    setState(() {
      isLoading = true;
    });

    // Special Demo Number:  Skip API call
    if (phoneNumber == '1002003000') {
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
        // Improved error handling message
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? 'Failed to send OTP';
        throw Exception(errorMessage);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // Display the specific error if available
      commToast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> verifyOtpAndSignIn() async {
    final String otp = _otpFromBoxes; // Get OTP from the digit boxes
    final String phone = phoneController.text.trim();

    if (otp.length != 6) {
      // Check if all 6 digits are entered
      commToast('Please enter the 6-digit OTP');
      return;
    }

    setState(() {
      isLoading = true;
    });

    // Demo Phone Number & OTP
    if (phone == '1002003000' && otp == '000000') {
      setState(() {
        isLoading = false;
      });
      commToast('Login Successful! (Simulated)');
      Get.offAll(() => BottomBarTabs(initialIndex: 0));
      return; //Exit early
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
          // Using a transaction for more robust Firestore updates
          FirebaseFirestore.instance.runTransaction((transaction) async {
            DocumentReference userDocRef =
                FirebaseFirestore.instance.collection('users').doc(user.uid);
            DocumentSnapshot snapshot = await transaction.get(userDocRef);

            // No need to set if it doesn't exist on login, only update lastLogin
            if (snapshot.exists) {
              transaction.update(userDocRef, {
                'lastLogin': FieldValue.serverTimestamp(),
              });
            }
            // If user doesn't exist in Firestore here, something is wrong with the flow
            // as the checkUserExists should have prevented this.
          }).then((_) {
            setState(() {
              isLoading = false;
            });
            Get.offAll(() => BottomBarTabs(
                initialIndex: 0)); // Use offAll after successful login
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
        // Improved error handling message
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

  // --- Function to show the User Not Found Dialog ---
  void _showUserNotFoundDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: darkColor, // Set dialog background to dark color
          shape: RoundedRectangleBorder(
            // Add rounded corners
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(color: Colors.white12), // Subtle border
          ),
          title: Text(
            "User Not Found",
            style: TextStyle(
              color: whiteColor, // White color for title
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "It seems you don't have an account. Would you like to register?",
            style: TextStyle(
              color: Colors.white70, // Muted white for content text
              fontSize: 16,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                "Cancel",
                style:
                    TextStyle(color: Colors.white60), // Muted color for cancel
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the dialog
                phoneController.clear(); // Clear the phone number field
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    greenColor, // Green background for primary action
                foregroundColor: blackColor, // Black text color
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(8), // Rounded button corners
                ),
              ),
              child: Text("Register"),
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the dialog
                Get.off(() =>
                    const Register()); // Navigate to the registration page
              },
            ),
          ],
        );
      },
    );
  }

  //** START HERE - Replace the old commToast */
  void commToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT, // You can use Toast.LENGTH_LONG
      gravity: ToastGravity.BOTTOM, // Or other positions like TOP, CENTER
      timeInSecForIosWeb: 1, // iOS-specific duration
      backgroundColor: Colors.grey[800], // Adjust color as desired
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }
  //** END commToast */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, // Slightly different gradient angle
            end: Alignment.bottomRight,
            colors: [
              // Adjusting gradient colors for a richer dark theme
              darkColor.withOpacity(0.8), // Slightly less opaque dark
              blackColor,
              darkColor.withOpacity(0.8),
            ],
            stops: const [0.0, 0.5, 1.0], // Adjusted stops
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: sidePadding,
                vertical: 32), // Added vertical padding
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    margin:
                        EdgeInsets.only(bottom: 48), // Increased bottom margin
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 120, // Slightly larger logo
                      height: 120,
                      child: Image.asset(blackAppLogo),
                    ),
                  ),

                  // Phone Number Input OR OTP Message and Fields
                  if (!isOtpSent) // Show phone input if OTP is not sent
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

                  if (isOtpSent) // Show OTP message and fields if OTP is sent
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
                              "OTP sent to ${phoneController.text.trim()}", // Display the number OTP was sent to
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

                  SizedBox(
                      height:
                          20), // Spacing consistent regardless of which input is shown

                  // Terms and Conditions
                  Theme(
                    data: ThemeData(
                      unselectedWidgetColor:
                          Colors.white70, // Slightly less bright for harmony
                      checkboxTheme: CheckboxThemeData(
                        fillColor: MaterialStateProperty.resolveWith<Color?>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.selected)) {
                              return greenColor; // Active color
                            }
                            return Colors.transparent; // Unselected color
                          },
                        ),
                        checkColor: MaterialStateProperty.all(
                            blackColor), // Checkmark color
                        side: BorderSide(
                            color: Colors.white70, width: 1.5), // Border color
                        shape: RoundedRectangleBorder(
                          // Rounded checkbox
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
                  SizedBox(height: 32), // Increased spacing

                  // Action Button
                  ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            // Made the onPressed async
                            // Disable button when loading
                            if (!_formKey.currentState!.validate() ||
                                !agreeTcs) {
                              if (!agreeTcs &&
                                  _formKey.currentState!.validate()) {
                                // Show toast only if validation passes but T&C not agreed
                                commToast("Agree to Terms & Conditions");
                              }
                              return;
                            }
                            if (!isOtpSent) {
                              // --- Check user existence before sending OTP ---
                              String phoneNumber = phoneController.text.trim();
                              bool userExists =
                                  await checkUserExists(phoneNumber);

                              if (userExists) {
                                sendOtpForLogin(
                                    phoneNumber); // Proceed to send OTP if user exists
                              } else {
                                // User does not exist, show dialog and navigate to register
                                _showUserNotFoundDialog(context);
                              }
                            } else {
                              verifyOtpAndSignIn(); // Verify OTP if already sent
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
                      elevation: 5, // Added elevation for depth
                      shadowColor: greenColor.withOpacity(0.5), // Subtle shadow
                    ),
                    child: isLoading
                        ? SizedBox(
                            // Use SizedBox for consistent size
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(blackColor),
                              strokeWidth: 2, // Thinner progress indicator
                            ),
                          )
                        : Text(isOtpSent ? "Verify OTP" : "Send OTP"),
                  ),

                  SizedBox(height: 40), // Increased spacing

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15, // Slightly smaller font size
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
                          padding: EdgeInsets.symmetric(
                              horizontal: 8), // Reduced horizontal padding
                        ),
                        child: Text(
                          "Sign Up",
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
      cursorColor: blueColor, // Keep accent color for cursor
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(
        fontSize: 16,
        color: whiteColor, // White text on dark background
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
        fillColor: darkColor.withOpacity(0.5), // Slightly less opaque fill
        border: OutlineInputBorder(
          borderSide: BorderSide.none, // No border in unfocused state
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
              color: blueColor, width: 1.5), // Accent border when focused
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          // Explicit error border
          borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedErrorBorder: OutlineInputBorder(
          // Error border when focused
          borderSide: BorderSide(color: Colors.red, width: 2.0),
          borderRadius: BorderRadius.circular(12),
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
                  fontSize: 14,
                ),
              ),
              TextSpan(
                text: "Terms & Conditions",
                style: TextStyle(
                  color: greenColor, // Accent color for link
                  fontWeight: FontWeight.w600, // Bolder
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
