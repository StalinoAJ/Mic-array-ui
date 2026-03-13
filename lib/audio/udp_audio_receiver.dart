import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../state/app_state.dart';

/// Receives raw 4-channel PCM over UDP and emits de-interleaved channel data.
/// Packet format from ESP32:
///   Header (optional): 4 bytes → [magic_hi, magic_lo, channel_count, flags]
///   Audio: N × 4 × 2 bytes → int16 interleaved [ch0,ch1,ch2,ch3, ch0,ch1,ch2,ch3 ...]
class UdpAudioReceiver {
  static const int sampleRate = 16000;
  static const int frameSize = 512; // samples per channel per frame
  static const int channels = 4;
  static const int magic = 0xDA5E;

  final AppState appState;

  bool _running = false;

  // Accumulators per channel
  final List<List<double>> _buffers = List.generate(channels, (_) => []);
  int _samplesAccumulated = 0;

  // Streams
  final _monoStreamController = StreamController<Float32List>.broadcast();
  final _doaStreamController = StreamController<List<Float64List>>.broadcast();

  Stream<Float32List> get monoStream => _monoStreamController.stream;
  Stream<List<Float64List>> get channelStream => _doaStreamController.stream;

  UdpAudioReceiver({required this.appState});

  RawDatagramSocket? _socket;

  Future<void> start() async {
    if (_running) return;
    _running = true;

    try {
      _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4, appState.udpPort);
      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _processPacket(datagram.data);
          }
        }
      });
      print("DEBUG: [UDP Receiver] Listening on port ${appState.udpPort}");
    } catch (e) {
      print("ERROR: [UDP Receiver] Failed to bind: $e");
      _running = false;
    }
  }

  void processBlePacket(List<int> packet) {
    // Keep for backward compatibility or remove
    _processPacket(Uint8List.fromList(packet));
  }

  void _processPacket(Uint8List data) {
    appState.trackPacket();
    int offset = 0;

    // Parse optional magic header
    if (data.length >= 4) {
      final magicVal = (data[0] << 8) | data[1];
      if (magicVal == magic) {
        // data[2] = channel count, data[3] = flags
        offset = 4;
      }
    }

    final audioData = data.sublist(offset);
    final bytesPerSample = channels * 2; // 4 channels × 2 bytes (int16)
    if (audioData.isEmpty || audioData.length % bytesPerSample != 0) return;

    final sampleCount = audioData.length ~/ bytesPerSample;
    final byteData = ByteData.view(
      audioData.buffer,
      audioData.offsetInBytes,
    );

    for (int s = 0; s < sampleCount; s++) {
      for (int ch = 0; ch < channels; ch++) {
        final idx = (s * channels + ch) * 2;
        final sample = byteData.getInt16(idx, Endian.little) / 32768.0;
        _buffers[ch].add(sample);
      }
      _samplesAccumulated++;

      if (_samplesAccumulated >= frameSize) {
        _emitFrame();
      }
    }
  }

  void _emitFrame() {
    final List<double> levels = [];

    // Build per-channel Float64Lists
    final channelArrays = List.generate(channels, (ch) {
      final arr = Float64List(frameSize);
      final buf = _buffers[ch];

      double minVal = 4095.0, maxVal = 0.0, sum = 0;
      for (int i = 0; i < frameSize; i++) {
        double val = buf[i] * 32768.0; // Raw units (0-4095)
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;
        sum += buf[i];
      }

      // Calculate Peak-to-Peak Loudness for UI
      // 400 unit swing will be half-bar (0.5), 800+ will be full-bar (1.0)
      double p2p = maxVal - minVal;
      levels.add((p2p / 800.0).clamp(0.005, 1.0));

      double avg = sum / frameSize; // DC estimate
      for (int i = 0; i < frameSize; i++) {
        // Boost gain specifically for AI/DOA math
        arr[i] = (buf[i] - avg) * 50.0;
      }
      return arr;
    });

    appState.updateMicLevels(levels);

    // Build mono mix
    final mono = Float32List(frameSize);
    for (int i = 0; i < frameSize; i++) {
      double sum = 0;
      for (int ch = 0; ch < channels; ch++) {
        sum += channelArrays[ch][i];
      }
      mono[i] = (sum / channels).clamp(-1.0, 1.0);
    }

    _monoStreamController.add(mono);
    _doaStreamController.add(channelArrays);

    // Keep 50% overlap for next frame
    for (int ch = 0; ch < channels; ch++) {
      _buffers[ch] = _buffers[ch].sublist(frameSize ~/ 2);
    }
    _samplesAccumulated = frameSize ~/ 2;
  }

  Future<void> stop() async {
    _running = false;
  }

  void dispose() {
    stop();
    _monoStreamController.close();
    _doaStreamController.close();
  }
}
