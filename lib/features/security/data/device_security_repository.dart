import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../core/api/mobile_api_client.dart';

class DeviceSecurityRepository {
  final MobileApiClient _apiClient;
  final FlutterSecureStorage _storage;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  DeviceSecurityRepository({
    MobileApiClient? apiClient,
    FlutterSecureStorage? storage,
  })  : _apiClient = apiClient ?? MobileApiClient(),
        _storage = storage ?? const FlutterSecureStorage();

  static const String _deviceIdKey = 'edut_device_id';

  Future<String> getOrCreateDeviceId() async {
    String? deviceId = await _storage.read(key: _deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }
    return deviceId;
  }

  Future<Map<String, String>> getCurrentDeviceDetails() async {
    final deviceId = await getOrCreateDeviceId();
    String brand = 'SAMSUNG';
    String model = 'SM-A525F';
    String os = 'Android';
    String osVersion = '14';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        final mfg = androidInfo.manufacturer.trim().toUpperCase();
        if (mfg.isNotEmpty && mfg != 'UNKNOWN') {
          brand = mfg;
        } else {
          brand = 'SAMSUNG';
        }
        final mdl = androidInfo.model.trim();
        if (mdl.isNotEmpty && mdl != 'UNKNOWN') {
          model = mdl;
        } else {
          model = 'SM-A525F';
        }
        os = 'Android';
        final rel = androidInfo.version.release.trim();
        if (rel.isNotEmpty) {
          osVersion = rel;
        } else {
          osVersion = '14';
        }
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        brand = 'APPLE';
        model = iosInfo.utsname.machine;
        if (model.isEmpty) model = 'iPhone';
        os = 'iOS';
        osVersion = iosInfo.systemVersion;
      }
    } catch (e) {
      debugPrint('Device info fallback: $e');
      if (Platform.isAndroid) {
        brand = 'SAMSUNG';
        model = 'SM-A525F';
        os = 'Android';
        osVersion = '14';
      } else if (Platform.isIOS) {
        brand = 'APPLE';
        model = 'iPhone';
        os = 'iOS';
        osVersion = '17.4';
      }
    }

    return {
      'deviceId': deviceId,
      'brand': brand,
      'model': model,
      'os': os,
      'osVersion': osVersion,
    };
  }

  Future<Map<String, dynamic>> fetchDevices() async {
    final details = await getCurrentDeviceDetails();
    final deviceId = details['deviceId']!;

    // Auto-register current device on fetch
    try {
      await _apiClient.postJson('/api/mobile/security/devices', {
        'action': 'register',
        'deviceId': deviceId,
        'brand': details['brand'],
        'model': details['model'],
        'os': details['os'],
        'osVersion': details['osVersion'],
      });
    } catch (e) {
      debugPrint('Device registration error: $e');
    }

    try {
      final response = await _apiClient.getJson('/api/mobile/security/devices?deviceId=$deviceId');
      if (response['data'] != null) {
        final data = Map<String, dynamic>.from(response['data']);
        if (data['currentDevice'] == null) {
          data['currentDevice'] = {
            'brand': details['brand'],
            'model': details['model'],
            'os': details['os'],
            'osVersion': details['osVersion'],
            'deviceId': deviceId,
            'isCurrent': true,
          };
        }
        return data;
      }
    } catch (e) {
      debugPrint('Fetch devices error: $e');
    }

    // Default fallback view
    return {
      'singleDeviceLock': false,
      'currentDevice': {
        'brand': details['brand'],
        'model': details['model'],
        'os': details['os'],
        'osVersion': details['osVersion'],
        'deviceId': deviceId,
        'isCurrent': true,
      },
      'devices': <Map<String, dynamic>>[],
      'totalConnected': 1,
    };
  }

  Future<bool> toggleSingleDeviceLock(bool enable) async {
    final details = await getCurrentDeviceDetails();
    try {
      final response = await _apiClient.postJson('/api/mobile/security/devices', {
        'action': 'toggle_lock',
        'enabled': enable,
        'deviceId': details['deviceId'],
      });
      return response['singleDeviceLock'] == true;
    } catch (e) {
      debugPrint('Toggle single device lock error: $e');
      return enable;
    }
  }

  Future<bool> revokeDevice(String targetDeviceId) async {
    try {
      final response = await _apiClient.postJson('/api/mobile/security/devices', {
        'action': 'revoke',
        'targetDeviceId': targetDeviceId,
      });
      return response['success'] == true;
    } catch (e) {
      debugPrint('Revoke device error: $e');
      return false;
    }
  }

  Future<bool> revokeAllOtherDevices() async {
    final details = await getCurrentDeviceDetails();
    try {
      final response = await _apiClient.postJson('/api/mobile/security/devices', {
        'action': 'revoke_all_others',
        'deviceId': details['deviceId'],
      });
      return response['success'] == true;
    } catch (e) {
      debugPrint('Revoke all other devices error: $e');
      return false;
    }
  }
}
