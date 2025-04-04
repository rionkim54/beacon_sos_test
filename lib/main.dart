import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'dart:convert'; // JSON 포맷을 위해

import 'package:fluttertoast/fluttertoast.dart';

class AppBridge {
  static const platform = MethodChannel('com.example.beacon_sos_test');

  static void setupHandler(Function onSosReceived) {
    platform.setMethodCallHandler((call) async {
      if (call.method == "receive_sos_alarm") {
        String arg = call.arguments ?? '';
        print("📲 Android가 보낸 메시지: $arg");
        // await publishMqttMessage();
        await onSosReceived(); // 외부에서 처리
      }
    });
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // 중요!!
  AppBridge.setupHandler(() async {
    final controllerState = _BleServiceControllerState();
    await controllerState.publishMqttMessage(null);
  });
  runApp(const MaterialApp(home: BleServiceController()));
}

class BleServiceController extends StatefulWidget {
  const BleServiceController({super.key});

  @override
  State<BleServiceController> createState() => _BleServiceControllerState();
}

class _BleServiceControllerState extends State<BleServiceController> {
  static const platform = MethodChannel('com.example.beacon_sos_test');

  GoogleMapController? mapController;
  LatLng? currentPosition;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _determinePosition();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.phone,
    ].request();
  }

  Future<void> _determinePosition() async {
    await Permission.location.request();

    if (await Permission.location.isGranted) {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 👇 로그 출력
      print('📍 현재 위치: ${position.latitude}, ${position.longitude}');

      setState(() {
        currentPosition = LatLng(position.latitude, position.longitude);
      });
    } else {
      // 권한 거부됨
      openAppSettings();
    }
  }

  Future<void> _startService() async {
    try {
      await platform.invokeMethod('startBleService');
    } catch (e) {
      print("서비스 시작 실패: $e");
    }
  }

  Future<void> _stopService() async {
    try {
      await platform.invokeMethod('stopBleService');
    } catch (e) {
      print("서비스 종료 실패: $e");
    }
  }

  Future<void> publishMqttMessage(BuildContext? context) async {
    print("publishMqttMessage - sos alarm");

    // 위치 값이 없을 경우 먼저 얻기
    if (currentPosition == null) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        currentPosition = LatLng(position.latitude, position.longitude);
      } catch (e) {
        print("❌ 위치 획득 실패: $e");
      }
    }

    final client = MqttServerClient(
      'zerowin.ddns.net',
      'flutter_client_${DateTime.now().millisecondsSinceEpoch}',
    );
    client.port = 18833;
    client.logging(on: true);
    client.keepAlivePeriod = 20;
    client.onDisconnected = () => print('🔌 MQTT 연결 끊김');

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .authenticateAs('zerowin', 'test1234')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMessage;

    try {
      await client.connect();
    } catch (e) {
      print('❌ MQTT 연결 실패: $e');
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('✅ MQTT 연결 성공');

      final topic = 'test/holy-iot/log';

      // JSON 메시지 생성
      final payload = jsonEncode({
        'message': 'SOS ALARM',
        'timestamp': DateTime.now().toIso8601String(),
        'location': {
          'latitude': currentPosition?.latitude,
          'longitude': currentPosition?.longitude,
        },
      });

      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);

      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);

      await Future.delayed(Duration(seconds: 1));
      client.disconnect();
      print('📤 MQTT 메시지 전송 완료: $payload');

      // ✅ 메시지박스 추가
      // if (context != null) {
      //   showDialog(
      //     context: context,
      //     builder:
      //         (ctx) => AlertDialog(
      //           title: const Text("📡 SOS 전송 완료"),
      //           content: Text("현재 위치와 함께 MQTT로 전송되었습니다."),
      //           actions: [
      //             TextButton(
      //               onPressed: () => Navigator.of(ctx).pop(),
      //               child: const Text("확인"),
      //             ),
      //           ],
      //         ),
      //   );
      // }
      Fluttertoast.showToast(
        msg: "MQTT 메시지 전송 완료!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } else {
      print('❌ MQTT 연결 실패 상태: ${client.connectionStatus}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BLE SOS 자동전화")),
      body: Column(
        children: [
          // 버튼 영역
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _startService,
                  child: const Text("백그라운드 BLE 감시 시작"),
                ),
                ElevatedButton(
                  onPressed: _stopService,
                  child: const Text("서비스 중지"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await publishMqttMessage(context);
                  },
                  child: const Text("MQTT 메시지 보내기"),
                ),
              ],
            ),
          ),

          // 지도 영역
          Expanded(
            child:
                currentPosition == null
                    ? Center(child: CircularProgressIndicator())
                    : GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: currentPosition!,
                        zoom: 15,
                      ),
                      myLocationEnabled: true,
                      onMapCreated: (controller) {
                        mapController = controller;
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
