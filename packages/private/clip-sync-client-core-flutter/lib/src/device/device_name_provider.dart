import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../models/sync_device.dart';

/// Reads the user-facing name reported by the current operating system.
class DeviceNameProvider {
  DeviceNameProvider({DeviceInfoPlugin? deviceInfo})
    : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfo;

  /// Returns a short name suitable for registration and display.
  Future<String> readName(String platform) async {
    String? name;
    try {
      name = switch (platform) {
        'android' => await _androidName(),
        'ios' => (await _deviceInfo.iosInfo).name,
        'macos' => (await _deviceInfo.macOsInfo).computerName,
        'windows' => (await _deviceInfo.windowsInfo).computerName,
        _ => null,
      };
    } catch (_) {
      // A hostname still gives the user a recognizable fallback if a native
      // device-information API is unavailable on a particular installation.
    }
    final candidate = name?.trim().isNotEmpty == true
        ? name!.trim()
        : Platform.localHostname.trim();
    final fallback = candidate.isEmpty
        ? SyncDevice.platformDisplayName(platform)
        : candidate;
    return fallback.length <= 100 ? fallback : fallback.substring(0, 100);
  }

  Future<String> _androidName() async {
    final info = await _deviceInfo.androidInfo;
    return info.name.trim().isNotEmpty ? info.name : info.model;
  }
}
