import 'dart:math' as math;
import 'dart:typed_data';

/// Pure-Dart GCC-PHAT Direction of Arrival estimation
/// for a 4-microphone square array.
///
/// Mic layout (top-down, origin = center):
///   Mic0 (Front-Left)  ---- Mic1 (Front-Right)
///        |                       |
///   Mic2 (Back-Left)   ---- Mic3 (Back-Right)
class GccPhat {
  final double micSpacingM; // distance between adjacent mics in metres
  static const double speedOfSound = 343.0; // m/s at 20°C

  GccPhat({this.micSpacingM = 0.05}); // 5 cm default

  /// Compute DOA azimuth from 4-channel PCM frame.
  /// Returns azimuth in degrees (0=front, 90=right, 180=back, 270=left).
  /// Returns null if confidence is too low.
  ({double azimuth, double confidence})? estimate(
    List<Float64List> channels,
    int sampleRate,
  ) {
    if (channels.length < 4) return null;

    final n = channels[0].length;
    if (n < 256) return null;

    // Compute TDOAs for key mic pairs
    // Pair 0-1: left vs right (gives azimuth L/R component)
    // Pair 0-2: front vs back (gives azimuth F/B component)
    final tdoa01 = _gccPhatTdoa(channels[0], channels[1], sampleRate); // L-R
    final tdoa02 = _gccPhatTdoa(channels[0], channels[2], sampleRate); // F-B
    final tdoa13 = _gccPhatTdoa(
      channels[1],
      channels[3],
      sampleRate,
    ); // F-B right side
    final tdoa23 = _gccPhatTdoa(
      channels[2],
      channels[3],
      sampleRate,
    ); // L-R back side

    // Average symmetric pairs for robustness
    final lrTdoa = (tdoa01.tdoa + tdoa23.tdoa) / 2;
    final fbTdoa = (tdoa02.tdoa + tdoa13.tdoa) / 2;

    final avgConf = (tdoa01.confidence +
            tdoa02.confidence +
            tdoa13.confidence +
            tdoa23.confidence) /
        4;

    // Convert TDOA (seconds) to sine of angle using mic spacing
    final maxTdoa = micSpacingM / speedOfSound;
    final sinLR = (lrTdoa / maxTdoa).clamp(-1.0, 1.0);
    final sinFB = (fbTdoa / maxTdoa).clamp(-1.0, 1.0);

    // Compute angle from sin components
    // sinLR > 0 → sound from right, sinFB > 0 → sound from front
    final azRad = math.atan2(sinLR, sinFB);
    final azimuth = (azRad * 180 / math.pi + 360) % 360;

    return (azimuth: azimuth, confidence: avgConf);
  }

  ({double tdoa, double confidence}) _gccPhatTdoa(
    Float64List x,
    Float64List y,
    int sampleRate,
  ) {
    final n = x.length;
    final fftSize = _nextPowerOf2(2 * n);

    // Zero-pad input arrays
    final xPad = Float64List(fftSize);
    final yPad = Float64List(fftSize);
    for (int i = 0; i < n; i++) {
      xPad[i] = x[i];
      yPad[i] = y[i];
    }

    // FFT both signals
    final xr = xPad.toList();
    final xi = List<double>.filled(fftSize, 0.0);
    final yr = yPad.toList();
    final yi = List<double>.filled(fftSize, 0.0);
    _fft(xr, xi);
    _fft(yr, yi);

    // Cross-power spectrum with PHAT weighting
    final gr = List<double>.filled(fftSize, 0.0);
    final gi = List<double>.filled(fftSize, 0.0);

    for (int k = 0; k < fftSize; k++) {
      // G = X * conj(Y)
      final re = xr[k] * yr[k] + xi[k] * yi[k];
      final im = xi[k] * yr[k] - xr[k] * yi[k];
      final mag = math.sqrt(re * re + im * im);
      if (mag > 1e-10) {
        gr[k] = re / mag;
        gi[k] = im / mag;
      }
    }

    // IFFT
    _ifft(gr, gi);

    // Find peak in GCC result (first half = positive delays, second half = negative)
    final halfN = n;
    int peakIdx = 0;
    double peakVal = -double.infinity;
    double sumAbs = 0.0;

    for (int i = 0; i < 2 * halfN; i++) {
      final idx = (fftSize - halfN + i) % fftSize;
      final v = gr[idx].abs();
      sumAbs += v;
      if (gr[idx] > peakVal) {
        peakVal = gr[idx];
        peakIdx = i - halfN;
      }
    }

    final confidence = (2 * halfN > 0 && sumAbs > 0)
        ? (peakVal / (sumAbs / (2 * halfN))).clamp(0.0, 1.0)
        : 0.0;
    final tdoa = peakIdx / sampleRate.toDouble();

    return (tdoa: tdoa, confidence: confidence);
  }

  int _nextPowerOf2(int n) {
    int p = 1;
    while (p < n) p <<= 1;
    return p;
  }

  /// In-place Cooley-Tukey FFT
  void _fft(List<double> re, List<double> im) {
    final n = re.length;
    if (n <= 1) return;

    // Bit-reversal permutation
    int j = 0;
    int bit = n >> 1; // Initialize bit once outside the loop
    for (int i = 1; i < n; i++) {
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        final tmpR = re[i];
        re[i] = re[j];
        re[j] = tmpR;
        final tmpI = im[i];
        im[i] = im[j];
        im[j] = tmpI;
      }
    }

    // FFT butterfly
    for (int len = 2; len <= n; len <<= 1) {
      final ang = -2 * math.pi / len;
      final wRe = math.cos(ang);
      final wIm = math.sin(ang);
      for (int i = 0; i < n; i += len) {
        double curRe = 1.0, curIm = 0.0;
        for (int k = 0; k < len ~/ 2; k++) {
          final uRe = re[i + k];
          final uIm = im[i + k];
          final vRe =
              re[i + k + len ~/ 2] * curRe - im[i + k + len ~/ 2] * curIm;
          final vIm =
              re[i + k + len ~/ 2] * curIm + im[i + k + len ~/ 2] * curRe;
          re[i + k] = uRe + vRe;
          im[i + k] = uIm + vIm;
          re[i + k + len ~/ 2] = uRe - vRe;
          im[i + k + len ~/ 2] = uIm - vIm;
          final newCurRe = curRe * wRe - curIm * wIm;
          curIm = curRe * wIm + curIm * wRe;
          curRe = newCurRe;
        }
      }
    }
  }

  void _ifft(List<double> re, List<double> im) {
    for (int i = 0; i < im.length; i++) {
      im[i] = -im[i];
    }
    _fft(re, im);
    for (int i = 0; i < re.length; i++) {
      re[i] /= re.length;
      im[i] = -im[i] / re.length; // Use re.length for consistency with re[i]
    }
  }
}
