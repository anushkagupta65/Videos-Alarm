// ignore_for_file: unused_local_variable

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videos_alarm_app/components/common_toast.dart';
import 'package:videos_alarm_app/device_guard.dart';
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
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          // If authentication state is loading
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black,
                    const Color.fromARGB(255, 37, 37, 37),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          // If no user is logged in
          if (!authSnapshot.hasData || authSnapshot.data == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black,
                        const Color.fromARGB(255, 37, 37, 37),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.blue.shade50,
                        child: const Icon(
                          Icons.person,
                          size: 52,
                          color: Colors.deepPurpleAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No user logged in',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Settings list remains the same
                Expanded(child: _buildSettingsList(context)),
              ],
            );
          }

          // User is logged in, fetch Firestore data
          final user = authSnapshot.data!;
          final userRef = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .withConverter(
                fromFirestore: (snapshot, _) => snapshot.data()!,
                toFirestore: (Map<String, dynamic> data, _) => data,
              );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: userRef.get(const GetOptions(source: Source.server)),
                builder: (context, snapshot) {
                  String displayName = 'User';
                  String phoneNumber = '';
                  Widget avatar = CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.blue.shade50,
                    child: const Icon(
                      Icons.person,
                      size: 52,
                      color: Colors.deepPurpleAccent,
                    ),
                  );

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black,
                            const Color.fromARGB(255, 37, 37, 37),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black,
                            const Color.fromARGB(255, 37, 37, 37),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          avatar,
                          const SizedBox(height: 8),
                          const Text(
                            'Error loading user',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data()!;
                    displayName = data['name'] ?? 'User';
                    phoneNumber = data['phone'] ?? '';
                    if (displayName.isNotEmpty) {
                      avatar = CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.blue.shade50,
                        child: Text(
                          displayName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.deepPurpleAccent,
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                  }

                  return Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black,
                          const Color.fromARGB(255, 37, 37, 37),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets.only(left: 8, right: 8, top: 30),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(width: 16),
                          avatar,
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  color: whiteColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                phoneNumber,
                                style: TextStyle(
                                  color: whiteColor,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Settings list
              Expanded(child: _buildSettingsList(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      itemCount: 9,
      itemBuilder: (context, index) {
        switch (index) {
          case 0:
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: const Text("About Us"),
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
            );
          case 1:
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
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
            );
          case 2:
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
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
            );
          case 3:
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: const Text("Cancellation & Refund Policy"),
                titleTextStyle: TextStyle(color: whiteColor),
                tileColor: whiteColor.withOpacity(0.05),
                trailing:
                    Icon(Icons.arrow_forward_ios, size: 16, color: whiteColor),
                onTap: () async {
                  final Uri url = Uri.parse(
                      'https://videosalarm.com/videoalarm/Cancellation.php');
                  if (!await launchUrl(url)) {
                    throw Exception('Could not launch $url');
                  }
                },
              ),
            );
          case 4:
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
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
                          content:
                              Text('Please log in to view your watchlist.')),
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
            );
          case 5:
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
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
            );
          case 6:
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: const Text("Support"),
                titleTextStyle: TextStyle(color: whiteColor),
                tileColor: whiteColor.withOpacity(0.05),
                trailing:
                    Icon(Icons.arrow_forward_ios, size: 16, color: whiteColor),
                onTap: () async {
                  Get.to(() => SupportPage(
                        calledFrom: "settings",
                      ));
                },
              ),
            );
          case 7:
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: const Text('Logout'),
                titleTextStyle: TextStyle(color: whiteColor),
                tileColor: whiteColor.withOpacity(0.05),
                trailing:
                    Icon(Icons.arrow_forward_ios, size: 16, color: whiteColor),
                onTap: () {
                  showCupertinoDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return CupertinoAlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('Cancel'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            child: const Text('Logout'),
                            onPressed: () async {
                              Navigator.of(context).pop();
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                final deviceId = await getDeviceId();
                                final deviceType = await getDeviceType();
                                final userRef = FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid);
                                await userRef.update({
                                  'devices.$deviceType': FieldValue.delete(),
                                });
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.clear();
                                await FirebaseAuth.instance.signOut();
                                Get.off(() => LogInScreen());
                              } else {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.clear();
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
            );
          case 8:
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: const Text("Delete Account"),
                titleTextStyle: const TextStyle(color: Colors.red),
                tileColor: whiteColor.withOpacity(0.05),
                trailing: const Icon(Icons.delete, size: 16, color: Colors.red),
                onTap: () async {
                  _showDeleteConfirmationDialog(context);
                },
              ),
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  Future<void> _showDeleteConfirmationDialog(BuildContext context) async {
    return showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Delete Account'),
          content: const Column(
            children: [
              Text('Are you sure you want to delete your account?'),
              SizedBox(height: 6), // Spacing between texts
              Text('This action cannot be undone.'),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
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
