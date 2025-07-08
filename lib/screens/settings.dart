import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videos_alarm_app/components/common_toast.dart';
import 'package:videos_alarm_app/login_screen/login_screen.dart';
import 'package:videos_alarm_app/screens/subscriptions.dart';
import 'package:videos_alarm_app/screens/support_screen.dart';
import 'package:videos_alarm_app/screens/watch_later.dart';
import '../components/app_style.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsPage> {
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
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
            child: ListTile(
              title: const Text("My List"),
              titleTextStyle: TextStyle(color: whiteColor),
              tileColor: whiteColor.withOpacity(0.05),
              trailing:
                  Icon(Icons.arrow_forward_ios, size: 16, color: whiteColor),
              onTap: () async {
                final userId = FirebaseAuth.instance.currentUser?.uid;

                if (userId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please log in to view your watchlist.')),
                  );
                  return;
                }

                try {
                  final userDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .get();

                  final watchlist =
                      List<String>.from(userDoc.data()?['watchlist'] ?? []);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WatchLaterPage(watchlist),
                    ),
                  );
                } catch (e) {
                  debugPrint('❌ Error loading watchlist: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to load watchlist: $e')),
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
            child: ListTile(
              title: const Text("Subscriptions"),
              titleTextStyle: TextStyle(color: whiteColor),
              tileColor: whiteColor.withOpacity(0.05),
              trailing:
                  Icon(Icons.arrow_forward_ios, size: 16, color: whiteColor),
              onTap: () async {
                Get.to(() => SubscriptionsScreen());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
            child: ListTile(
              title: const Text("Support"),
              titleTextStyle: TextStyle(color: whiteColor),
              tileColor: whiteColor.withOpacity(0.05),
              trailing:
                  Icon(Icons.arrow_forward_ios, size: 16, color: whiteColor),
              onTap: () async {
                Get.to(() => SupportPage());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
            child: ListTile(
              title: Text('Logout'),
              titleTextStyle: TextStyle(color: whiteColor),
              tileColor: whiteColor.withOpacity(0.05),
              trailing:
                  Icon(Icons.arrow_forward_ios, size: 16, color: whiteColor),
              onTap: () {
                showCupertinoDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return CupertinoAlertDialog(
                      title: Text('Logout'),
                      content: Text('Are you sure you want to logout?'),
                      actions: [
                        CupertinoDialogAction(
                          child: Text('Cancel'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        CupertinoDialogAction(
                          isDestructiveAction: true,
                          child: Text('Logout'),
                          onPressed: () async {
                            Navigator.of(context).pop(); // Close dialog
                            final prefs = await SharedPreferences.getInstance();
                            bool cleared = await prefs.clear();
                            if (cleared) {
                              print('SharedPreferences cleared successfully');
                            } else {
                              print('Failed to clear SharedPreferences');
                            }
                            if (FirebaseAuth.instance.currentUser != null) {
                              await FirebaseAuth.instance.signOut();
                              setState(() {
                                Get.off(() => LogInScreen());
                              });
                            } else {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => LogInScreen()),
                              );
                            }
                          },
                        ),
                      ],
                    );
                  },
                );
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
    return showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text('Delete Account'),
          content: Column(
            children: [
              Text(
                'Are you sure you want to delete your account?',
                // style: TextStyle(color: blackColor),
              ),
              SizedBox(height: 6), // Spacing between texts
              Text(
                'This action cannot be undone.',
                // style: TextStyle(color: blackColor),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: Text(
                'Cancel',
                // style: TextStyle(color: blackColor),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: Text(
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
