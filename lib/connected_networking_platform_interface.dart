import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'connected_networking_method_channel.dart';

abstract class ConnectedNetworkingPlatform extends PlatformInterface {
  /// Constructs a ConnectedNetworkingPlatform.
  ConnectedNetworkingPlatform() : super(token: _token);

  static final Object _token = Object();

  static ConnectedNetworkingPlatform _instance = MethodChannelConnectedNetworking();

  /// The default instance of [ConnectedNetworkingPlatform] to use.
  ///
  /// Defaults to [MethodChannelConnectedNetworking].
  static ConnectedNetworkingPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ConnectedNetworkingPlatform] when
  /// they register themselves.
  static set instance(ConnectedNetworkingPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
