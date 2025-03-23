import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MaterialApp(home: SosAutoCallPage()));
}

class SosAutoCallPage extends StatefulWidget {
  const SosAutoCallPage({super.key});
  @override
  State<SosAutoCallPage> createState() => _SosAutoCallPageState();
}

class _SosAutoCallPageState extends State<SosAutoCallPage> {
  bool _sosPending = false;
  Timer? _callTimer;
  final String phoneNumber = "01025195254";

  static const platform = MethodChannel('com.example.beacon_sos_test');

  Future<void> requestPhonePermission() async {
    final status = await Permission.phone.request();
    if (status != PermissionStatus.granted) {
      print("전화 권한이 거부되었습니다.");
    }
  }

  @override
  void initState() {
    super.initState();
    requestPhonePermission();

    _startScan();
  }

  Future<void> _startScan() async {
    await [
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
      Permission.phone,
    ].request();

    FlutterBluePlus.startScan();

    FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final adv = result.advertisementData;

        for (final data in adv.serviceData.values) {
          if (data.length > 10) {
            if (data[10] == 0x06 && data[11] == 0x01 && !_sosPending) {
              _handleSosDetected();
            }
          }
        }
      }
    });
  }

  void _handleSosDetected() {
    _sosPending = true;

    Fluttertoast.showToast(
      msg: "🚨 SOS 감지됨! 5초 후 전화 연결 예정.",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        _callTimer = Timer(const Duration(seconds: 5), () {
          Navigator.of(context).pop();
          _makePhoneCall(phoneNumber);
        });

        return AlertDialog(
          title: const Text("🚨 SOS 감지됨"),
          content: Text(
            "SOS 버튼이 눌렸습니다.\n"
            "5초 후에 전화를 걸도록 하겠습니다.\n\n"
            "취소를 하려면 아래 버튼을 누르세요.\n"
            "전화번호는 ${_formatPhone(phoneNumber)} 입니다.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                _callTimer?.cancel();
                Navigator.of(context).pop();
                setState(() => _sosPending = false);
              },
              child: const Text("취소"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _makePhoneCall(String number) async {
    try {
      await platform.invokeMethod('makeCall', {'number': number});
    } catch (e) {
      Fluttertoast.showToast(
        msg: "📞 전화 연결 실패: $e",
        backgroundColor: Colors.black,
      );
    }
    setState(() => _sosPending = false);
  }

  String _formatPhone(String number) {
    if (number.length == 11) {
      return "${number.substring(0, 3)}-${number.substring(3, 7)}-${number.substring(7)}";
    }
    return number;
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BLE SOS 자동 전화")),
      body: const Center(child: Text("BLE 비콘을 감지 중입니다...")),
    );
  }
}
