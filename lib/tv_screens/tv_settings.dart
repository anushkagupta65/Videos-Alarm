import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';
import 'package:videos_alarm_app/device_guard.dart';
import 'package:videos_alarm_app/tv_screens/tv_login.dart';
import 'package:flutter/services.dart';

class TVSettingsScreen extends StatelessWidget {
  final bool isSettingsDrawerOpen;
  final List<FocusNode> settingsItemFocusNodes;
  final VoidCallback toggleSettingsDrawer;
  final Function(String) commToast;

  const TVSettingsScreen({
    super.key,
    required this.isSettingsDrawerOpen,
    required this.settingsItemFocusNodes,
    required this.toggleSettingsDrawer,
    required this.commToast,
  });

  @override
  Widget build(BuildContext context) {
    // Debug focus tree to inspect focus hierarchy (optional)
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   debugPrintFocusTree();
    // });

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isSettingsDrawerOpen ? 300 : 0,
      transform: Matrix4.translationValues(
          MediaQuery.of(context).size.width - (isSettingsDrawerOpen ? 300 : 0),
          0,
          0),
      color: Colors.black.withOpacity(isSettingsDrawerOpen ? 0.5 : 0),
      child: isSettingsDrawerOpen
          ? Container(
              width: 200,
              height: (MediaQuery.of(context).size.height) / 1.8,
              color: const Color(0xFF212121),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        "Settings",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Focus(
                      focusNode: settingsItemFocusNodes[0],
                      onFocusChange: (hasFocus) {
                        if (hasFocus) {
                          print('About Us ListTile focused');
                        }
                        (context as Element).markNeedsBuild();
                      },
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.select ||
                                event.logicalKey == LogicalKeyboardKey.enter ||
                                event.logicalKey ==
                                    LogicalKeyboardKey.gameButtonA)) {
                          print('About Us ListTile selected');
                          toggleSettingsDrawer();
                          final Uri url = Uri.parse(
                              'https://videosalarm.com/videoalarm/about-us.php');
                          launchUrl(url).then((success) {
                            if (!success) {
                              commToast('Could not launch About Us page');
                            }
                          });
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: ListTile(
                        leading: const Icon(Icons.info_outline,
                            color: Colors.white70),
                        title: Text(
                          "About Us",
                          style: TextStyle(
                            color: settingsItemFocusNodes[0].hasFocus
                                ? Colors.white
                                : Colors.white70,
                            fontWeight: settingsItemFocusNodes[0].hasFocus
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    Focus(
                      focusNode: settingsItemFocusNodes[1],
                      onFocusChange: (hasFocus) {
                        if (hasFocus) {
                          print('Terms & Conditions ListTile focused');
                        }
                        (context as Element).markNeedsBuild();
                      },
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.select ||
                                event.logicalKey == LogicalKeyboardKey.enter ||
                                event.logicalKey ==
                                    LogicalKeyboardKey.gameButtonA)) {
                          print('Terms & Conditions ListTile selected');
                          toggleSettingsDrawer();
                          final Uri url = Uri.parse(
                              'https://videosalarm.com/videoalarm/terms-and-condition.php');
                          launchUrl(url).then((success) {
                            if (!success) {
                              commToast(
                                  'Could not launch Terms & Conditions page');
                            }
                          });
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: ListTile(
                        leading: const Icon(Icons.power_settings_new,
                            color: Colors.white70),
                        title: Text(
                          "Terms & Conditions",
                          style: TextStyle(
                            color: settingsItemFocusNodes[1].hasFocus
                                ? Colors.white
                                : Colors.white70,
                            fontWeight: settingsItemFocusNodes[1].hasFocus
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    Focus(
                      focusNode: settingsItemFocusNodes[2],
                      onFocusChange: (hasFocus) {
                        if (hasFocus) {
                          print('Privacy Policy ListTile focused');
                        }
                        (context as Element).markNeedsBuild();
                      },
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.select ||
                                event.logicalKey == LogicalKeyboardKey.enter ||
                                event.logicalKey ==
                                    LogicalKeyboardKey.gameButtonA)) {
                          print('Privacy Policy ListTile selected');
                          toggleSettingsDrawer();
                          final Uri url = Uri.parse(
                              'https://videosalarm.com/privacy-policy.html');
                          launchUrl(url).then((success) {
                            if (!success) {
                              commToast('Could not launch Privacy Policy page');
                            }
                          });
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: ListTile(
                        leading: const Icon(Icons.access_time,
                            color: Colors.white70),
                        title: Text(
                          "Privacy Policy",
                          style: TextStyle(
                            color: settingsItemFocusNodes[2].hasFocus
                                ? Colors.white
                                : Colors.white70,
                            fontWeight: settingsItemFocusNodes[2].hasFocus
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    Focus(
                      focusNode: settingsItemFocusNodes[3],
                      onFocusChange: (hasFocus) {
                        if (hasFocus) {
                          print('Logout ListTile focused');
                        }
                        (context as Element).markNeedsBuild();
                      },
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.select ||
                                event.logicalKey == LogicalKeyboardKey.enter ||
                                event.logicalKey ==
                                    LogicalKeyboardKey.gameButtonA)) {
                          print('Logout ListTile selected');
                          toggleSettingsDrawer();
                          // Create focus nodes for dialog buttons
                          final FocusNode cancelFocusNode = FocusNode();
                          final FocusNode logoutFocusNode = FocusNode();

                          // Request focus on the Cancel button when dialog opens
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            cancelFocusNode.requestFocus();
                            print('Requested focus on Cancel button');
                          });

                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return FocusScope(
                                child: AlertDialog(
                                  backgroundColor: Colors.grey[900],
                                  title: const Text(
                                    'Logout',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: const Text(
                                    'Are you sure you want to logout?',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  actions: [
                                    Focus(
                                      focusNode: cancelFocusNode,
                                      onFocusChange: (hasFocus) {
                                        (context as Element).markNeedsBuild();
                                      },
                                      onKeyEvent:
                                          (FocusNode node, KeyEvent event) {
                                        if (event is KeyDownEvent &&
                                            (event.logicalKey ==
                                                    LogicalKeyboardKey.select ||
                                                event.logicalKey ==
                                                    LogicalKeyboardKey.enter ||
                                                event.logicalKey ==
                                                    LogicalKeyboardKey
                                                        .gameButtonA)) {
                                          Navigator.of(context).pop();
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.ignored;
                                      },
                                      child: Builder(
                                        builder: (context) => TextButton(
                                          style: TextButton.styleFrom(
                                            backgroundColor: cancelFocusNode
                                                    .hasFocus
                                                ? Colors.blue.withOpacity(0.3)
                                                : null,
                                            foregroundColor:
                                                cancelFocusNode.hasFocus
                                                    ? Colors.blue
                                                    : Colors.grey,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                          ),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: Text(
                                            'Cancel',
                                            style: TextStyle(
                                              color: cancelFocusNode.hasFocus
                                                  ? Colors.blue
                                                  : Colors.grey,
                                              fontWeight:
                                                  cancelFocusNode.hasFocus
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Focus(
                                      focusNode: logoutFocusNode,
                                      onFocusChange: (hasFocus) {
                                        (context as Element).markNeedsBuild();
                                      },
                                      onKeyEvent:
                                          (FocusNode node, KeyEvent event) {
                                        if (event is KeyDownEvent &&
                                            (event.logicalKey ==
                                                    LogicalKeyboardKey.select ||
                                                event.logicalKey ==
                                                    LogicalKeyboardKey.enter ||
                                                event.logicalKey ==
                                                    LogicalKeyboardKey
                                                        .gameButtonA)) {
                                          Navigator.of(context).pop();
                                          SharedPreferences.getInstance()
                                              .then((prefs) async {
                                            try {
                                              final user = FirebaseAuth
                                                  .instance.currentUser;
                                              if (user != null) {
                                                // ignore: unused_local_variable
                                                final deviceId =
                                                    await getDeviceId();
                                                final deviceType =
                                                    await getDeviceType();
                                                final userRef =
                                                    FirebaseFirestore.instance
                                                        .collection('users')
                                                        .doc(user.uid);
                                                await userRef.update({
                                                  'devices.$deviceType':
                                                      FieldValue.delete(),
                                                });
                                                bool cleared =
                                                    await prefs.clear();
                                                if (cleared) {
                                                  commToast(
                                                      'Logged out successfully');
                                                } else {
                                                  commToast(
                                                      'Failed to clear preferences');
                                                }
                                                await FirebaseAuth.instance
                                                    .signOut();
                                                Get.off(() => TVLogInScreen());
                                              } else {
                                                bool cleared =
                                                    await prefs.clear();
                                                if (cleared) {
                                                  commToast(
                                                      'Logged out successfully');
                                                } else {
                                                  commToast(
                                                      'Failed to clear preferences');
                                                }
                                                Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          TVLogInScreen()),
                                                );
                                              }
                                            } catch (e) {
                                              commToast('Error during logout');
                                            }
                                          });
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.ignored;
                                      },
                                      child: Builder(
                                        builder: (context) => TextButton(
                                          style: TextButton.styleFrom(
                                            backgroundColor: logoutFocusNode
                                                    .hasFocus
                                                ? Colors.red.withOpacity(0.3)
                                                : null,
                                            foregroundColor:
                                                logoutFocusNode.hasFocus
                                                    ? Colors.redAccent[700]
                                                    : Colors.redAccent[700],
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                          ),
                                          onPressed: () async {
                                            Navigator.of(context).pop();
                                            try {
                                              final user = FirebaseAuth
                                                  .instance.currentUser;
                                              if (user != null) {
                                                // ignore: unused_local_variable
                                                final deviceId =
                                                    await getDeviceId();
                                                final deviceType =
                                                    await getDeviceType();
                                                final userRef =
                                                    FirebaseFirestore.instance
                                                        .collection('users')
                                                        .doc(user.uid);
                                                await userRef.update({
                                                  'devices.$deviceType':
                                                      FieldValue.delete(),
                                                });
                                                final prefs =
                                                    await SharedPreferences
                                                        .getInstance();
                                                bool cleared =
                                                    await prefs.clear();
                                                if (cleared) {
                                                  commToast(
                                                      'Logged out successfully');
                                                } else {
                                                  commToast(
                                                      'Failed to clear preferences');
                                                }
                                                await FirebaseAuth.instance
                                                    .signOut();
                                                Get.off(() => TVLogInScreen());
                                              } else {
                                                final prefs =
                                                    await SharedPreferences
                                                        .getInstance();
                                                bool cleared =
                                                    await prefs.clear();
                                                if (cleared) {
                                                  commToast(
                                                      'Logged out successfully');
                                                } else {
                                                  commToast(
                                                      'Failed to clear preferences');
                                                }
                                                Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          TVLogInScreen()),
                                                );
                                              }
                                            } catch (e) {
                                              commToast('Error during logout');
                                            }
                                          },
                                          child: Text(
                                            'Logout',
                                            style: TextStyle(
                                              color: logoutFocusNode.hasFocus
                                                  ? Colors.red
                                                  : Colors.redAccent,
                                              fontWeight:
                                                  logoutFocusNode.hasFocus
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ).then((_) {
                            print('Dialog closed, disposing focus nodes');
                            cancelFocusNode.dispose();
                            logoutFocusNode.dispose();
                          });
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: ListTile(
                        leading:
                            const Icon(Icons.logout, color: Colors.white70),
                        title: Text(
                          "Logout",
                          style: TextStyle(
                            color: settingsItemFocusNodes[3].hasFocus
                                ? Colors.white
                                : Colors.white70,
                            fontWeight: settingsItemFocusNodes[3].hasFocus
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
