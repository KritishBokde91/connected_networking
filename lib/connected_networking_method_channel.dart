import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'connected_networking_platform_interface.dart';

/// An implementation of [ConnectedNetworkingPlatform] that uses method channels.
class MethodChannelConnectedNetworking extends ConnectedNetworkingPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('connected_networking');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
