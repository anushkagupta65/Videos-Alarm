import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videos_alarm_app/components/common_toast.dart';
import 'package:videos_alarm_app/login_screen/login_screen.dart';
import 'package:videos_alarm_app/screens/banner_video_list.dart';
import 'package:videos_alarm_app/screens/subscriptions.dart';
import '../components/app_style.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackColor,
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
            child: ListTile(
              title: Text("About Us"),
              titleTextStyle: TextStyle(color: whiteColor),
              tileColor: whiteColor.withOpacity(0.05),
              trailing:
                  Icon(Icons.arrow_forward_ios, size: 16, color: whiteColor),
              onTap: () async {
                final Uri url = Uri.parse(
                    'https://videosalarm.com/videoalarm/about-us.php');
                if (!await launchUrl(url)) {
                  throw Exception('Could not launch $url');
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
            child: ListTile(
              title: const Text("Terms and Conditions"),
              titleTextStyle: TextStyle(color: whiteColor),
              tileColor: whiteColor.withOpacity(0.05),
              trailing:
                  Icon(Icons.arrow_forward_ios, size: 16, color: whiteColor),
              onTap: () async {
                final Uri url = Uri.parse(
                    'https://videosalarm.com/videoalarm/terms-and-condition.php');
                if (!await launchUrl(url)) {
                  throw Exception('Could not launch $url');
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
            child: ListTile(
              title: const Text("Privacy Policy"),
              titleTextStyle: TextStyle(color: whiteColor),
              tileColor: whiteColor.withOpacity(0.05),
              trailing:
                  Icon(Icons.arrow_forward_ios, size: 16, color: whiteColor),
              onTap: () async {
                final Uri url =
                    Uri.parse('https://videosalarm.com/privacy-policy.html');
                if (!await launchUrl(url)) {
                  throw Exception('Could not launch $url');
                }
              },
            ),
          ),
          // Padding(
          //   padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
          //   child: ListTile(
          //     title: const Text("Subscriptions"),
          //     titleTextStyle: TextStyle(color: whiteColor),
          //     tileColor: whiteColor.withOpacity(0.05),
          //     trailing:
          //         Icon(Icons.arrow_forward_ios, size: 16, color: whiteColor),
          //     onTap: () async {
          //       Get.to(() => SubscriptionsScreen());
          //     },
          //   ),
          // ),
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
            child: ListTile(
              title: Text(FirebaseAuth.instance.currentUser != null
                  ? 'Logout'
                  : 'Login'),
              // title: Text(
              //     AppPref.getUniqueToken() !=""? "Logout":"Login"),
              titleTextStyle: TextStyle(color: whiteColor),
              tileColor: whiteColor.withOpacity(0.05),
              trailing:
                  Icon(Icons.arrow_forward_ios, size: 16, color: whiteColor),
              onTap: () async {
                if (FirebaseAuth.instance.currentUser != null) {
                  // If the user is logged in, perform logout
                  await FirebaseAuth.instance
                      .signOut(); // Log out from Firebase
                  // ScaffoldMessenger.of(context).showSnackBar(
                  //     SnackBar(content: Text("Logout successfully")));
                  setState(() {
                    // Refresh UI to show "Login" after logout
                    Get.off(() => LogInScreen());
                  });
                } else {
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (context) => LogInScreen()));
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
            child: ListTile(
              title: const Text("Delete Account"),
              titleTextStyle: TextStyle(color: Colors.red),
              tileColor: whiteColor.withOpacity(0.05),
              trailing: Icon(Icons.delete, size: 16, color: Colors.red),
              onTap: () async {
                _showDeleteConfirmationDialog(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: blackColor,
          title: const Text(
            'Delete Account',
            style: TextStyle(color: Colors.red),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Are you sure you want to delete your account?',
                  style: TextStyle(color: whiteColor),
                ),
                Text(
                  'This action cannot be undone.',
                  style: TextStyle(color: whiteColor),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(color: whiteColor),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                _deleteAccount();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Mark the user as deleted in Firestore
        final userDoc = FirebaseFirestore.instance
            .collection('users') // Replace 'users' with your collection name
            .doc(user.uid);

        await userDoc.update({'deleted': true});

        // 2. Sign out the user
        await FirebaseAuth.instance.signOut();
        commToast(
            "Account marked for deletion. Please log in again to permanently delete your account");
        Get.offAll(() => LogInScreen());
      } else {
        commToast("No user is currently logged in.");
      }
    } catch (e) {
      print("Error deleting account: $e");
      commToast("Failed to mark account for deletion. Please try again.");
    }
  }
}
