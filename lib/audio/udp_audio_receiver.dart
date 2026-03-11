import 'dart:async';
import 'dart:math';
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

  int _packetCounter = 0;

  Future<void> start() async {
    if (_running) return;
    _running = true;
  }

  void processBlePacket(List<int> packet) {
    if (!_running) return;
    if (packet.length > 10) {
      if (_packetCounter++ % 10 == 0) {
        print(
            "DEBUG: [BLE Receiver] Raw data arriving. Packet #$_packetCounter. Size: ${packet.length} bytes");
      }
    }
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

      double sumSq = 0;
      for (int i = 0; i < frameSize; i++) {
        arr[i] = buf[i];
        sumSq += arr[i] * arr[i];
      }

      // Calculate RMS level for this channel
      double rms = sqrt(sumSq / frameSize);
      levels.add(rms);

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
