import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:deaf_assist/doa/gcc_phat.dart';

void main() {
  group('GCC-PHAT DOA Algorithm', () {
    late GccPhat doa;

    setUp(() {
      doa = GccPhat(micSpacingM: 0.05);
    });

    test('returns null for insufficient samples', () {
      final channels = List.generate(4, (_) => Float64List(64));
      final result = doa.estimate(channels, 16000);
      expect(result, isNull);
    });

    test('returns non-null for valid 4-channel input', () {
      // Synthetic signal: 440 Hz tone
      const int sr = 16000;
      const int n = 1024;
      final channel0 = Float64List(n);
      for (int i = 0; i < n; i++) {
        channel0[i] = (i % 2 == 0) ? 0.5 : -0.5; // square wave
      }
      final channels = [
        channel0,
        Float64List(n), // silence on other channels
        Float64List(n),
        Float64List(n),
      ];
      final result = doa.estimate(channels, sr);
      expect(result, isNotNull);
      expect(result!.azimuth, inInclusiveRange(0.0, 360.0));
      expect(result.confidence, inInclusiveRange(0.0, 1.0));
    });

    test('azimuth is in valid range for identical signals', () {
      const int n = 1024;
      const int sr = 16000;
      final signal = Float64List.fromList(
        List.generate(n, (i) => i % 4 == 0 ? 0.8 : -0.1),
      );
      final channels = List.generate(4, (_) => Float64List.fromList(signal));
      final result = doa.estimate(channels, sr);
      expect(result, isNotNull);
      expect(result!.azimuth, inInclusiveRange(0.0, 360.0));
    });

    test('FFT size is correct power of 2', () {
      // Indirectly tested via successful estimate with non-power-of-2 length
      const int n = 700; // not a power of 2
      const int sr = 16000;
      final signal = Float64List(n);
      for (int i = 0; i < n; i++) signal[i] = 0.1 * (i % 3 - 1);
      final channels = List.generate(4, (_) => Float64List.fromList(signal));
      final result = doa.estimate(channels, sr);
      // Should not throw; returns valid result with enough samples
      expect(result, isNotNull);
    });
  });
}
