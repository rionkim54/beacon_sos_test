package com.example.beacon_sos_test

// import io.flutter.embedding.android.FlutterActivity

// class MainActivity : FlutterActivity()

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.beacon_sos_test"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "startBleService" -> {
                    val intent = Intent(this, BleScanService::class.java)
                    startForegroundService(intent)
                    result.success("Service started")
                }
                "stopBleService" -> {
                    val intent = Intent(this, BleScanService::class.java)
                    stopService(intent)
                    result.success("Service stopped")
                }
                else -> result.notImplemented()
            }
        }
    }
}