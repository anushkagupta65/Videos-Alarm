import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth import
import 'package:videos_alarm_app/screens/banner_video_list.dart';
import '../app_store/app_pref.dart';
import '../components/app_button.dart';
import '../app_store/secure_store.dart';
import '../components/app_style.dart';
import '../components/common_toast.dart';
import '../components/constant.dart';

class VerifyOTP extends StatefulWidget {
  final String mobileNumber;
  const VerifyOTP(
      {super.key, required this.mobileNumber, required String verificationId});

  @override
  State<VerifyOTP> createState() => _VerifyOTPState();
}

class _VerifyOTPState extends State<VerifyOTP> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController otpController = TextEditingController();
  bool isLoading = false;
  int _startTimer = 30;
  String verificationId = ''; // Store the verification ID

  // Timer for OTP resend
  void startTimer() {
    Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_startTimer == 0) {
        setState(() {
          timer.cancel();
        });
      } else {
        setState(() {
          _startTimer--;
        });
      }
    });
  }

  @override
  void initState() {
    sendOtp();
    startTimer();
    super.initState();
  }

  // Method to send OTP using Firebase
  void sendOtp() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+91 ${widget.mobileNumber}',
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verification or instant verification
        await FirebaseAuth.instance.signInWithCredential(credential);
        navigateToNextScreen();
      },
      verificationFailed: (FirebaseAuthException e) {
        commToast("OTP verification failed: ${e.message}");
      },
      codeSent: (String verId, int? resendToken) {
        setState(() {
          verificationId = verId;
        });
        commToast("OTP sent to +91 ${widget.mobileNumber}");
      },
      codeAutoRetrievalTimeout: (String verId) {
        setState(() {
          verificationId = verId;
        });
      },
    );
  }

  // Method to verify OTP
  void verifyOtp(String otp) async {
    try {
      setState(() {
        isLoading = true;
      });
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      navigateToNextScreen();
    } catch (e) {
      commToast("OTP verification failed: ${e.toString()}");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Navigate to next screen after successful verification
  void navigateToNextScreen() {
    AppPref.setUniqueToken();
    AppStore().setMobile(widget.mobileNumber);
    // Navigate to your next screen here (e.g., BottomBarTabs)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => BottomBarTabs()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackColor,
      appBar: AppBar(
        backgroundColor: darkColor,
        elevation: 0,
        centerTitle: false,
        leading: BackButton(color: whiteColor),
        title: Text("Verify OTP",
            style:
                TextStyle(color: whiteColor, fontWeight: w500, fontSize: fo18)),
      ),
      body: Padding(
        padding:
            EdgeInsets.fromLTRB(sidePadding, sidePadding, sidePadding, 0.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Image.asset(appLogo),
              ),
              SizedBox(height: sidePadding),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: "You will get OTP on ",
                  style: TextStyle(color: greyColor),
                  children: <TextSpan>[
                    TextSpan(
                      text: "+91 ${widget.mobileNumber}",
                      style: TextStyle(color: whiteColor),
                    ),
                    TextSpan(
                      text: " through SMS",
                      style: TextStyle(color: greyColor),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              TextFormField(
                maxLength: 6, // Firebase OTP is 6 digits
                controller: otpController,
                cursorColor: blueColor,
                keyboardType: TextInputType.number,
                style: TextStyle(
                    fontSize: fo18, fontWeight: w500, color: whiteColor),
                decoration: InputDecoration(
                  fillColor: darkColor,
                  filled: true,
                  counter: const Offstage(),
                  labelStyle: TextStyle(color: whiteColor, fontWeight: w400),
                  labelText: "Enter OTP",
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: grey300, width: 2),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: blueColor, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter OTP";
                  } else if (value.length != 6) {
                    return "Enter 6 digit OTP";
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              _startTimer != 0
                  ? RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: "Resend OTP in ",
                        style: TextStyle(color: greyColor),
                        children: <TextSpan>[
                          TextSpan(
                            text: "$_startTimer",
                            style: TextStyle(color: blueColor),
                          ),
                          TextSpan(
                            text: " seconds",
                            style: TextStyle(color: greyColor),
                          ),
                        ],
                      ),
                    )
                  : GestureDetector(
                      onTap: () {
                        setState(() {
                          _startTimer = 30;
                          sendOtp(); // Resend OTP
                          startTimer();
                        });
                      },
                      child: Text("Resend OTP",
                          style: TextStyle(
                              color: greenColor,
                              fontWeight: w500,
                              fontSize: fo16)),
                    ),
              const SizedBox(height: 30),
              CommonButton(
                child: isLoading
                    ? CircularProgressIndicator(color: whiteColor)
                    : Text("Verify OTP"),
                onTap: () {
                  if (_formKey.currentState!.validate()) {
                    verifyOtp(otpController.text.trim());
                  }
                },
              ),
              const Divider(),
            ],
          ),
        ),
      ),
    );
  }
}



// import 'dart:async';
// import 'package:flutter/gestures.dart';
// import 'package:flutter/material.dart';
// import 'package:videos_alarm_app/screens/banner_video_list.dart';
// import '../app_store/app_pref.dart';
// import '../components/app_button.dart';
// import '../app_store/secure_store.dart';
// import '../components/app_style.dart';
// import '../components/common_toast.dart';
// import '../components/constant.dart';
// import '../main.dart';

// class VerifyOTP extends StatefulWidget {
//   final String mobileNumber;
//   const VerifyOTP({super.key, required this.mobileNumber});

//   @override
//   State<VerifyOTP> createState() => _VerifyOTPState();
// }

// class _VerifyOTPState extends State<VerifyOTP> {
//   final _formKey = GlobalKey<FormState>();
// TextEditingController otpController = TextEditingController();


//   bool isLoading = false;
//   int _startTimer = 30;

//   void startTimer() {
//     Timer.periodic(const Duration(seconds: 1),(Timer timer) {
//       if (_startTimer == 0) {
//         setState(() {
//           timer.cancel();
//         });
//       } else {
//         setState(() {
//           _startTimer--;
//         });
//       }
//     },
//     );
//   }

//   @override
//   void initState() {
//     startTimer();
//     super.initState();
//   }



//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: blackColor,
//       appBar: AppBar(
//         backgroundColor: darkColor,
//         elevation: 0,
//         centerTitle: false,
//         leading: BackButton(color: whiteColor,),
//         title: Text("Verify OTP", style: TextStyle(color: whiteColor, fontWeight: w500, fontSize: fo18),),
//       ),

//       body: Padding(
//         padding: EdgeInsets.fromLTRB(sidePadding, sidePadding, sidePadding, 0.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               SizedBox(
//                   width: 100,
//                   height: 100,
//                   child: Image.asset(appLogo)),
//               SizedBox(height: sidePadding,),

//               RichText(
//                 textAlign: TextAlign.center,
//                 text: TextSpan(
//                   text: "You will get OTP on ",
//                   style: TextStyle(
//                     color: greyColor,
//                   ),
//                   children: <TextSpan>[
//                     TextSpan(
//                       text: "+91 ${widget.mobileNumber}",
//                       recognizer: TapGestureRecognizer()..onTap = () {},
//                       style: TextStyle(
//                         color: whiteColor,
//                       ),
//                     ),
//                     TextSpan(
//                       text: " through sms",
//                       recognizer: TapGestureRecognizer()..onTap = () {},
//                       style: TextStyle(
//                         color: greyColor,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               SizedBox(height: 10,),

//               TextFormField(
//                 maxLength: 4,
//                 controller: otpController,
//                 cursorColor:blueColor,
//                 keyboardType: TextInputType.number,
//                 style: TextStyle(fontSize: fo18, fontWeight: w500, color: whiteColor),
//                 decoration: InputDecoration(
//                     fillColor: darkColor,
//                     filled: true,
//                     counter: const Offstage(),
//                     labelStyle: TextStyle(color: whiteColor, fontWeight: w400),
//                     labelText: "Enter OTP",
//                     enabledBorder: UnderlineInputBorder(
//                       borderSide: BorderSide(color: grey300, width: 2),),
//                     focusedBorder: UnderlineInputBorder(
//                       borderSide: BorderSide(color: blueColor, width: 2),),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return "Enter OTP";
//                   }else if(value.length != 4){
//                     return "Enter 4 digit OTP";
//                   }
//                   return null;
//                 },
//               ),

//               SizedBox(height: 10,),

//               _startTimer !=0?
//               RichText(
//                 textAlign: TextAlign.center,
//                 text: TextSpan(
//                   text: "Resend OTP in ",
//                   style: TextStyle(
//                     color: greyColor,
//                   ),
//                   children: <TextSpan>[
//                     TextSpan(
//                       text: "$_startTimer",
//                       recognizer: TapGestureRecognizer()..onTap = () {},
//                       style: TextStyle(
//                         color: blueColor,
//                       ),
//                     ),
//                     TextSpan(
//                       text: " Seconds",
//                       recognizer: TapGestureRecognizer()..onTap = () {},
//                       style: TextStyle(
//                         color: greyColor,
//                       ),
//                     ),
//                   ],
//                 ),
//               ):

//               GestureDetector(
//                   onTap: ()async{
//                     setState(() {
//                       _startTimer = 30;
//                       startTimer();
//                     });
//                     client.userLogIn(widget.mobileNumber).then((value){
//                     }).onError((error, stackTrace){
//                       commToast("Something went wrong");
//                     });

//                   },
//                   child: Text("Resend OTP", style: TextStyle(color: greenColor, fontWeight: w500, fontSize: fo16, ),)),

//               const SizedBox(height: 30),



//               CommonButton(
//                   child: isLoading ==true? CircularProgressIndicator(color: whiteColor,): Text("Verify OTP"),
//                   onTap: (){
//                     if(_formKey.currentState!.validate()){
//                         setState(() {isLoading = true;});
//                         client.otpVarification(widget.mobileNumber, otpController.text.toString()).then((value){
//                           setState(() {isLoading = false;});
//                           logger.i(value);
//                           if(value["success"] == true){
//                             AppPref.setUniqueToken();
//                             AppStore().setToken(value["token"].toString());
//                             AppStore().setMobile(value["user"]["mobile"].toString());
//                             AppStore().setUserId(value["user"]["userid"].toString());

//                             Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>BottomBarTabs()));
//                           }else{
//                             commToast("${value["message"].toString()}");
//                           }
//                         }).onError((error, stackTrace){
//                           setState(() {isLoading = false;});
//                           commToast("Something went wrong");
//                         });
//                       }
//                   }),

//               const Divider(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
