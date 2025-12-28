import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Service for generating and managing device fingerprints
class DeviceFingerprintService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Generate a unique device fingerprint
  static Future<String> getFingerprint() async {
    Map<String, dynamic> deviceData = {};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceData = {
          'platform': 'android',
          'id': androidInfo.id,
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'product': androidInfo.product,
          'device': androidInfo.device,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceData = {
          'platform': 'ios',
          'id': iosInfo.identifierForVendor ?? 'unknown',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'systemVersion': iosInfo.systemVersion,
        };
      }

      // Create a consistent JSON string
      final jsonStr = jsonEncode(deviceData);

      // Generate SHA-256 hash
      final bytes = utf8.encode(jsonStr);
      final digest = sha256.convert(bytes);

      return digest.toString();
    } catch (e) {
      // Fallback fingerprint
      return 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Get a human-readable device name
  static Future<String> getDeviceName() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.name;
      }
    } catch (e) {
      return 'Unknown Device';
    }
    return 'Unknown Device';
  }
}
