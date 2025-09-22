// plugins/connected_networking/ios/Classes/ConnectedNetworkingPlugin.swift
import Flutter
import UIKit
import NetworkExtension
import Network
import MultipeerConnectivity
import SystemConfiguration.CaptiveNetwork

public class ConnectedNetworkingPlugin: NSObject, FlutterPlugin {
    private var netServiceBrowser: NetServiceBrowser?
    private var netService: NetService?
    private var discoveredServices: [NetService] = []
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "connected_networking", binaryMessenger: registrar.messenger())
        let instance = ConnectedNetworkingPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startHotspot":
            // iOS doesn't support programmatic hotspot creation
            result(false)
            
        case "stopHotspot":
            // iOS doesn't support programmatic hotspot control
            result(false)
            
        case "isHotspotEnabled":
            // iOS doesn't provide hotspot status
            result(false)
            
        case "connectToWifi":
            let args = call.arguments as? [String: Any]
            let ssid = args?["ssid"] as? String ?? ""
            let password = args?["password"] as? String ?? ""
            connectToWifi(ssid: ssid, password: password, result: result)
            
        case "getCurrentWifiSSID":
            result(getCurrentWifiSSID())
            
        case "startServiceAdvertising":
            let args = call.arguments as? [String: Any]
            let serviceName = args?["serviceName"] as? String ?? ""
            let serviceType = args?["serviceType"] as? String ?? ""
            let port = args?["port"] as? Int ?? 0
            let txtRecords = args?["txtRecords"] as? [String: String] ?? [:]
            startServiceAdvertising(serviceName: serviceName, serviceType: serviceType, port: port, txtRecords: txtRecords, result: result)
            
        case "stopServiceAdvertising":
            stopServiceAdvertising(result: result)
            
        case "discoverServices":
            let args = call.arguments as? [String: Any]
            let serviceType = args?["serviceType"] as? String ?? ""
            let timeoutSeconds = args?["timeoutSeconds"] as? Int ?? 10
            discoverServices(serviceType: serviceType, timeoutSeconds: timeoutSeconds, result: result)
            
        case "getLocalIPAddress":
            result(getLocalIPAddress())
            
        case "getConnectedDevices":
            result([]) // Not available on iOS without private APIs
            
        case "requestNetworkPermissions":
            result(true) // Handled by Info.plist
            
        case "hasNetworkPermissions":
            result(true)
            
        case "openWifiSettings":
            openWifiSettings(result: result)
            
        case "copyToClipboard":
            let args = call.arguments as? [String: Any]
            let text = args?["text"] as? String ?? ""
            copyToClipboard(text: text, result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func connectToWifi(ssid: String, password: String, result: @escaping FlutterResult) {
        if #available(iOS 11.0, *) {
            let configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
            configuration.joinOnce = false
            
            NEHotspotConfigurationManager.shared.apply(configuration) { error in
                DispatchQueue.main.async {
                    result(error == nil)
                }
            }
        } else {
            result(false)
        }
    }
    
    private func getCurrentWifiSSID() -> String? {
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return nil }
        
        for interface in interfaces {
            guard let info = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any],
                  let ssid = info[kCNNetworkInfoKeySSID as String] as? String else { continue }
            return ssid
        }
        return nil
    }
    
    private func startServiceAdvertising(serviceName: String, serviceType: String, port: Int, txtRecords: [String: String], result: @escaping FlutterResult) {
        netService = NetService(domain: "local.", type: serviceType, name: serviceName, port: Int32(port))
        
        if !txtRecords.isEmpty {
            let txtData = NetService.data(fromTXTRecord: txtRecords.mapValues { $0.data(using: .utf8) ?? Data() })
            netService?.setTXTRecord(txtData)
        }
        
        netService?.delegate = self
        netService?.publish(options: .listenForConnections)
        
        // Give some time for service to start
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            result(true)
        }
    }
    
    private func stopServiceAdvertising(result: @escaping FlutterResult) {
        netService?.stop()
        netService = nil
        result(true)
    }
    
    private func discoverServices(serviceType: String, timeoutSeconds: Int, result: @escaping FlutterResult) {
        discoveredServices.removeAll()
        
        netServiceBrowser = NetServiceBrowser()
        netServiceBrowser?.delegate = self
        netServiceBrowser?.searchForServices(ofType: serviceType, inDomain: "local.")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(timeoutSeconds)) {
            self.netServiceBrowser?.stop()
            
            let services = self.discoveredServices.compactMap { service -> [String: Any]? in
                guard let addresses = service.addresses, !addresses.isEmpty else { return nil }
                
                let host = self.getIPAddress(from: addresses.first!)
                let txtRecords = self.getTXTRecords(from: service)
                
                return [
                    "name": service.name,
                    "host": host ?? "",
                    "port": service.port,
                    "txtRecords": txtRecords
                ]
            }
            
            result(services)
        }
    }
    
    private func getIPAddress(from data: Data) -> String? {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        
        return data.withUnsafeBytes { bytes in
            let sockaddr = bytes.bindMemory(to: sockaddr.self)
            guard getnameinfo(sockaddr.baseAddress, socklen_t(data.count),
                            &hostname, socklen_t(hostname.count),
                            nil, 0, NI_NUMERICHOST) == 0 else {
                return nil
            }
            return String(cString: hostname)
        }
    }
    
    private func getTXTRecords(from service: NetService) -> [String: String] {
        guard let txtData = service.txtRecordData() else { return [:] }
        let txtRecords = NetService.dictionary(fromTXTRecord: txtData)
        
        var result: [String: String] = [:]
        for (key, value) in txtRecords {
            if let stringValue = String(data: value, encoding: .utf8) {
                result[key] = stringValue
            }
        }
        return result
    }
    
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) {
                    if let name = String(cString: interface!.ifa_name, encoding: .utf8) {
                        if name == "en0" || name.hasPrefix("en") || name == "pdp_ip0" || name.hasPrefix("pdp_ip") {
                            var addr = interface?.ifa_addr.pointee
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            getnameinfo(&addr, socklen_t(interface!.ifa_addr.pointee.sa_len),
                                      &hostname, socklen_t(hostname.count),
                                      nil, socklen_t(0), NI_NUMERICHOST)
                            address = String(cString: hostname)
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
    
    private func openWifiSettings(result: @escaping FlutterResult) {
        if let url = URL(string: "App-Prefs:root=WIFI") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    result(success)
                }
                return
            }
        }
        
        // Fallback to general settings
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:]) { success in
                result(success)
            }
        } else {
            result(false)
        }
    }
    
    private func copyToClipboard(text: String, result: @escaping FlutterResult) {
        UIPasteboard.general.string = text
        result(true)
    }
}

// MARK: - NetServiceDelegate
extension ConnectedNetworkingPlugin: NetServiceDelegate {
    public func netServiceDidPublish(_ sender: NetService) {
        print("Service published: \(sender.name)")
    }
    
    public func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        print("Service failed to publish: \(errorDict)")
    }
}

// MARK: - NetServiceBrowserDelegate
extension ConnectedNetworkingPlugin: NetServiceBrowserDelegate {
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        service.resolve(withTimeout: 10.0)
        discoveredServices.append(service)
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        discoveredServices.removeAll { $0.name == service.name }
    }
    
    public func netServiceDidResolveAddress(_ sender: NetService) {
        print("Service resolved: \(sender.name) at \(sender.hostName ?? "unknown")")
    }
    
    public func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        print("Service failed to resolve: \(errorDict)")
    }
}