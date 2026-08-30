// Shared geometry for M3 Expressive wavy circular indicators — used by both
// M3XCircularWavyProgressPainter (fill/determinate) and
// M3XCircularWavyLoadingPainter (vibes-accurate rotating indeterminate).
//
// Ported from package:m3e_progress_indicator (https://pub.dev/packages/m3e_progress_indicator).
//
// Copyright (c) 2026 Mudit Purohit
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Traces an arc from [startAngle] to [startAngle + sweepAngle] (radians,
/// clockwise) where the radius oscillates sinusoidally:
///
///   r(θ) = R + A * sin(θ * N + phase)
///
/// where [N] = number of complete wave cycles around the full circle,
/// [A] = amplitude in pixels, and [phase] = scroll offset in radians.
///
/// The path is built using quadratic bezier segments, each spanning one
/// half-wavelength. When [taper] is true, amplitude is dampened to zero near
/// the arc's two endpoints so it blends smoothly into a plain track — set it
/// to false only for a true closed loop (a full 2π sweep), where there are no
/// endpoints to blend.
Path buildWaveArcPath({
  required double cx,
  required double cy,
  required double R,
  required double A,
  required double startAngle,
  required double sweepAngle,
  required double N,
  required double phase,
  bool taper = true,
}) {
  final Path path = Path();
  if (sweepAngle <= 0) return path;

  final double halfWaveAngle = math.pi / N;
  final double endAngle = startAngle + sweepAngle;
  final double taperRange = taper ? halfWaveAngle * 0.5 : 0.0;

  double localA(double angle) {
    if (taperRange <= 0) return A;
    final double distFromStart = angle - startAngle;
    final double distFromEnd = endAngle - angle;

    double factor = 1.0;
    if (distFromStart < taperRange) {
      factor = math.min(factor, distFromStart / taperRange);
    }
    if (distFromEnd < taperRange) {
      factor = math.min(factor, distFromEnd / taperRange);
    }

    final double smoothFactor = 0.5 - 0.5 * math.cos(factor * math.pi);
    return A * smoothFactor;
  }

  double currentAngle = startAngle;
  final double r0 =
      R + localA(currentAngle) * math.sin(currentAngle * N + phase);
  path.moveTo(
      cx + r0 * math.cos(currentAngle), cy + r0 * math.sin(currentAngle));

  double segEnd = _nextHalfWaveBoundary(startAngle, halfWaveAngle, phase, N);

  while (currentAngle < endAngle) {
    final double segEndClamped = math.min(segEnd, endAngle);
    final double midAngle = (currentAngle + segEndClamped) / 2;
    final double actualSpan = segEndClamped - currentAngle;
    final double segmentCos = math.cos(actualSpan / 2);

    // Control radius = peak/trough at midAngle, adjusted by segmentCos to draw
    // a smooth circle when amplitude is 0.
    final double rMid =
        (R / segmentCos) + localA(midAngle) * math.sin(midAngle * N + phase);
    final double rEnd =
        R + localA(segEndClamped) * math.sin(segEndClamped * N + phase);

    final double cpx = cx + rMid * math.cos(midAngle);
    final double cpy = cy + rMid * math.sin(midAngle);
    final double epx = cx + rEnd * math.cos(segEndClamped);
    final double epy = cy + rEnd * math.sin(segEndClamped);

    path.quadraticBezierTo(cpx, cpy, epx, epy);

    currentAngle = segEndClamped;
    segEnd += halfWaveAngle;
  }

  return path;
}

/// Returns the angle of the first half-wave boundary AFTER [startAngle].
/// Half-wave boundaries are where the sinusoid crosses zero (sin=0),
/// i.e. θ * N + phase = k * π → θ = (k*π - phase) / N.
double _nextHalfWaveBoundary(
  double startAngle,
  double halfWaveAngle,
  double phase,
  double N,
) {
  final double k = ((startAngle * N + phase) / math.pi).ceil().toDouble();
  final double boundary = (k * math.pi - phase) / N;
  if ((boundary - startAngle).abs() < 1e-9) {
    return boundary + halfWaveAngle;
  }
  return boundary;
}

/// Number of full wave cycles around the full circle so the wave fits
/// perfectly: round(2πR / wavelength), minimum 3.
double waveCycleCount({required double radius, required double wavelength}) {
  return math.max(3.0, (2 * math.pi * radius / wavelength).roundToDouble());
}
