import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:videos_alarm_app/device_limit_screen.dart';

Future<String> getDeviceId() async {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      final deviceId = androidInfo.id;
      return deviceId;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      final deviceId = iosInfo.identifierForVendor ?? 'unknown_ios_device';
      return deviceId;
    }
  } catch (e) {}
  return 'unknown_device';
}

Future<String> getDeviceType() async {
  try {
    if (Platform.isAndroid) {
      final isTV = await isDeviceAndroidTV();
      final deviceType = isTV ? 'AndroidTV' : 'Phone';
      return deviceType;
    } else if (Platform.isIOS) {
      return 'Phone';
    }
  } catch (e) {}
  return 'unknown';
}

Future<bool> isDeviceAndroidTV() async {
  if (Platform.isAndroid) {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      final isTV =
          androidInfo.systemFeatures.contains('android.software.leanback');
      return isTV;
    } catch (e) {}
  }
  return false;
}

Future<bool> isDeviceAndroidPhone() async {
  if (Platform.isAndroid) {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      final isPhone =
          !androidInfo.systemFeatures.contains('android.software.leanback');
      return isPhone;
    } catch (e) {}
  }
  return false;
}

Future<Map<String, dynamic>> getDeviceDetails() async {
  final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
  Map<String, dynamic> deviceDetails = {};
  String platformType = 'unknown';

  try {
    if (Platform.isAndroid) {
      platformType = 'Android';
      final androidInfo = await deviceInfoPlugin.androidInfo;
      deviceDetails = {
        'board': androidInfo.board,
        'brand': androidInfo.brand,
        'device': androidInfo.device,
        'display': androidInfo.display,
        'fingerprint': androidInfo.fingerprint,
        'hardware': androidInfo.hardware,
        'isLowRamDevice': androidInfo.isLowRamDevice,
        'isPhysicalDevice': androidInfo.isPhysicalDevice,
        'manufacturer': androidInfo.manufacturer,
        'model': androidInfo.model,
        'product': androidInfo.product,
        'tags': androidInfo.tags,
        'type': androidInfo.type,
        'version': {
          'baseOS': androidInfo.version.baseOS,
          'previewSdkInt': androidInfo.version.previewSdkInt,
          'release': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'securityPatch': androidInfo.version.securityPatch,
        },
      };
    } else if (Platform.isIOS) {
      platformType = 'iOS';
      final iosInfo = await deviceInfoPlugin.iosInfo;
      deviceDetails = {
        'os': 'iOS',
        'os_version': iosInfo.systemVersion,
        'name': iosInfo.name,
        'model': iosInfo.model,
        'localizedModelName': iosInfo.localizedModel,
        'systemName': iosInfo.systemName,
        'is_physical_device': iosInfo.isPhysicalDevice,
        'utsname': {
          'sysname': iosInfo.utsname.sysname,
          'nodename': iosInfo.utsname.nodename,
          'release': iosInfo.utsname.release,
          'version': iosInfo.utsname.version,
          'machine': iosInfo.utsname.machine,
        },
      };
    }
  } catch (e) {}

  return {'details': deviceDetails, 'platform': platformType};
}

Future<void> addDeviceInfo(String uid) async {
  try {
    final deviceId = await getDeviceId();
    final deviceType = await getDeviceType();
    final deviceInfo = await getDeviceDetails();
    final deviceDetails = deviceInfo['details'];
    final platformType = deviceInfo['platform'];
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    if (uid == '4woatkyIhYOeV5t3aNjlDmjq3mX2') {
      return;
    }

    final snapshot = await userRef.get();
    Map<String, dynamic>? devices = snapshot.data()?['devices'];

    if (devices != null) {
      if (devices.containsKey(deviceType)) {
        final storedDevice = devices[deviceType];
        if (storedDevice['deviceId'] == deviceId) {
          await userRef.set({
            'devices': {
              deviceType: {
                'deviceId': deviceId,
                'lastLogin': DateTime.now().toIso8601String(),
                'platform': platformType,
                'details': deviceDetails,
              },
            },
          }, SetOptions(merge: true));
          return;
        }
        if (Platform.isIOS && storedDevice['platform'] == 'iOS') {
          final storedDetails = storedDevice['details'];
          final currentDetails = deviceDetails;
          if (storedDetails['model'] == currentDetails['model'] &&
              storedDetails['name'] == currentDetails['name']) {
            await userRef.set({
              'devices': {
                deviceType: {
                  'deviceId': deviceId,
                  'lastLogin': DateTime.now().toIso8601String(),
                  'platform': platformType,
                  'details': deviceDetails,
                },
              },
            }, SetOptions(merge: true));
            return;
          }
        }

        if (devices.containsKey(deviceType) &&
            storedDevice['deviceId'] != deviceId) {
          throw Exception('Device limit reached for $deviceType');
        }
        if (deviceType == 'Phone' &&
            ((devices.containsKey('AndroidTV') &&
                    devices.containsKey('Phone')) ||
                (devices.containsKey('Phone') &&
                    storedDevice['deviceId'] != deviceId))) {
          throw Exception('Only one phone device (Android or iOS) is allowed');
        }
        if (deviceType == 'AndroidTV' &&
            devices.containsKey('AndroidTV') &&
            storedDevice['deviceId'] != deviceId) {
          throw Exception('Only one AndroidTV device is allowed');
        }
      }
    }
    await userRef.set({
      'devices': {
        deviceType: {
          'deviceId': deviceId,
          'lastLogin': DateTime.now().toIso8601String(),
          'platform': platformType,
          'details': deviceDetails,
        },
      },
    }, SetOptions(merge: true));
  } catch (e) {
    throw e;
  }
}

Future<bool> checkDeviceLimit(String uid) async {
  try {
    if (uid == '4woatkyIhYOeV5t3aNjlDmjq3mX2') {
      return true;
    }

    final deviceId = await getDeviceId();
    final deviceType = await getDeviceType();
    final deviceInfo = await getDeviceDetails();
    final deviceDetails = deviceInfo['details'];
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    final snapshot = await userRef.get();
    if (!snapshot.exists) {
      return true;
    }

    Map<String, dynamic>? userData = snapshot.data();
    Map<String, dynamic>? devices = userData?['devices'];

    if (devices != null && devices.containsKey(deviceType)) {
      final storedDevice = devices[deviceType];
      if (storedDevice['deviceId'] == deviceId) {
        return true;
      }

      if (Platform.isIOS && storedDevice['platform'] == 'iOS') {
        final storedDetails = storedDevice['details'];
        final currentDetails = deviceDetails;
        if (storedDetails['model'] == currentDetails['model'] &&
            storedDetails['name'] == currentDetails['name']) {
          return true;
        }
      }
    }

    if (devices == null || devices.isEmpty) {
      return true;
    }
    if (deviceType == 'AndroidTV' && !devices.containsKey('AndroidTV')) {
      return true;
    }
    if (deviceType == 'Phone' && !devices.containsKey('Phone')) {
      return true;
    }
    return false;
  } catch (e) {
    return false;
  }
}

Future<bool> validateAndAddDevice(String uid, BuildContext context) async {
  try {
    final deviceId = await getDeviceId();
    final deviceType = await getDeviceType();
    final deviceInfo = await getDeviceDetails();
    final deviceDetails = deviceInfo['details'];
    final platformType = deviceInfo['platform'];
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    final snapshot = await userRef.get();
    Map<String, dynamic>? userData = snapshot.data();
    Map<String, dynamic>? devices = userData?['devices'];

    if (devices != null && devices.containsKey(deviceType)) {
      final storedDevice = devices[deviceType];
      if (storedDevice['deviceId'] == deviceId) {
        await userRef.set({
          'devices': {
            deviceType: {
              'deviceId': deviceId,
              'lastLogin': DateTime.now().toIso8601String(),
              'platform': platformType,
              'details': deviceDetails,
            },
          },
        }, SetOptions(merge: true));
        return true;
      }

      if (Platform.isIOS && storedDevice['platform'] == 'iOS') {
        final storedDetails = storedDevice['details'];
        final currentDetails = deviceDetails;
        if (storedDetails['model'] == currentDetails['model'] &&
            storedDetails['name'] == currentDetails['name']) {
          await userRef.set({
            'devices': {
              deviceType: {
                'deviceId': deviceId,
                'lastLogin': DateTime.now().toIso8601String(),
                'platform': platformType,
                'details': deviceDetails,
              },
            },
          }, SetOptions(merge: true));
          return true;
        }
      }
    }

    bool canAddDevice = await checkDeviceLimit(uid);
    if (!canAddDevice) {
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const DeviceLimitScreen(),
          ),
        );
      }
      return false;
    }

    await addDeviceInfo(uid);
    return true;
  } catch (e) {
    if (context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const DeviceLimitScreen(),
        ),
      );
    }
    return false;
  }
}
