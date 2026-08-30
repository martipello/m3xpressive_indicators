// Vendored from package:m3e_progress_indicator (https://pub.dev/packages/m3e_progress_indicator)
// because that package requires Dart SDK >=3.12.1 / Flutter >=3.47.0, newer
// than this project's SDK. Ported to plain package:flutter/material.dart.
//
// Simplified per the M3 spec anatomy (https://m3.material.io/components/progress-indicators/specs):
// there is no separate "indeterminate" rendering mode (the original multi-segment
// bouncing-lines animation was dropped) — when used as a "loading" indicator, the
// widget drives this painter with an ordinary progress value that fills 0→1 and
// repeats, reusing the same determinate rendering the whole time.
//
// Copyright (c) 2026 Mudit Purohit
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class M3XLinearWavyProgressPainter extends CustomPainter {
  final double progress;
  final double waveOffset;
  final double amplitude;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final double trackStrokeWidth;
  final double gapSize;
  final double stopSize;
  final double wavelength;
  final bool isLtr;

  final M3XLinearWavyProgressPathCache _cache;

  M3XLinearWavyProgressPainter({
    required this.progress,
    required this.waveOffset,
    required this.amplitude,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.trackStrokeWidth,
    required this.gapSize,
    required this.stopSize,
    required this.wavelength,
    required this.isLtr,
    required M3XLinearWavyProgressPathCache cache,
  }) : _cache = cache;

  // Pre-computes a full wavy path and scales it to fit size.
  WavyPathData _createWavyPath(Size size) {
    final Path path = Path();
    final double height = size.height;
    final double width = size.width;

    path.moveTo(0.0, 0.0);

    final double halfWavelength = wavelength / 2.0;
    double anchorX = halfWavelength;
    double controlX = halfWavelength / 2.0;
    double controlY = height - strokeWidth;

    // Plot path with extra phase to support continuous scroll.
    final double widthWithExtraPhase = width + wavelength * 2.0;
    while (anchorX <= widthWithExtraPhase) {
      path.quadraticBezierTo(controlX, controlY, anchorX, 0.0);
      anchorX += halfWavelength;
      controlX += halfWavelength;
      controlY *= -1.0;
    }

    final Rect bounds = path.getBounds();
    final Matrix4 translateMatrix =
        Matrix4.translationValues(0.0, height / 2.0, 0.0);
    final Path transformedPath = path.transform(translateMatrix.storage);

    final List<PathMetric> metricsList =
        transformedPath.computeMetrics().toList();
    if (metricsList.isNotEmpty) {
      final PathMetric metric = metricsList.first;
      final double scale = metric.length / (bounds.width + 0.00000001);
      return WavyPathData(metric, scale);
    }
    return const WavyPathData(null, 1.0);
  }

  WavyPathData _getOrBuildPath(Size size) {
    if (_cache.size == size &&
        _cache.strokeWidth == strokeWidth &&
        _cache.wavelength == wavelength &&
        _cache.pathData != null) {
      return _cache.pathData!;
    }
    final pathData = _createWavyPath(size);
    _cache.size = size;
    _cache.strokeWidth = strokeWidth;
    _cache.wavelength = wavelength;
    _cache.pathData = pathData;
    return pathData;
  }

  Path? _extractWaveSegment({
    required double startFraction,
    required double endFraction,
    required Size size,
    required WavyPathData pathData,
  }) {
    if ((endFraction - startFraction) <= 0.0) return null;
    final metric = pathData.metric;
    if (metric == null) return null;

    final double width = size.width;
    final double halfHeight = size.height / 2;
    final double strokeCapWidth = (strokeWidth > width)
        ? 0.0
        : math.max(strokeWidth / 2, trackStrokeWidth / 2);

    final double barTail =
        (startFraction * width).clamp(strokeCapWidth, width - strokeCapWidth);
    final double barHead =
        (endFraction * width).clamp(strokeCapWidth, width - strokeCapWidth);
    final double waveShift = amplitude > 0 ? waveOffset * wavelength : 0.0;

    final double startDist = (barTail + waveShift) * pathData.scale;
    final double endDist = (barHead + waveShift) * pathData.scale;
    final Path segmentPath = metric.extractPath(startDist, endDist);

    final Matrix4 matrix =
        Matrix4.translationValues(-waveShift, halfHeight, 0.0) *
            Matrix4.diagonal3Values(1.0, amplitude, 1.0) *
            Matrix4.translationValues(0.0, -halfHeight, 0.0);
    return segmentPath.transform(matrix.storage);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackStrokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.save();
    if (!isLtr) {
      canvas.translate(size.width, 0);
      canvas.scale(-1.0, 1.0);
    }

    final WavyPathData pathData = _getOrBuildPath(size);
    final double prog = progress.clamp(0.0, 1.0);

    final Path? activePath = _extractWaveSegment(
        startFraction: 0.0, endFraction: prog, size: size, pathData: pathData);

    // Track: from just after the active indicator (plus gap) to the stop indicator.
    final double strokeCapWidth =
        math.max(strokeWidth / 2, trackStrokeWidth / 2);
    final double activeEndX =
        (prog * size.width).clamp(strokeCapWidth, size.width - strokeCapWidth);
    final double trackStart = activeEndX + gapSize + strokeCapWidth * 2;
    final double trackEnd = size.width - strokeCapWidth;

    if (trackColor != Colors.transparent && trackStart < trackEnd) {
      final Path trackPath = Path()
        ..moveTo(trackStart, size.height / 2)
        ..lineTo(trackEnd, size.height / 2);
      canvas.drawPath(trackPath, trackPaint);
    }

    if (activePath != null) {
      canvas.drawPath(activePath, activePaint);
    }

    canvas.restore();

    _drawStopIndicator(canvas: canvas, size: size, progressEnd: prog);
  }

  /// Draws a small filled dot marking the end of the track (100% point).
  void _drawStopIndicator({
    required Canvas canvas,
    required Size size,
    required double progressEnd,
  }) {
    if (stopSize <= 0) return;

    final double strokeCapOffset = strokeWidth / 2;
    double finalStopSize = math.min(stopSize, strokeWidth);

    const double maxStopOffset = 6.0;
    final double stopOffset =
        math.min((strokeWidth - finalStopSize) / 2, maxStopOffset);

    double indicatorX = size.width - finalStopSize - stopOffset;
    final double progressX = size.width * progressEnd + strokeCapOffset;

    if (indicatorX <= progressX) {
      finalStopSize = math.max(0.0, finalStopSize - (progressX - indicatorX));
      indicatorX = progressX;
    }

    if (finalStopSize <= 0) return;

    final Paint stopPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.save();
    if (!isLtr) {
      canvas.translate(size.width, 0);
      canvas.scale(-1.0, 1.0);
    }
    canvas.drawCircle(
      Offset(indicatorX + finalStopSize / 2, size.height / 2),
      finalStopSize / 2,
      stopPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant M3XLinearWavyProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.waveOffset != waveOffset ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackStrokeWidth != trackStrokeWidth ||
        oldDelegate.gapSize != gapSize ||
        oldDelegate.stopSize != stopSize ||
        oldDelegate.wavelength != wavelength ||
        oldDelegate.isLtr != isLtr;
  }
}

class WavyPathData {
  const WavyPathData(this.metric, this.scale);

  final PathMetric? metric;
  final double scale;
}

/// Caches the built wave path across frames for [M3XLinearWavyProgressPainter]
/// — it only depends on [Size], stroke width and wavelength, all of which are
/// usually stable. One instance should be kept alive for the lifetime of the
/// owning widget.
class M3XLinearWavyProgressPathCache {
  Size? size;
  double? strokeWidth;
  double? wavelength;
  WavyPathData? pathData;
}
