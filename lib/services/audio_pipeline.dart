import 'dart:async';
import 'dart:math';
import 'alert_service.dart';
import '../state/app_state.dart';
import '../doa/gcc_phat.dart';
import '../audio/udp_audio_receiver.dart';
import '../audio/wifi_control_channel.dart';
import '../classification/yamnet_classifier.dart';

/// Central orchestrator – wires together all services and manages demo mode.
class AudioPipeline {
  final AppState appState;
  late UdpAudioReceiver _udpReceiver;
  late WifiControlChannel _wifi;
  late YamNetClassifier _classifier;
  late AlertService _alertService;
  late GccPhat _doa;

  StreamSubscription? _monoSub;
  StreamSubscription? _channelSub;
  StreamSubscription? _classificationSub;
  Timer? _demoTimer;

  AudioPipeline({required this.appState});

  Future<void> init() async {
    _classifier = YamNetClassifier();
    await _classifier.load();

    _doa = GccPhat(micSpacingM: appState.micSpacingCm / 100.0);
    _udpReceiver = UdpAudioReceiver(appState: appState);
    _wifi = WifiControlChannel(appState: appState);
    _alertService = AlertService();
    await _alertService.init();

    // Wire classifier outputs
    _classificationSub = _classifier.results.listen((results) {
      if (results.isEmpty) return;
      final top = results.first;
      if (top.confidence >= appState.confidenceThreshold) {
        final event = SoundEvent(
          label: top.label,
          confidence: top.confidence,
          direction: appState.latestDirection,
          timestamp: DateTime.now(),
        );
        appState.addSoundEvent(event);
        _alertService.onSoundEvent(event, appState.notificationsEnabled);

        if (event.direction != null) {
          final dirStr = event.direction!.cardinalLabel.toLowerCase();
          _wifi.sendMessage(dirStr);
        }
      }
    });
  }

  Future<void> connectAudioStream() async {
    _monoSub?.cancel();
    _channelSub?.cancel();

    // Connect WiFi control first
    bool connected = await _wifi.connect();
    if (!connected) return;

    _monoSub = _udpReceiver.monoStream.listen(_classifier.processFrame);
    _channelSub = _udpReceiver.channelStream.listen((channels) {
      final result = _doa.estimate(channels, UdpAudioReceiver.sampleRate);
      if (result != null) {
        appState.updateDirection(
          DirectionEvent(
            azimuth: result.azimuth,
            confidence: result.confidence,
            timestamp: DateTime.now(),
          ),
        );
      }
    });

    await _udpReceiver.start();
  }

  // Keep 'ble' name for compatibility with UI parts that use pipeline.ble
  WifiControlChannel get ble => _wifi;
  WifiControlChannel get wifi => _wifi;

  void startDemo() {
    appState.demoMode = true;
    appState.setConnectionStatus(ConnectionStatus.connected);
    appState.setBatteryLevel(87);

    final rand = Random();
    final demoSounds = [
      ('Car horn', 0.92),
      ('Siren', 0.89),
      ('Dog bark', 0.78),
      ('Speech', 0.65),
      ('Music', 0.71),
      ('Alarm', 0.85),
      ('Doorbell', 0.76),
      ('Gunshot, gunfire', 0.88),
      ('Crowd', 0.61),
    ];
    double azimuth = 45;
    double azTarget = 45;

    _demoTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      // Smoothly animate direction
      azTarget = rand.nextDouble() * 360;
      azimuth = azimuth + (azTarget - azimuth) * 0.3;
      azimuth = azimuth % 360;

      appState.updateDirection(
        DirectionEvent(
          azimuth: azimuth,
          confidence: 0.6 + rand.nextDouble() * 0.4,
          timestamp: DateTime.now(),
        ),
      );

      final sound = demoSounds[rand.nextInt(demoSounds.length)];
      final confidence = sound.$2 + (rand.nextDouble() - 0.5) * 0.1;
      final event = SoundEvent(
        label: sound.$1,
        confidence: confidence.clamp(0.5, 0.99),
        direction: appState.latestDirection,
        timestamp: DateTime.now(),
      );
      appState.addSoundEvent(event);
      _alertService.onSoundEvent(event, appState.notificationsEnabled);

      if (event.direction != null) {
        final dirStr = event.direction!.cardinalLabel.toLowerCase();
        _wifi.sendMessage(dirStr);
      }
    });
  }

  void stopDemo() {
    _demoTimer?.cancel();
    _demoTimer = null;
    appState.demoMode = false;
    appState.setConnectionStatus(ConnectionStatus.disconnected);
    appState.clearEvents();
  }

  Future<void> dispose() async {
    _demoTimer?.cancel();
    _monoSub?.cancel();
    _channelSub?.cancel();
    _classificationSub?.cancel();
    _udpReceiver.dispose();
    _wifi.dispose();
    _classifier.dispose();
  }
}
