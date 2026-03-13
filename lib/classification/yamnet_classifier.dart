import 'dart:async';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

class ClassificationResult {
  final String label;
  final double confidence;
  ClassificationResult(this.label, this.confidence);
}

/// Runs YAMNet TFLite model on 16kHz mono audio frames.
/// YAMNet expects: 15600 samples (0.975s) → outputs 521-class scores.
class YamNetClassifier {
  static const int yamnetInputSize = 15600;
  static const int numClasses = 521;
  static const String modelPath = 'assets/models/yamnet.tflite';

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoaded = false;

  // Accumulation buffer for YAMNet's large input window
  final List<double> _accumBuffer = [];
  int _logCounter = 0;

  final StreamController<List<ClassificationResult>> _resultsController =
      StreamController.broadcast();
  Stream<List<ClassificationResult>> get results => _resultsController.stream;

  Future<void> load() async {
    try {
      _interpreter = await Interpreter.fromAsset(modelPath);
      _labels = await _loadLabels();
      _isLoaded = true;
    } catch (e) {
      // Model not found – fall back to demo mode labels
      _isLoaded = false;
    }
  }

  Future<List<String>> _loadLabels() async {
    // YAMNet's 521 classes – returning common ones for brevity
    // In production, load from yamnet_class_map.csv asset
    return [
      'Speech',
      'Child speech, kid speaking',
      'Conversation',
      'Narration, monologue',
      'Babbling',
      'Speech synthesizer',
      'Shout',
      'Bellow',
      'Whoop',
      'Yell',
      'Screaming',
      'Whispering',
      'Laughter',
      'Baby laughter',
      'Giggle',
      'Snicker',
      'Belly laugh',
      'Chuckle, chortle',
      'Crying, sobbing',
      'Baby cry, infant cry',
      'Whimper',
      'Wail, moan',
      'Sigh',
      'Singing',
      'Choir',
      'Yodeling',
      'Chant',
      'Mantra',
      'Male singing',
      'Female singing',
      'Child singing',
      'Male speech, man speaking',
      'Female speech, woman speaking',
      'Whistling',
      'Breathing',
      'Snoring',
      'Cough',
      'Sneeze',
      'Clapping',
      'Finger snapping',
      'Footsteps',
      'Calculator',
      'Typewriter',
      'Computer keyboard',
      'Mouse',
      'Writing',
      'Alarm',
      'Telephone bell ringing',
      'Ringtone',
      'Telephone',
      'Cell phone',
      'Electronic piano',
      'Piano',
      'Guitar',
      'Violin',
      'Drums',
      'Drum machine',
      'Music',
      'Pop music',
      'Rock music',
      'Dance music',
      'Classical music',
      'Electronic music',
      'Background music',
      'Jingle',
      'Middle Eastern music',
      'Dog',
      'Dog bark',
      'Dog baying',
      'Bow-wow',
      'Cat',
      'Meow',
      'Purr',
      'Car',
      'Car alarm',
      'Car horn',
      'Car passing by',
      'Motorcycle',
      'Truck',
      'Bus',
      'Race car, auto racing',
      'Bicycle',
      'Ambulance (siren)',
      'Police car (siren)',
      'Fire engine, fire truck (siren)',
      'Civil defense siren',
      'Siren',
      'Emergency vehicle',
      'Glass',
      'Breaking',
      'Shatter',
      'Knock',
      'Door',
      'Doorbell',
      'Gunshot, gunfire',
      'Explosion',
      'Thunderstorm',
      'Rain',
      'Wind',
      'Crowd',
      'Applause',
      'Cheer',
      'Hubbub',
      'Speech noise, speech babble',
      'Inside, small room',
      'Inside, large room or hall',
      'Outside, rural or natural',
      'Outside, urban or manmade',
      'Wind noise',
      'Noise',
      'Environmental noise',
    ];
  }

  void processFrame(Float32List monoFrame) {
    _accumBuffer.addAll(monoFrame);

    // Log buffer progress every 30 frames
    if (_logCounter++ % 30 == 0) {
      print(
          "DEBUG: [Classifier] Buffer filling: ${_accumBuffer.length} / $yamnetInputSize samples");
    }

    while (_accumBuffer.length >= yamnetInputSize) {
      final input = _accumBuffer.sublist(0, yamnetInputSize);
      _accumBuffer.removeRange(0, yamnetInputSize ~/ 2); // 50% hop

      print(
          "DEBUG: [Classifier] Window full ($yamnetInputSize samples). TRIGGERING INFERENCE...");
      _runInference(input);
    }
  }

  void _runInference(List<double> samples) {
    if (!_isLoaded || _interpreter == null) {
      _emitDemoResults();
      return;
    }

    try {
      // YAMNet expects input [15600] and output [1, 521]
      final inputData = Float32List.fromList(samples);
      // Use a standard nested List for the output buffer
      final outputBuffer =
          List.generate(1, (_) => List<double>.filled(numClasses, 0.0));

      _interpreter!.run(inputData, outputBuffer);

      final List<double> scores = outputBuffer[0];
      final results = <ClassificationResult>[];
      for (int i = 0; i < scores.length && i < _labels.length; i++) {
        results.add(ClassificationResult(_labels[i], scores[i]));
      }

      results.sort((a, b) => b.confidence.compareTo(a.confidence));
      final top = results.first;
      print(
          "DEBUG: [Classifier] Inference Result: ${top.label} (${(top.confidence * 100).toStringAsFixed(1)}%)");

      _resultsController.add(results.take(5).toList());
    } catch (e) {
      print("DEBUG: [Classifier] Inference Error: $e");
      _emitDemoResults();
    }
  }

  void _emitDemoResults() {
    /* Handled externally in demo mode */
  }

  void dispose() {
    _interpreter?.close();
    _resultsController.close();
  }
}
