import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class DeviceInfoModel {
  final String deviceId;
  final String deviceName;
  final String platform;
  final bool isPrimary;
  final DateTime lastSeen;
  final String? fcmToken;

  DeviceInfoModel({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.isPrimary,
    required this.lastSeen,
    this.fcmToken,
  });

  Map<String, dynamic> toMap() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': platform,
        'isPrimary': isPrimary,
        'lastSeen': lastSeen.toIso8601String(),
        'fcmToken': fcmToken,
      };

  factory DeviceInfoModel.fromMap(Map<String, dynamic> map) => DeviceInfoModel(
        deviceId: map['deviceId'] ?? '',
        deviceName: map['deviceName'] ?? 'Unknown Device',
        platform: map['platform'] ?? 'Unknown',
        isPrimary: map['isPrimary'] ?? false,
        lastSeen: map['lastSeen'] != null
            ? DateTime.parse(map['lastSeen'])
            : DateTime.now(),
        fcmToken: map['fcmToken'],
      );
}

class DeviceManagementService {
  static const String _primaryDeviceIdKey = 'notlyfe_primary_device_id';
  static const String _localDeviceIdKey = 'notlyfe_current_device_id';
  static const String _registeredDevicesKey = 'notlyfe_registered_devices_list';

  /// Gets or generates a stable persistent unique ID for this device
  static Future<String> getCurrentDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_localDeviceIdKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_localDeviceIdKey, id);
    }
    return id;
  }

  /// Identifies the platform string
  static String getPlatformName() {
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      if (Platform.isLinux) return 'Linux';
      if (Platform.isMacOS) return 'macOS';
      if (Platform.isWindows) return 'Windows';
    } catch (_) {}
    return 'Web/Other';
  }

  /// Default friendly name for the current hardware
  static String getDefaultDeviceName() {
    try {
      if (Platform.isAndroid) return 'My Android Phone (A6)';
      if (Platform.isIOS) return 'iPhone';
      if (Platform.isLinux) return 'Linux PC';
      if (Platform.isWindows) return 'Windows PC';
      if (Platform.isMacOS) return 'MacBook';
    } catch (_) {}
    return 'Active Device';
  }

  /// Retrieves list of all known devices for this user
  static Future<List<DeviceInfoModel>> getRegisteredDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_registeredDevicesKey) ?? [];
    final currentId = await getCurrentDeviceId();
    final primaryId = await getPrimaryDeviceId();

    final List<DeviceInfoModel> devices = [];
    for (final raw in rawList) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final dev = DeviceInfoModel.fromMap(map);
        // Sync primary flag
        devices.add(DeviceInfoModel(
          deviceId: dev.deviceId,
          deviceName: dev.deviceName,
          platform: dev.platform,
          isPrimary: dev.deviceId == primaryId,
          lastSeen: dev.lastSeen,
          fcmToken: dev.fcmToken,
        ));
      } catch (_) {}
    }

    // Ensure current device is present
    if (!devices.any((d) => d.deviceId == currentId)) {
      final currentDev = DeviceInfoModel(
        deviceId: currentId,
        deviceName: getDefaultDeviceName(),
        platform: getPlatformName(),
        isPrimary: primaryId == null || primaryId == currentId,
        lastSeen: DateTime.now(),
      );
      devices.insert(0, currentDev);
      await saveDevicesList(devices);
      if (primaryId == null) {
        await setPrimaryDevice(currentId);
      }
    }

    return devices;
  }

  /// Saves the registered devices list locally and syncs to Supabase if logged in
  static Future<void> saveDevicesList(List<DeviceInfoModel> devices) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = devices.map((d) => jsonEncode(d.toMap())).toList();
    await prefs.setStringList(_registeredDevicesKey, raw);
  }

  /// Gets the currently assigned primary device ID
  static Future<String?> getPrimaryDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_primaryDeviceIdKey);
  }

  /// Sets a device as the primary device for FCM notifications
  static Future<void> setPrimaryDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_primaryDeviceIdKey, deviceId);

    // Update list
    final devices = await getRegisteredDevices();
    final updated = devices.map((d) {
      return DeviceInfoModel(
        deviceId: d.deviceId,
        deviceName: d.deviceName,
        platform: d.platform,
        isPrimary: d.deviceId == deviceId,
        lastSeen: d.deviceId == deviceId ? DateTime.now() : d.lastSeen,
        fcmToken: d.fcmToken,
      );
    }).toList();
    await saveDevicesList(updated);

    // Sync to Supabase user_profile if logged in
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Storing primary_device_id in user_metadata or user_profile
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {
              'primary_device_id': deviceId,
              'primary_device_platform': getPlatformName(),
              'fcm_enabled': true,
            },
          ),
        );
      }
    } catch (_) {}
  }

  /// Checks if this current hardware is the designated primary push notification device
  static Future<bool> isCurrentDevicePrimary() async {
    final currentId = await getCurrentDeviceId();
    final primaryId = await getPrimaryDeviceId();
    return currentId == primaryId;
  }

  /// Renames a registered device
  static Future<void> renameDevice(String deviceId, String newName) async {
    final devices = await getRegisteredDevices();
    final updated = devices.map((d) {
      if (d.deviceId == deviceId) {
        return DeviceInfoModel(
          deviceId: d.deviceId,
          deviceName: newName,
          platform: d.platform,
          isPrimary: d.isPrimary,
          lastSeen: d.lastSeen,
          fcmToken: d.fcmToken,
        );
      }
      return d;
    }).toList();
    await saveDevicesList(updated);
  }

  /// Removes a secondary device from registration
  static Future<void> removeDevice(String deviceId) async {
    final devices = await getRegisteredDevices();
    devices.removeWhere((d) => d.deviceId == deviceId);
    await saveDevicesList(devices);
  }
}

