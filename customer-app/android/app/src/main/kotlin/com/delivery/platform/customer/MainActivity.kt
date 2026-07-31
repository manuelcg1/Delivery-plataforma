package com.delivery.platform.customer

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import com.baseflow.geolocator.GeolocatorLocationService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val trackingChannel = "com.delivery.platform.customer/tracking"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            trackingChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "stopLocationForeground" -> stopLocationForeground(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun stopLocationForeground(result: MethodChannel.Result) {
        val intent = Intent(this, GeolocatorLocationService::class.java)
        lateinit var connection: ServiceConnection
        connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                try {
                    val getter = binder?.javaClass?.getDeclaredMethod("getLocationService")
                    getter?.isAccessible = true
                    val service = getter?.invoke(binder) as? GeolocatorLocationService
                    service?.disableBackgroundMode()
                    result.success(null)
                } catch (error: Exception) {
                    result.error("TRACKING_STOP_FAILED", error.message, null)
                } finally {
                    unbindService(connection)
                }
            }

            override fun onServiceDisconnected(name: ComponentName?) = Unit
        }
        if (!bindService(intent, connection, Context.BIND_AUTO_CREATE)) {
            result.success(null)
        }
    }
}
