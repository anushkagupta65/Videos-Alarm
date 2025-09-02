import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:videos_alarm_app/device_guard.dart';
import 'package:videos_alarm_app/login_screen/login_screen.dart';
import 'package:videos_alarm_app/screens/banner_video_list.dart';
import 'package:videos_alarm_app/tv_screens/tv_login.dart';

class DeviceLimitScreen extends StatefulWidget {
  const DeviceLimitScreen({super.key});

  @override
  State<DeviceLimitScreen> createState() => _DeviceLimitScreenState();
}

class _DeviceLimitScreenState extends State<DeviceLimitScreen> {
  String _deviceName = 'Unknown Device';
  String? _deviceType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _fetchDeviceInfo();
      if (context.mounted) {
        await _showDeviceLimitAlert(context);
      }
    });
  }

  Future<void> _fetchDeviceInfo() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() {
          _deviceName = 'Unknown Device';
        });
        return;
      }

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final snapshot = await userRef.get();
      if (!snapshot.exists) {
        setState(() {
          _deviceName = 'Unknown Device';
        });
        return;
      }

      final userData = snapshot.data();
      final devices = userData?['devices'] as Map<String, dynamic>?;

      if (devices == null || devices.isEmpty) {
        setState(() {
          _deviceName = 'Unknown Device';
        });
        return;
      }

      if (devices.containsKey('Phone')) {
        setState(() {
          _deviceType = 'Phone';
          final details = devices['Phone']['details'] as Map<String, dynamic>?;
          if (details != null) {
            final brand = details['brand'] as String? ?? 'Unknown';
            _deviceName = '$brand';
          } else {
            _deviceName = 'Unknown Phone';
          }
        });
      } else if (devices.containsKey('AndroidTV')) {
        setState(() {
          _deviceType = 'AndroidTV';
          final details =
              devices['AndroidTV']['details'] as Map<String, dynamic>?;
          if (details != null) {
            final brand = details['brand'] as String? ?? 'Unknown';
            _deviceName = '$brand';
          } else {
            _deviceName = 'Unknown Android TV';
          }
        });
      } else {
        setState(() {
          _deviceName = 'Unknown Device';
        });
        return;
      }
    } catch (e) {
      setState(() {
        _deviceName = 'Unknown Device';
      });
    }
  }

  Future<void> _showConfirmationDialog() async {
    if (!context.mounted) return;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.0),
          ),
          titlePadding:
              const EdgeInsets.only(top: 30.0, left: 24.0, right: 24.0),
          contentPadding:
              const EdgeInsets.only(top: 20.0, left: 24.0, right: 24.0),
          actionsPadding: const EdgeInsets.only(
              top: 25.0, bottom: 30.0, left: 24.0, right: 24.0),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Confirm Device Removal',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22.0,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to remove the session from $_deviceName and continue on this device?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16.0,
              height: 1.6,
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.9),
                      side: BorderSide(
                          color: Colors.white.withOpacity(0.3), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFFE50914),
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      elevation: 5,
                      shadowColor: const Color(0xFFE50914).withOpacity(0.4),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (result == true && context.mounted) {
      await _removeDevice();
    }
  }

  Future<void> _removeDevice() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No user logged in')),
          );
        }
        return;
      }

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final snapshot = await userRef.get();
      final devices = snapshot.data()?['devices'] as Map<String, dynamic>?;

      if (devices != null &&
          _deviceType != null &&
          devices.containsKey(_deviceType)) {
        await userRef.update({
          'devices.$_deviceType': FieldValue.delete(),
        });

        final success = await validateAndAddDevice(uid, context);
        if (success && context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => BottomBarTabs(),
            ),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to register this device after removal')),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No device found to remove')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing device: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToLogin() async {
    try {
      final isAndroidTV = await isDeviceAndroidTV();
      if (context.mounted) {
        await FirebaseAuth.instance.signOut();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                isAndroidTV ? const TVLogInScreen() : const LogInScreen(),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error navigating to login: $e')),
        );
      }
    }
  }

  Future<void> _showDeviceLimitAlert(BuildContext context) async {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.0),
          ),
          titlePadding:
              const EdgeInsets.only(top: 30.0, left: 24.0, right: 24.0),
          contentPadding:
              const EdgeInsets.only(top: 20.0, left: 24.0, right: 24.0),
          actionsPadding: const EdgeInsets.only(
              top: 25.0, bottom: 30.0, left: 24.0, right: 24.0),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Device Limit Reached',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22.0,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'You\'re already logged in on another device. To continue, you\'ll need to manage your active devices.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16.0,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 25),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 15.0, vertical: 15.0),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.2), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tv, color: Colors.blue.shade300, size: 28),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        'Currently active on: $_deviceName',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                          fontSize: 16.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Please select an action below:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 15.0,
                ),
              ),
            ],
          ),
          actions: [
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFFE50914),
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      elevation: 5,
                      shadowColor: const Color(0xFFE50914).withOpacity(0.4),
                    ),
                    onPressed: _isLoading ? null : _showConfirmationDialog,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Continue on This Device',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16.0,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.9),
                      side: BorderSide(
                          color: Colors.white.withOpacity(0.3), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _navigateToLogin,
                    child: const Text(
                      'Log in with a Different Account',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.6),
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                    child: const Text(
                      'Exit App',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const SizedBox.shrink(),
      ),
    );
  }
}
