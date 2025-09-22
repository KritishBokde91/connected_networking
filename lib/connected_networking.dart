import 'dart:async';
import 'package:flutter/services.dart';

class ConnectedNetworking {
  static const MethodChannel _channel = MethodChannel('connected_networking');

  // Hotspot Management
  static Future<bool> startHotspot({
    required String ssid,
    required String password,
  }) async {
    try {
      final bool result = await _channel.invokeMethod('startHotspot', {
        'ssid': ssid,
        'password': password,
      });
      return result;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> stopHotspot() async {
    try {
      final bool result = await _channel.invokeMethod('stopHotspot');
      return result;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> isHotspotEnabled() async {
    try {
      final bool result = await _channel.invokeMethod('isHotspotEnabled');
      return result;
    } on PlatformException {
      return false;
    }
  }

  // Wi-Fi Network Connection
  static Future<bool> connectToWifi({
    required String ssid,
    required String password,
  }) async {
    try {
      final bool result = await _channel.invokeMethod('connectToWifi', {
        'ssid': ssid,
        'password': password,
      });
      return result;
    } on PlatformException {
      return false;
    }
  }

  static Future<String?> getCurrentWifiSSID() async {
    try {
      final String? result = await _channel.invokeMethod('getCurrentWifiSSID');
      return result;
    } on PlatformException {
      return null;
    }
  }

  // DNS-SD Service Discovery
  static Future<bool> startServiceAdvertising({
    required String serviceName,
    required String serviceType,
    required int port,
    Map<String, String>? txtRecords,
  }) async {
    try {
      final bool result = await _channel.invokeMethod('startServiceAdvertising', {
        'serviceName': serviceName,
        'serviceType': serviceType,
        'port': port,
        'txtRecords': txtRecords ?? {},
      });
      return result;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> stopServiceAdvertising() async {
    try {
      final bool result = await _channel.invokeMethod('stopServiceAdvertising');
      return result;
    } on PlatformException {
      return false;
    }
  }

  static Future<List<NetworkService>> discoverServices({
    required String serviceType,
    int timeoutSeconds = 10,
  }) async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('discoverServices', {
        'serviceType': serviceType,
        'timeoutSeconds': timeoutSeconds,
      });
      return result.map((e) => NetworkService.fromMap(Map<String, dynamic>.from(e))).toList();
    } on PlatformException {
      return [];
    }
  }

  // Network Information
  static Future<String?> getLocalIPAddress() async {
    try {
      final String? result = await _channel.invokeMethod('getLocalIPAddress');
      return result;
    } on PlatformException {
      return null;
    }
  }

  static Future<List<String>> getConnectedDevices() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getConnectedDevices');
      return result.cast<String>();
    } on PlatformException {
      return [];
    }
  }

  // Permissions
  static Future<bool> requestNetworkPermissions() async {
    try {
      final bool result = await _channel.invokeMethod('requestNetworkPermissions');
      return result;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> hasNetworkPermissions() async {
    try {
      final bool result = await _channel.invokeMethod('hasNetworkPermissions');
      return result;
    } on PlatformException {
      return false;
    }
  }

  // iOS Specific - Open Wi-Fi Settings
  static Future<bool> openWifiSettings() async {
    try {
      final bool result = await _channel.invokeMethod('openWifiSettings');
      return result;
    } on PlatformException {
      return false;
    }
  }

  // Copy to Clipboard
  static Future<bool> copyToClipboard(String text) async {
    try {
      final bool result = await _channel.invokeMethod('copyToClipboard', {
        'text': text,
      });
      return result;
    } on PlatformException {
      return false;
    }
  }
}

class NetworkService {
  final String name;
  final String host;
  final int port;
  final Map<String, String> txtRecords;

  NetworkService({
    required this.name,
    required this.host,
    required this.port,
    required this.txtRecords,
  });

  factory NetworkService.fromMap(Map<String, dynamic> map) {
    return NetworkService(
      name: map['name'] ?? '',
      host: map['host'] ?? '',
      port: map['port'] ?? 0,
      txtRecords: Map<String, String>.from(map['txtRecords'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'host': host,
      'port': port,
      'txtRecords': txtRecords,
    };
  }
}