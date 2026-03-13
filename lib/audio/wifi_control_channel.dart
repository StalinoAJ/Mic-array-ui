import 'dart:async';
import 'dart:io';
import '../state/app_state.dart';

class WifiControlChannel {
  final AppState appState;
  final int tcpPort = 5000;
  Socket? _socket;

  bool _isConnected = false;

  WifiControlChannel({required this.appState});

  Future<bool> connect() async {
    appState.setConnectionStatus(ConnectionStatus.connecting);
    try {
      _socket = await Socket.connect(appState.udpHost, tcpPort,
          timeout: const Duration(seconds: 5));
      _isConnected = true;
      appState.setConnectionStatus(ConnectionStatus.connected);
      print("DEBUG: [WiFi Control] Connected to ${appState.udpHost}:$tcpPort");

      _socket!.listen((data) {
        _handleData(data);
      }, onDone: () {
        disconnect();
      }, onError: (e) {
        print("ERROR: [WiFi Control] Socket error: $e");
        disconnect();
      });

      // Handshake
      sendHandshake();

      return true;
    } catch (e) {
      print("ERROR: [WiFi Control] Failed to connect: $e");
      appState.setConnectionStatus(ConnectionStatus.disconnected);
      return false;
    }
  }

  void _handleData(List<int> data) {
    try {
      if (data.isEmpty) return;
      // Simple protocol: first byte is system status (0: Idle, 1: Listening, 2: Alerting)
      // Second byte is battery level
      if (data.length >= 1) {
        int status = data[0];
        if (status == 0)
          appState.setSystemStatus(SystemStatus.idle);
        else if (status == 1)
          appState.setSystemStatus(SystemStatus.listening);
        else if (status == 2) appState.setSystemStatus(SystemStatus.alerting);
      }
      if (data.length >= 2) {
        appState.setBatteryLevel(data[1]);
      }
    } catch (e) {
      print("ERROR: [WiFi Control] Data processing error: $e");
    }
  }

  void sendHandshake() {
    if (_isConnected && _socket != null) {
      _socket!.write("HELO\n");
      print("DEBUG: [WiFi Control] Sent HELO Handshake");
    }
  }

  void sendMessage(String message) {
    if (_isConnected && _socket != null) {
      _socket!.write(message);
    }
  }

  void disconnect() {
    _isConnected = false;
    _socket?.destroy();
    _socket = null;
    appState.setConnectionStatus(ConnectionStatus.disconnected);
    print("DEBUG: [WiFi Control] Disconnected");
  }

  void dispose() {
    disconnect();
  }
}
