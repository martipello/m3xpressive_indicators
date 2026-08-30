// Vibes-accurate M3 indeterminate circular wavy indicator, following the
// head/tail model used by the classic Material circular indeterminate
// spinner (CircularIndeterminateAnimatorDelegate in
// material-components-android): the leading (head) edge grows out from the
// trailing (tail) edge to a peak width, then the tail catches up most of the
// way to the head, shrinking the arc back down to a resting (trough) width
// rather than a literal zero-width point. Unlike the reference spec, the
// peak and trough widths here are randomized each phase rather than fixed,
// so consecutive cycles don't look identical.
//
// Continuity across phases is guaranteed by construction, not by an
// algebraic formula: each phase always animates FROM the live head/tail
// value the previous phase actually ended on (captured at the instant the
// new phase starts), TO a freshly chosen target — so however much the
// target varies, there is never a gap between "where the arc was" and
// "where it starts animating from next".
//
// This is a SEPARATE widget from M3XCircularWavyProgressIndicator, which
// instead renders a "loading" fill-and-repeat motion. Both are kept because
// the fill-and-repeat one, while not vibes-accurate, is preferred visually —
// this one exists alongside it for the true M3 spec motion.
//
// This is original work, not derived from package:m3e_progress_indicator
// (https://pub.dev/packages/m3e_progress_indicator) — it only reuses the
// wave-arc geometry in painters/wavy_arc_path.dart, which is ported from that
// package. See THIRD_PARTY_NOTICES.md for details.
//
// Copyright (c) 2026 Martin Seal
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'm3x_progress_indicator_defaults.dart';
import 'painters/m3x_circular_wavy_loading_painter.dart';

// Each "head grows" phase picks a random peak arc width in this range.
const double kM3XCircularWavyLoadingPeakWidthMin = 0.45;
const double kM3XCircularWavyLoadingPeakWidthMax = 0.80;

// Each "tail catches up" phase picks a random resting (trough) arc width in
// this range — the arc never fully collapses to a point.
const double kM3XCircularWavyLoadingTroughWidthMin = 0.10;
const double kM3XCircularWavyLoadingTroughWidthMax = 0.18;

// Duration of a single head-grows or tail-catches-up phase (half of the
// classic spec's ~1333ms full grow-then-collapse cycle).
const Duration kM3XCircularWavyLoadingPhaseDuration =
    Duration(milliseconds: 666);

// How long the arc holds still at the peak/trough width before reversing
// direction, rather than immediately snapping into the next phase.
const Duration kM3XCircularWavyLoadingHoldDuration =
    Duration(milliseconds: 800);

// Rotation follows a cycloid-like motion profile — the path traced by a
// point on the rim of a rolling wheel — rather than a plain linear turn: it
// always advances forward (never reverses), slowing down once per revolution
// before racing through the rest of the turn at above-average speed. This is
// what gives the "pear-shaped wheel" look — a lopsided rotation speed, not a
// back-and-forth pendulum.
//
// A pure cycloid (rotation = θ - sin θ) has a velocity of exactly zero at
// that slow point, which reads as a dead stop rather than a slowdown.
// kM3XCircularWavyLoadingCycloidDepth scales the sine term down (< 1) so the
// velocity dips but never reaches zero — see the depth constant below for the
// exact floor/peak speed math.
//
// θ is driven directly by continuously-elapsed real time (this is the only
// speed knob — seconds per revolution) rather than by a repeating 0→1
// controller: a repeating controller's loop boundary lands on the same phase
// every time, so anything periodic riding on it can compound awkwardly at
// that boundary. Driving θ straight from elapsed time has no loop boundary
// to begin with.
const Duration kM3XCircularWavyLoadingRotationDuration =
    Duration(milliseconds: 2000);

// How deep the cycloid's speed dip goes, as a fraction of the pure cycloid
// (1.0 = touches zero velocity, i.e. looks like a dead stop; 0.0 = perfectly
// even speed, no lopsidedness at all). At 0.6, speed ranges from 40% to 160%
// of the average — a clear slowdown that never looks fully stopped.
const double kM3XCircularWavyLoadingCycloidDepth = 0.6;

// How fast the color scrolls along the squiggle (logical pixels per second).
const double kM3XCircularWavyLoadingWaveSpeed = 5.0;

/// A Material 3 Expressive indeterminate circular wavy progress indicator,
/// matching the spec's rotating motion.
class M3XCircularWavyLoadingIndicator extends StatefulWidget {
  final Color? color;
  final Color? backgroundColor;
  final double strokeWidth;
  final double trackStrokeWidth;
  final double gapSize;
  final double wavelength;
  final double waveSpeed;
  final double size;

  const M3XCircularWavyLoadingIndicator({
    super.key,
    this.color,
    this.backgroundColor,
    this.strokeWidth = M3XProgressIndicatorDefaults.circularStrokeWidth,
    this.trackStrokeWidth = M3XProgressIndicatorDefaults.circularStrokeWidth,
    this.gapSize = M3XProgressIndicatorDefaults.circularIndicatorTrackGapSize,
    this.wavelength = M3XProgressIndicatorDefaults.circularWavelength,
    this.waveSpeed = kM3XCircularWavyLoadingWaveSpeed,
    this.size = M3XProgressIndicatorDefaults.circularContainerSize,
  });

  @override
  State<M3XCircularWavyLoadingIndicator> createState() =>
      _M3XCircularWavyLoadingIndicatorState();
}

class _M3XCircularWavyLoadingIndicatorState
    extends State<M3XCircularWavyLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _wavePhaseController;
  // Ticks continuously purely to trigger AnimatedBuilder rebuilds — its own
  // value isn't used, since rotation is driven from elapsed wall time instead
  // (see kM3XCircularWavyLoadingRotationDuration).
  late AnimationController _rotationHeartbeatController;
  late AnimationController _phaseController;

  late final DateTime _rotationStartTime = DateTime.now();
  final math.Random _random = math.Random();
  Timer? _holdTimer;

  // The head/tail values the previous phase actually committed to — always
  // exactly where the arc currently is, never recomputed from a formula.
  double _headAbs = 0.0;
  double _tailAbs = 0.0;
  bool _headGrowing = true;
  double _phaseFrom = 0.0;
  double _phaseTo = 0.0;

  @override
  void initState() {
    super.initState();

    final double waveCycleSec =
        widget.waveSpeed > 0 ? widget.wavelength / widget.waveSpeed : 1.0;
    _wavePhaseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (waveCycleSec * 1000).round()),
    );
    if (widget.waveSpeed > 0) {
      _wavePhaseController.repeat();
    }

    _rotationHeartbeatController = AnimationController(
        vsync: this, duration: kM3XCircularWavyLoadingRotationDuration);
    _phaseController = AnimationController(
        vsync: this, duration: kM3XCircularWavyLoadingPhaseDuration);

    _rotationHeartbeatController.repeat();
    _startNextPhase();
  }

  void _startNextPhase() {
    if (!mounted) return;

    if (_headGrowing) {
      final double width = kM3XCircularWavyLoadingPeakWidthMin +
          _random.nextDouble() *
              (kM3XCircularWavyLoadingPeakWidthMax -
                  kM3XCircularWavyLoadingPeakWidthMin);
      _phaseFrom = _headAbs;
      _phaseTo = _tailAbs + width;
    } else {
      final double width = kM3XCircularWavyLoadingTroughWidthMin +
          _random.nextDouble() *
              (kM3XCircularWavyLoadingTroughWidthMax -
                  kM3XCircularWavyLoadingTroughWidthMin);
      _phaseFrom = _tailAbs;
      _phaseTo = _headAbs - width;
    }

    _phaseController.forward(from: 0).then((_) {
      if (!mounted) return;
      // Hold at the peak/trough width — the controller stays at 1.0, so
      // animatingValue keeps rendering _phaseTo unchanged during the wait.
      _holdTimer = Timer(kM3XCircularWavyLoadingHoldDuration, () {
        if (!mounted) return;
        if (_headGrowing) {
          _headAbs = _phaseTo;
        } else {
          _tailAbs = _phaseTo;
        }
        _headGrowing = !_headGrowing;
        _startNextPhase();
      });
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _wavePhaseController.dispose();
    _rotationHeartbeatController.dispose();
    _phaseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackColor = widget.backgroundColor ??
        M3XProgressIndicatorDefaults.trackColor(context);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _wavePhaseController,
          _rotationHeartbeatController,
          _phaseController,
        ]),
        builder: (context, child) {
          final activeColor =
              widget.color ?? M3XProgressIndicatorDefaults.activeColor(context);

          final double curvedT =
              Curves.fastOutSlowIn.transform(_phaseController.value);
          final double animatingValue =
              lerpDouble(_phaseFrom, _phaseTo, curvedT)!;
          final double headFraction = _headGrowing ? animatingValue : _headAbs;
          final double tailFraction = _headGrowing ? _tailAbs : animatingValue;

          final double elapsedSeconds =
              DateTime.now().difference(_rotationStartTime).inMicroseconds /
                  1e6;
          final double revolutionsPerSecond =
              1000 / kM3XCircularWavyLoadingRotationDuration.inMilliseconds;
          final double theta =
              elapsedSeconds * 2 * math.pi * revolutionsPerSecond;
          final double rotationRadians =
              theta - kM3XCircularWavyLoadingCycloidDepth * math.sin(theta);

          return CustomPaint(
            painter: M3XCircularWavyLoadingPainter(
              rotation: rotationRadians,
              headFraction: headFraction,
              tailFraction: tailFraction,
              wavePhase: _wavePhaseController.value,
              amplitude: 1.0,
              color: activeColor,
              trackColor: trackColor,
              strokeWidth: widget.strokeWidth,
              trackStrokeWidth: widget.trackStrokeWidth,
              gapSize: widget.gapSize,
              wavelength: widget.wavelength,
              isLtr: Directionality.of(context) == TextDirection.ltr,
            ),
          );
        },
      ),
    );
  }
}
