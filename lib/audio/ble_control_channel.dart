import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../state/app_state.dart';

/// Handles BLE scanning, connecting, and subscribing to
/// battery level + custom status characteristic from the ESP32-S3.
class BleControlChannel {
  static const batteryServiceUuid = "0000180f-0000-1000-8000-00805f9b34fb";
  static const batteryCharUuid = "00002a19-0000-1000-8000-00805f9b34fb";
  // Custom service for status: idle/listening/alerting and device info
  static const customServiceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const statusCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  final AppState appState;
  BluetoothDevice? _device;
  StreamSubscription? _batterySubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _connectionSubscription;

  final _devicesController =
      StreamController<List<BluetoothDevice>>.broadcast();
  Stream<List<BluetoothDevice>> get foundDevices => _devicesController.stream;
  final List<BluetoothDevice> _foundDevices = [];

  BleControlChannel({required this.appState});

  Future<void> startScan({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    appState.setConnectionStatus(ConnectionStatus.scanning);
    _foundDevices.clear();
    _devicesController.add([]);

    await FlutterBluePlus.stopScan();
    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: false,
    );

    FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (!_foundDevices.any((d) => d.remoteId == r.device.remoteId)) {
          if (r.device.platformName.isNotEmpty ||
              r.advertisementData.advName.isNotEmpty) {
            _foundDevices.add(r.device);
            _devicesController.add(List.from(_foundDevices));
          }
        }
      }
    });

    await Future.delayed(timeout);
    if (appState.connectionStatus == ConnectionStatus.scanning) {
      appState.setConnectionStatus(ConnectionStatus.disconnected);
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    if (appState.connectionStatus == ConnectionStatus.scanning) {
      appState.setConnectionStatus(ConnectionStatus.disconnected);
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    _device = device;
    appState.setConnectionStatus(ConnectionStatus.connecting);

    try {
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      appState.setConnectionStatus(ConnectionStatus.disconnected);
      return;
    }

    _connectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        appState.setConnectionStatus(ConnectionStatus.disconnected);
        _cleanupSubscriptions();
      }
    });

    await _discoverAndSubscribe(device);
    appState.setConnectionStatus(ConnectionStatus.connected);
  }

  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    final services = await device.discoverServices();

    for (final service in services) {
      // Battery service
      if (service.uuid.toString().toLowerCase() == batteryServiceUuid) {
        for (final char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() == batteryCharUuid) {
            await char.setNotifyValue(true);
            _batterySubscription = char.onValueReceived.listen((value) {
              if (value.isNotEmpty) {
                appState.setBatteryLevel(value[0]);
              }
            });
            // Read initial value
            final val = await char.read();
            if (val.isNotEmpty) appState.setBatteryLevel(val[0]);
          }
        }
      }

      // Custom status service
      if (service.uuid.toString().toLowerCase() == customServiceUuid) {
        for (final char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() == statusCharUuid) {
            await char.setNotifyValue(true);
            _statusSubscription = char.onValueReceived.listen((value) {
              if (value.isNotEmpty) {
                switch (value[0]) {
                  case 0:
                    appState.setSystemStatus(SystemStatus.idle);
                    break;
                  case 1:
                    appState.setSystemStatus(SystemStatus.listening);
                    break;
                  case 2:
                    appState.setSystemStatus(SystemStatus.alerting);
                    break;
                }
              }
            });
          }
        }
      }
    }
  }

  Future<void> disconnect() async {
    _cleanupSubscriptions();
    await _device?.disconnect();
    _device = null;
    appState.setConnectionStatus(ConnectionStatus.disconnected);
  }

  void _cleanupSubscriptions() {
    _batterySubscription?.cancel();
    _statusSubscription?.cancel();
    _connectionSubscription?.cancel();
    _batterySubscription = null;
    _statusSubscription = null;
    _connectionSubscription = null;
  }

  void dispose() {
    _cleanupSubscriptions();
    _devicesController.close();
  }
}
