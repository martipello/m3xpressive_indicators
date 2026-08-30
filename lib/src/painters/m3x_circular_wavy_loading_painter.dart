// Vibes-accurate M3 indeterminate motion, matching the head/tail model used by
// the classic Material circular indeterminate spinner
// (CircularIndeterminateAnimatorDelegate in material-components-android):
// the leading (head) edge grows out from the trailing (tail) edge to a fixed
// maximum sweep, then holds while the tail catches up to it — an asymmetric
// grow-then-collapse, not a symmetric pulse — while the whole arc rotates
// continuously around the track.
//
// Shares its wave geometry with M3XCircularWavyProgressPainter via
// wavy_arc_path.dart (which is itself ported from package:m3e_progress_indicator,
// https://pub.dev/packages/m3e_progress_indicator) — see that file for the
// shared math. This painter's motion is original work, not derived from the
// vendored package's indeterminate implementation — see THIRD_PARTY_NOTICES.md.
//
// Copyright (c) 2026 Martin Seal
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'wavy_arc_path.dart';

class M3XCircularWavyLoadingPainter extends CustomPainter {
  final double rotation; // radians, canvas rotation for this frame
  final double headFraction; // leading edge position, as a fraction of 2π
  final double tailFraction; // trailing edge position, as a fraction of 2π

  final double wavePhase; // 0→1, one wavelength of scroll per cycle
  final double amplitude; // 0→1
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final double trackStrokeWidth;
  final double gapSize;
  final double wavelength;
  final bool isLtr;

  M3XCircularWavyLoadingPainter({
    required this.rotation,
    required this.headFraction,
    required this.tailFraction,
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
    canvas.translate(cx, cy);
    canvas.rotate(rotation);
    canvas.translate(-cx, -cy);

    final double maxStroke = math.max(strokeWidth, trackStrokeWidth);
    final double R = (math.min(size.width, size.height) - maxStroke) / 2;
    final double N = waveCycleCount(radius: R, wavelength: wavelength);
    final double A = amplitude * strokeWidth * 1.5;
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

    final double capWidth = maxStroke / 2.0;
    final double gapRad = (gapSize + capWidth * 2.0) / R;

    final double sweep = (headFraction - tailFraction) * 2 * math.pi;
    final double startAngle = -math.pi / 2 + tailFraction * 2 * math.pi;

    if (sweep > 0) {
      final Path wavePath = buildWaveArcPath(
        cx: cx,
        cy: cy,
        R: R,
        A: A,
        startAngle: startAngle,
        sweepAngle: sweep,
        N: N,
        phase: phase,
      );
      canvas.drawPath(wavePath, activePaint);
    }

    final double trackSweep = 2 * math.pi - sweep - 2 * gapRad;
    if (trackSweep > 0 && trackColor != Colors.transparent) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: R),
        startAngle + sweep + gapRad,
        trackSweep,
        false,
        trackPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant M3XCircularWavyLoadingPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.headFraction != headFraction ||
        oldDelegate.tailFraction != tailFraction ||
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
