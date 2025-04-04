package com.example.beacon_sos_test

import android.app.*
import android.bluetooth.BluetoothManager
import android.bluetooth.le.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.Manifest
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import org.eclipse.paho.client.mqttv3.*
import org.eclipse.paho.android.service.MqttAndroidClient
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class BleScanService : Service() {

    private val channelId = "BLEScannerChannel"
    private val phoneNumber = "tel:01025195254"
    private val targetName = "Holy-IOT"

    private val CHANNEL = "com.example.beacon_sos_test"
    private var flutterEngine: FlutterEngine? = null

    private lateinit var scanner: BluetoothLeScanner
    private lateinit var scanCallback: ScanCallback

    override fun onCreate() {
        super.onCreate()

        // FlutterEngine 준비
        flutterEngine = FlutterEngine(this)
        flutterEngine?.dartExecutor?.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        createNotificationChannel()
        startForeground(1, buildNotification())

        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        scanner = bluetoothManager.adapter.bluetoothLeScanner

        scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {

                val name = result.scanRecord?.deviceName ?: result.device.name ?: return

                // val mac = result.device.address
                // val rssi = result.rssi
                // val data = result.scanRecord?.serviceData?.values?.firstOrNull()
                // val hex = data?.joinToString(" ") { String.format("%02X", it) }

                // Log.d("BLE", "name=$name, mac=$mac, rssi=$rssi, data=$hex")

                

                // if (name == targetName) 
                if (name.contains(targetName)) 
                {

                    val data = result.scanRecord?.serviceData?.values?.firstOrNull()
                    Log.d("BLE", "광고 데이터 = ${data?.joinToString(" ") { String.format("%02X", it) }}")

                    if (data != null && data.size > 10) {
                        val conditionMet = data[10].toInt() == 0x06 && data[11].toInt() == 0x01
                        if (conditionMet) {
                            Log.d("BLE", "🚨 Holy-IOT SOS 비상알림! 자동 전화 걸기")
                            // makePhoneCall()
                            // stopSelf()
                            // sendMqttAlert()
                            // publishMqttMessage(applicationContext)

                            notifyFlutter()

                        }
                    }
                }
            }
        }

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        // scanner.startScan(scanCallback)
        scanner.startScan(null, settings, scanCallback)

    }

    private fun notifyFlutter() {
        MethodChannel(
            flutterEngine!!.dartExecutor.binaryMessenger,
            CHANNEL
        ).invokeMethod("receive_sos_alarm", "SOS 감지됨!")
    }

    override fun onDestroy() {
        super.onDestroy()

        flutterEngine?.destroy()
        scanner.stopScan(scanCallback)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun makePhoneCall() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED) {
            Log.e("BLE", "CALL_PHONE 권한이 없음")
            return
        }

        // val intent = Intent(Intent.ACTION_CALL).apply {
        //     data = Uri.parse(phoneNumber)
        //     addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        // }

        val intent = Intent(Intent.ACTION_DIAL).apply {
            data = Uri.parse(phoneNumber)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("BLE SOS 감시 중")
            .setContentText("비콘을 감지하고 있습니다...")
            .setSmallIcon(android.R.drawable.ic_dialog_info) // 아이콘 교체 가능
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "BLE Scanner",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
