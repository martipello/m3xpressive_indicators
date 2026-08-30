// Vendored from package:m3e_progress_indicator (https://pub.dev/packages/m3e_progress_indicator)
// because that package requires Dart SDK >=3.12.1 / Flutter >=3.47.0, newer
// than this project's SDK. Ported to plain package:flutter/material.dart.
//
// Simplified per the M3 spec anatomy (https://m3.material.io/components/progress-indicators/specs):
// the active wavy indicator only ever covers part of the ring, with a plain
// track covering the rest and a small gap between them — there is no
// "fully wavy ring" mode. The stateful "loading" behaviour (fill 0→1, then
// repeat) lives in the widget, driving this painter with an ordinary
// progress value rather than this painter having its own indeterminate mode.
//
// For the vibes-accurate rotating indeterminate motion instead, see
// M3XCircularWavyLoadingIndicator / M3XCircularWavyLoadingPainter.
//
// Copyright (c) 2026 Mudit Purohit
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'wavy_arc_path.dart';

class M3XCircularWavyProgressPainter extends CustomPainter {
  final double progress;

  final double wavePhase; // 0→1, one wavelength of scroll per cycle
  final double amplitude; // 0→1 (morphed)
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final double trackStrokeWidth;
  final double gapSize;
  final double wavelength;
  final bool isLtr;

  M3XCircularWavyProgressPainter({
    required this.progress,
    required this.wavePhase,
    required this.amplitude,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.trackStrokeWidth,
    required this.gapSize,
    required this.wavelength,
    required this.isLtr,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    canvas.save();
    if (!isLtr) {
      canvas.translate(cx, cy);
      canvas.scale(-1.0, 1.0);
      canvas.translate(-cx, -cy);
    }

    final double maxStroke = math.max(strokeWidth, trackStrokeWidth);
    final double R = (math.min(size.width, size.height) - maxStroke) / 2;
    final double N = waveCycleCount(radius: R, wavelength: wavelength);

    // Amplitude in pixels: scales the wave radially.
    final double A = amplitude * strokeWidth * 1.5;

    // Phase: wavePhase 0→1 scrolls one full wavelength.
    final double phase = wavePhase * 2 * math.pi;

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

    // Gap in radians (arc length gapSize at radius R).
    final double capWidth = maxStroke / 2.0;
    final double gapRad = (gapSize + capWidth * 2.0) / R;

    final double prog = progress.clamp(0.0, 1.0);
    final double progressSweep = prog * 2 * math.pi;

    // Active arc: starts at 12 o'clock (-π/2), goes clockwise.
    const double startAngle = -math.pi / 2;

    if (progressSweep > 0) {
      final Path wavePath = buildWaveArcPath(
        cx: cx,
        cy: cy,
        R: R,
        A: A,
        startAngle: startAngle,
        sweepAngle: progressSweep,
        N: N,
        phase: phase,
      );
      canvas.drawPath(wavePath, activePaint);
    }

    // Track: plain circle arc covering the remainder, after a small gap.
    final double trackSweep = 2 * math.pi - progressSweep - 2 * gapRad;
    if (trackSweep > 0 && trackColor != Colors.transparent) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: R),
        startAngle + progressSweep + gapRad,
        trackSweep,
        false,
        trackPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant M3XCircularWavyProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackStrokeWidth != trackStrokeWidth ||
        oldDelegate.gapSize != gapSize ||
        oldDelegate.wavelength != wavelength ||
        oldDelegate.isLtr != isLtr;
  }
}
