package com.upasthiti.connected_networking

import android.annotation.SuppressLint
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.*
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.net.InetAddress
import java.net.NetworkInterface
import java.util.*
import kotlin.collections.HashMap

class ConnectedNetworkingPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var wifiManager: WifiManager
    private lateinit var nsdManager: NsdManager
    private var registrationListener: NsdManager.RegistrationListener? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private var discoveredServices = mutableListOf<NsdServiceInfo>()

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "connected_networking")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        nsdManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    }

    @SuppressLint("MissingPermission")
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "startHotspot" -> {
                val ssid = call.argument<String>("ssid") ?: ""
                val password = call.argument<String>("password") ?: ""
                startHotspot(ssid, password, result)
            }
            "stopHotspot" -> {
                stopHotspot(result)
            }
            "isHotspotEnabled" -> {
                result.success(isHotspotEnabled())
            }
            "connectToWifi" -> {
                val ssid = call.argument<String>("ssid") ?: ""
                val password = call.argument<String>("password") ?: ""
                connectToWifi(ssid, password, result)
            }
            "getCurrentWifiSSID" -> {
                result.success(getCurrentWifiSSID())
            }
            "startServiceAdvertising" -> {
                val serviceName = call.argument<String>("serviceName") ?: ""
                val serviceType = call.argument<String>("serviceType") ?: ""
                val port = call.argument<Int>("port") ?: 0
                val txtRecords = call.argument<Map<String, String>>("txtRecords") ?: emptyMap()
                startServiceAdvertising(serviceName, serviceType, port, txtRecords, result)
            }
            "stopServiceAdvertising" -> {
                stopServiceAdvertising(result)
            }
            "discoverServices" -> {
                val serviceType = call.argument<String>("serviceType") ?: ""
                val timeoutSeconds = call.argument<Int>("timeoutSeconds") ?: 10
                discoverServices(serviceType, timeoutSeconds, result)
            }
            "getLocalIPAddress" -> {
                result.success(getLocalIPAddress())
            }
            "getConnectedDevices" -> {
                result.success(getConnectedDevices())
            }
            "requestNetworkPermissions" -> {
                result.success(true) // Permissions should be handled in manifest
            }
            "hasNetworkPermissions" -> {
                result.success(true)
            }
            "openWifiSettings" -> {
                openWifiSettings(result)
            }
            "copyToClipboard" -> {
                val text = call.argument<String>("text") ?: ""
                copyToClipboard(text, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun startHotspot(ssid: String, password: String, result: Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Android 8.0+ hotspot management
                val wifiConfiguration = WifiConfiguration().apply {
                    SSID = ssid
                    preSharedKey = password
                    allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)
                    allowedAuthAlgorithms.set(WifiConfiguration.AuthAlgorithm.OPEN)
                }

                // Use reflection for hotspot management (requires system app or root)
                val method = wifiManager.javaClass.getMethod("setWifiApEnabled", WifiConfiguration::class.java, Boolean::class.java)
                val success = method.invoke(wifiManager, wifiConfiguration, true) as Boolean
                result.success(success)
            } else {
                // Fallback for older versions
                result.success(false)
            }
        } catch (e: Exception) {
            result.success(false)
        }
    }

    @SuppressLint("MissingPermission")
    private fun stopHotspot(result: Result) {
        try {
            val method = wifiManager.javaClass.getMethod("setWifiApEnabled", WifiConfiguration::class.java, Boolean::class.java)
            val success = method.invoke(wifiManager, null, false) as Boolean
            result.success(success)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    @SuppressLint("MissingPermission")
    private fun isHotspotEnabled(): Boolean {
        return try {
            val method = wifiManager.javaClass.getMethod("isWifiApEnabled")
            method.invoke(wifiManager) as Boolean
        } catch (e: Exception) {
            false
        }
    }

    @SuppressLint("MissingPermission")
    private fun connectToWifi(ssid: String, password: String, result: Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ - Use WifiNetworkSuggestion
            val suggestion = WifiNetworkSuggestion.Builder()
                .setSsid(ssid)
                .setWpa2Passphrase(password)
                .build()

            val suggestionsList = listOf(suggestion)
            val status = wifiManager.addNetworkSuggestions(suggestionsList)
            result.success(status == WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS)
        } else {
            // Legacy method for Android 9 and below
            val wifiConfig = WifiConfiguration().apply {
                SSID = "\"$ssid\""
                preSharedKey = "\"$password\""
                allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)
            }

            val networkId = wifiManager.addNetwork(wifiConfig)
            if (networkId != -1) {
                wifiManager.disconnect()
                wifiManager.enableNetwork(networkId, true)
                wifiManager.reconnect()
                result.success(true)
            } else {
                result.success(false)
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun getCurrentWifiSSID(): String? {
        val wifiInfo = wifiManager.connectionInfo
        return wifiInfo?.ssid?.replace("\"", "")
    }

    private fun startServiceAdvertising(serviceName: String, serviceType: String, port: Int, txtRecords: Map<String, String>, result: Result) {
        val serviceInfo = NsdServiceInfo().apply {
            this.serviceName = serviceName
            this.serviceType = serviceType
            this.port = port

            // Add TXT records
            txtRecords.forEach { (key, value) ->
                setAttribute(key, value)
            }
        }

        registrationListener = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(nsdServiceInfo: NsdServiceInfo) {
                result.success(true)
            }

            override fun onRegistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                result.success(false)
            }

            override fun onServiceUnregistered(arg0: NsdServiceInfo) {}
            override fun onUnregistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {}
        }

        nsdManager.registerService(serviceInfo, NsdManager.PROTOCOL_DNS_SD, registrationListener)
    }

    private fun stopServiceAdvertising(result: Result) {
        registrationListener?.let {
            nsdManager.unregisterService(it)
            result.success(true)
        } ?: result.success(false)
    }

    private fun discoverServices(serviceType: String, timeoutSeconds: Int, result: Result) {
        discoveredServices.clear()

        discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(regType: String) {}

            override fun onServiceFound(service: NsdServiceInfo) {
                if (service.serviceType == serviceType) {
                    nsdManager.resolveService(service, object : NsdManager.ResolveListener {
                        override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {}

                        override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                            discoveredServices.add(serviceInfo)
                        }
                    })
                }
            }

            override fun onServiceLost(service: NsdServiceInfo) {
                discoveredServices.removeAll { it.serviceName == service.serviceName }
            }

            override fun onDiscoveryStopped(serviceType: String) {}
            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                result.success(emptyList<Map<String, Any>>())
            }
            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {}
        }

        nsdManager.discoverServices(serviceType, NsdManager.PROTOCOL_DNS_SD, discoveryListener)

        // Stop discovery after timeout and return results
        Timer().schedule(object : TimerTask() {
            override fun run() {
                discoveryListener?.let { nsdManager.stopServiceDiscovery(it) }

                val services = discoveredServices.map { service ->
                    mapOf(
                        "name" to service.serviceName,
                        "host" to (service.host?.hostAddress ?: ""),
                        "port" to service.port,
                        "txtRecords" to (service.attributes?.mapValues { String(it.value) } ?: emptyMap<String, String>())
                    )
                }
                result.success(services)
            }
        }, (timeoutSeconds * 1000).toLong())
    }

    private fun getLocalIPAddress(): String? {
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                val addresses = networkInterface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val address = addresses.nextElement()
                    if (!address.isLoopbackAddress && address is java.net.Inet4Address) {
                        return address.hostAddress
                    }
                }
            }
        } catch (e: Exception) {
            return null
        }
        return null
    }

    private fun getConnectedDevices(): List<String> {
        // This would require root access or system privileges
        // Return empty list for now, can be enhanced with ARP table parsing
        return emptyList()
    }

    private fun openWifiSettings(result: Result) {
        try {
            val intent = Intent(Settings.ACTION_WIFI_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun copyToClipboard(text: String, result: Result) {
        try {
            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = ClipData.newPlainText("ConnectED", text)
            clipboard.setPrimaryClip(clip)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}