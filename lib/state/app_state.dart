import 'dart:collection';
import 'package:flutter/foundation.dart';

enum ConnectionStatus { disconnected, scanning, connecting, connected }

enum SystemStatus { idle, listening, alerting }

class DirectionEvent {
  final double azimuth; // 0-360 degrees, 0 = front
  final double confidence; // 0-1
  final DateTime timestamp;

  const DirectionEvent({
    required this.azimuth,
    required this.confidence,
    required this.timestamp,
  });

  String get cardinalLabel {
    if (azimuth >= 315 || azimuth < 45) return 'FRONT';
    if (azimuth >= 45 && azimuth < 135) return 'RIGHT';
    if (azimuth >= 135 && azimuth < 225) return 'BEHIND';
    return 'LEFT';
  }

  String get cardinalIcon {
    if (azimuth >= 315 || azimuth < 45) return '↑';
    if (azimuth >= 45 && azimuth < 135) return '→';
    if (azimuth >= 135 && azimuth < 225) return '↓';
    return '←';
  }
}

class SoundEvent {
  final String label;
  final double confidence; // 0-1
  final DirectionEvent? direction;
  final DateTime timestamp;
  final String emoji;

  SoundEvent({
    required this.label,
    required this.confidence,
    this.direction,
    required this.timestamp,
  }) : emoji = _labelToEmoji(label);

  static String _labelToEmoji(String label) {
    final l = label.toLowerCase();
    if (l.contains('siren') || l.contains('emergency')) return '🚨';
    if (l.contains('horn') || l.contains('car')) return '🚗';
    if (l.contains('dog') || l.contains('bark')) return '🐕';
    if (l.contains('music') || l.contains('song')) return '🎵';
    if (l.contains('speech') || l.contains('voice') || l.contains('shout'))
      return '🗣️';
    if (l.contains('alarm') || l.contains('bell')) return '🔔';
    if (l.contains('knock') || l.contains('door')) return '🚪';
    if (l.contains('baby') || l.contains('child')) return '👶';
    if (l.contains('thunder') || l.contains('rain')) return '⛈️';
    if (l.contains('glass') || l.contains('crash')) return '💥';
    if (l.contains('gun') || l.contains('shot')) return '⚠️';
    return '🔊';
  }

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(0)}%';

  bool get isHighPriority {
    final l = label.toLowerCase();
    return l.contains('siren') ||
        l.contains('alarm') ||
        l.contains('gun') ||
        l.contains('crash') ||
        l.contains('horn') ||
        l.contains('scream') ||
        l.contains('shout');
  }
}

class AppState extends ChangeNotifier {
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  SystemStatus _systemStatus = SystemStatus.idle;
  int? _batteryLevel;
  DirectionEvent? _latestDirection;
  SoundEvent? _latestSound;
  final Queue<SoundEvent> _recentEvents = Queue();
  static const int maxEvents = 20;

  // Settings
  String udpHost = '192.168.4.1'; // ESP32 AP default
  int udpPort = 5005;
  double confidenceThreshold = 0.45;
  bool notificationsEnabled = true;
  bool demoMode = false;
  double micSpacingCm = 5.0;

  // Latency tracking
  DateTime? _lastPacketTime;
  double _currentLatencyMs = 0.0;

  ConnectionStatus get connectionStatus => _connectionStatus;
  SystemStatus get systemStatus => _systemStatus;
  int? get batteryLevel => _batteryLevel;
  DirectionEvent? get latestDirection => _latestDirection;
  SoundEvent? get latestSound => _latestSound;
  List<SoundEvent> get recentEvents => _recentEvents.toList().reversed.toList();
  double get currentLatencyMs => _currentLatencyMs;

  void setConnectionStatus(ConnectionStatus status) {
    _connectionStatus = status;
    if (status == ConnectionStatus.connected) {
      _systemStatus = SystemStatus.listening;
    } else if (status == ConnectionStatus.disconnected) {
      _systemStatus = SystemStatus.idle;
    }
    notifyListeners();
  }

  void setSystemStatus(SystemStatus status) {
    _systemStatus = status;
    notifyListeners();
  }

  void setBatteryLevel(int? level) {
    _batteryLevel = level;
    notifyListeners();
  }

  void updateDirection(DirectionEvent event) {
    _latestDirection = event;
    notifyListeners();
  }

  void addSoundEvent(SoundEvent event) {
    _latestSound = event;
    _recentEvents.addLast(event);
    if (_recentEvents.length > maxEvents) {
      _recentEvents.removeFirst();
    }
    if (event.isHighPriority) {
      _systemStatus = SystemStatus.alerting;
    }
    notifyListeners();
  }

  void trackPacket() {
    final now = DateTime.now();
    if (_lastPacketTime != null) {
      _currentLatencyMs =
          now.difference(_lastPacketTime!).inMicroseconds / 1000.0;
    }
    _lastPacketTime = now;
  }

  void resetAlertStatus() {
    if (_systemStatus == SystemStatus.alerting) {
      _systemStatus = SystemStatus.listening;
      notifyListeners();
    }
  }

  void clearEvents() {
    _recentEvents.clear();
    _latestSound = null;
    _latestDirection = null;
    notifyListeners();
  }

  String get connectionLabel {
    switch (_connectionStatus) {
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.scanning:
        return 'Scanning...';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.connected:
        return 'Connected';
    }
  }

  String get systemLabel {
    switch (_systemStatus) {
      case SystemStatus.idle:
        return 'Idle';
      case SystemStatus.listening:
        return 'Listening';
      case SystemStatus.alerting:
        return 'Alert!';
    }
  }
}
