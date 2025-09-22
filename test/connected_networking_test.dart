import 'package:flutter_test/flutter_test.dart';
import 'package:connected_networking/connected_networking.dart';
import 'package:connected_networking/connected_networking_platform_interface.dart';
import 'package:connected_networking/connected_networking_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockConnectedNetworkingPlatform
    with MockPlatformInterfaceMixin
    implements ConnectedNetworkingPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final ConnectedNetworkingPlatform initialPlatform = ConnectedNetworkingPlatform.instance;

  test('$MethodChannelConnectedNetworking is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelConnectedNetworking>());
  });

  test('getPlatformVersion', () async {
    ConnectedNetworking connectedNetworkingPlugin = ConnectedNetworking();
    MockConnectedNetworkingPlatform fakePlatform = MockConnectedNetworkingPlatform();
    ConnectedNetworkingPlatform.instance = fakePlatform;

    expect(await connectedNetworkingPlugin.getPlatformVersion(), '42');
  });
}
