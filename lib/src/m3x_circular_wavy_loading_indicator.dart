// Vibes-accurate M3 indeterminate circular wavy indicator. Four phases repeat
// in a cycle, verified against a real M3 spec reference recording (a) by eye
// against the actual footage and (b) by frame-by-frame angle tracking:
//
//  1. Grow: the head (leading edge) advances forward from the tail to a peak
//     width, while the tail stays put. Rotation runs at its normal steady
//     speed throughout.
//  2. Peak hold: both edges stay put — the arc just rotates in place, at
//     normal speed, for an exact number of full revolutions
//     (peakHoldRevolutions).
//  3. Shrink: the tail advances forward to catch up toward the head — like a
//     worm's tail-end being drawn into a hole, disappearing from the near
//     end while the far end (head) stays exactly where it is — down to a
//     resting trough width rather than a literal zero-width point. Rotation
//     decelerates smoothly through this phase, coming to a stop exactly as
//     the shrink completes.
//  4. Trough hold: both edges stay put again, while rotation re-accelerates
//     from a stop back up to normal speed over troughHoldRevolutions.
//
// Then it grows again. Peak and trough widths are randomized each cycle
// rather than fixed, so consecutive cycles don't look identical.
//
// Continuity across phases is guaranteed by construction, not by an
// algebraic formula: each animated phase always starts FROM the live value
// the previous phase actually left it at, TO a freshly chosen target — so
// however much the target varies, there is never a gap between "where the
// arc was" and "where it starts animating from next". Rotation angle is
// accumulated the same way: each phase's contribution is added to a running
// total when it completes, so the transition between constant-speed and
// ramping phases is always continuous in position (never a jump), even
// though speed itself changes abruptly at phase boundaries.
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

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'm3x_progress_indicator_defaults.dart';
import 'painters/m3x_circular_wavy_loading_painter.dart';
import 'painters/wavy_arc_path.dart' show waveCycleCount;

// Default "grow" phase peak arc width range — see
// M3XCircularWavyLoadingIndicator.peakWidthMin/Max to override per instance.
// Larger circles tend to want a narrower range than the default, since the
// same fraction of the ring spans more pixels.
const double kM3XCircularWavyLoadingPeakWidthMin = 0.45;
const double kM3XCircularWavyLoadingPeakWidthMax = 0.80;

// Default "shrink" phase resting (trough) arc width range — see
// M3XCircularWavyLoadingIndicator.troughWidthMin/Max to override per
// instance. The arc never fully collapses to a point.
const double kM3XCircularWavyLoadingTroughWidthMin = 0.10;
const double kM3XCircularWavyLoadingTroughWidthMax = 0.18;

// Duration of the grow or shrink phase's arc-length animation.
const Duration kM3XCircularWavyLoadingPhaseDuration =
    Duration(milliseconds: 1600);

// How many full revolutions the arc spins in place at the peak width before
// shrinking — see M3XCircularWavyLoadingIndicator.peakHoldRevolutions to
// override. Rotation runs at constant speed during this hold, so this is an
// exact revolution count, not an approximation.
const double kM3XCircularWavyLoadingPeakHoldRevolutions = 1.5;

// How many rotation-periods' worth of time the arc spends at the trough
// width — see M3XCircularWavyLoadingIndicator.troughHoldRevolutions to
// override. Rotation dips partway through this hold (see
// kM3XCircularWavyLoadingTroughHoldDipDepth) rather than ramping the whole
// way through it, so this constant sets the hold's duration, not directly
// its angle. Kept short because the dip itself takes real time to ease into
// and out of — a long hold just means more time spent slow.
const double kM3XCircularWavyLoadingTroughHoldRevolutions = 1.0;

// How deep the trough hold's rotation dip goes, as a fraction of normal
// speed (1.0 = touches zero, i.e. a literal stop; 0.0 = no dip at all,
// constant speed throughout). A literal stop measurably reads as a pause —
// even placed at the hold's midpoint, safely away from the shrink boundary,
// it still held near-zero speed for ~500ms — so this stops short of zero:
// speed dips to (1 - depth) of normal, slow enough to read as "settling" but
// never fully stopping, the same principle already used for the rotation's
// original per-revolution wobble.
const double kM3XCircularWavyLoadingTroughHoldDipDepth = 0.7;

// Seconds per revolution at normal (unramped) speed — see
// M3XCircularWavyLoadingIndicator.rotationDuration to override per instance.
const Duration kM3XCircularWavyLoadingRotationDuration =
    Duration(milliseconds: 2000);

// How fast the color scrolls along the squiggle (logical pixels per second).
// At the default wavelength (20), 5.0 took a full 4 seconds to scroll one
// wavelength — slow enough that, combined with the arc-length pulse's own
// motion, the squiggle reads as having stopped rather than merely scrolling
// slowly. 20.0 matches M3XCircularWavyProgressIndicator's wave speed, which
// scrolls a full wavelength every ~1s — clearly, unambiguously moving.
const double kM3XCircularWavyLoadingWaveSpeed = 20.0;

// Below this size the wave flattens to a plain smooth arc, ramping up to
// full amplitude by kM3XCircularWavyFullSize. Matches the M3 spec's own size
// reference, where the two smallest circular sizes (40dp, 44dp) render with
// no wave at all — only 48dp and up show the wavy variant, all at the same
// fixed wavelength. A small ring keeping the same wavelength as a large one
// crams in too many cycles for its circumference (a tight starburst/gear
// look), so rather than shrinking the wavelength too (which just trades that
// problem for showing almost no wave at all — visible wave count is capped
// by how much of the ring the arc actually sweeps, not the full
// circumference), small rings drop the wave entirely instead.
const double kM3XCircularWavyMinSize = 44.0;
const double kM3XCircularWavyFullSize = 48.0;

// Minimum number of wave cycles a [forceWavy] ring is guaranteed to show,
// regardless of size. At the plain fixed wavelength, a small ring's shorter
// circumference naturally fits fewer cycles — a 32dp ring only manages 4,
// which barely reads as "wavy" rather than just a slightly bumpy circle,
// undermining the entire point of forcing the wave on in the first place.
// Only ever lowers the effective wavelength (raising the wave count), never
// raises it — larger rings already clear this minimum on their own.
const double kM3XCircularWavyForceWavyMinWaveCount = 7.0;

enum _PulsePhase { grow, peakHold, shrink, troughHold }

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

  /// Skips the below-[kM3XCircularWavyMinSize] amplitude taper and always
  /// renders at full wave amplitude, regardless of [size]. The taper matches
  /// the M3 spec's own size reference, but callers who want a small
  /// indicator that still reads as wavy — a brand choice, not a spec one —
  /// can opt out with this instead of fighting the default.
  final bool forceWavy;

  /// Range the active arc's peak width is randomly picked from, as a
  /// fraction of the full ring (0.0–1.0).
  final double peakWidthMin;
  final double peakWidthMax;

  /// Range the active arc's resting (trough) width is randomly picked from,
  /// as a fraction of the full ring (0.0–1.0). Never reaches 0 — the arc
  /// doesn't fully collapse to a point.
  final double troughWidthMin;
  final double troughWidthMax;

  /// How many full revolutions the arc spins in place at the peak width
  /// before shrinking. Rotation is at constant speed during this hold, so
  /// this is an exact count.
  final double peakHoldRevolutions;

  /// How many rotation-periods' worth of time the arc spends at the trough
  /// width before growing again, while rotation re-accelerates from a stop.
  final double troughHoldRevolutions;

  /// Seconds per revolution at normal (unramped) speed.
  final Duration rotationDuration;

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
    this.forceWavy = false,
    this.peakWidthMin = kM3XCircularWavyLoadingPeakWidthMin,
    this.peakWidthMax = kM3XCircularWavyLoadingPeakWidthMax,
    this.troughWidthMin = kM3XCircularWavyLoadingTroughWidthMin,
    this.troughWidthMax = kM3XCircularWavyLoadingTroughWidthMax,
    this.peakHoldRevolutions = kM3XCircularWavyLoadingPeakHoldRevolutions,
    this.troughHoldRevolutions = kM3XCircularWavyLoadingTroughHoldRevolutions,
    this.rotationDuration = kM3XCircularWavyLoadingRotationDuration,
  });

  @override
  State<M3XCircularWavyLoadingIndicator> createState() =>
      _M3XCircularWavyLoadingIndicatorState();
}

class _M3XCircularWavyLoadingIndicatorState
    extends State<M3XCircularWavyLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _wavePhaseController;

  // Drives the grow/shrink arc-length animation (duration =
  // kM3XCircularWavyLoadingPhaseDuration) and, during those same two phases,
  // also the rotation-speed ramp (constant during grow, linear decel during
  // shrink) — its 0..1 value is `t` for both.
  late AnimationController _phaseController;

  // Drives the peak/trough holds — duration is set dynamically per phase
  // (peakHoldRevolutions or troughHoldRevolutions worth of rotationDuration)
  // right before each hold starts. Its 0..1 value is `t` for the
  // rotation-speed ramp during those two phases (constant during peak hold,
  // linear accel during trough hold).
  late AnimationController _holdController;

  final math.Random _random = math.Random();

  _PulsePhase _pulsePhase = _PulsePhase.grow;

  // Total rotation angle (radians) accumulated by every phase that has
  // already fully completed — the current phase's own in-progress
  // contribution is added to this at render time, never mutated mid-phase.
  double _rotationAngleAtPhaseStart = 0.0;

  // The head/tail values the previous grow/shrink phase actually committed
  // to — always exactly where the arc currently is, never recomputed from a
  // formula.
  double _headAbs = 0.0;
  double _tailAbs = 0.0;
  double _phaseFrom = 0.0;
  double _phaseTo = 0.0;

  double get _omega0 =>
      2 * math.pi / (widget.rotationDuration.inMicroseconds / 1e6);

  @override
  void initState() {
    super.initState();

    final double waveCycleSec =
        widget.waveSpeed > 0 ? widget.wavelength / widget.waveSpeed : 1.0;
    _wavePhaseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (waveCycleSec * 1000).round()),
    );
    // A phase transition is driven by the controller's AnimationStatus,
    // not by chaining .then() on the Future .forward() returns — that
    // Future resolves via a microtask one frame later than the status
    // change itself, so every single phase boundary would otherwise render
    // one extra frame with the old phase frozen at its final value before
    // the new phase's first frame snaps in — a stutter that reads as a
    // little "roll back" right before the arc starts growing again.
    void onStatusChanged(AnimationStatus status) {
      if (status == AnimationStatus.completed) _completePhase();
    }

    _phaseController = AnimationController(
        vsync: this, duration: kM3XCircularWavyLoadingPhaseDuration)
      ..addStatusListener(onStatusChanged);
    _holdController = AnimationController(vsync: this, duration: Duration.zero)
      ..addStatusListener(onStatusChanged);

    // The first phase (grow) starts the wave scroll itself via
    // _resumeWaveScroll — see _startNextPhase.
    _startNextPhase();
  }

  Duration _scaledDuration(Duration base, double factor) {
    return Duration(microseconds: (base.inMicroseconds * factor).round());
  }

  // ∫[0,t] midBump(s) ds, where midBump(t) = 4·S·(1-S) and
  // S(t) = 3t²-2t³ (smoothstep) — midBump is 0 at t=0 and t=1, peaks at 1
  // at t=0.5, with zero slope at both ends (the simplest symmetric shape
  // with all of those properties at once). Expanded out algebraically so
  // it's a plain polynomial to evaluate, rather than needing midBump itself.
  static double _midBumpIntegral(double t) {
    final double t2 = t * t, t3 = t2 * t, t4 = t3 * t, t5 = t4 * t;
    final double t6 = t5 * t, t7 = t6 * t;
    return 4 * t3 - 2 * t4 - 7.2 * t5 + 8 * t6 - (16 / 7) * t7;
  }

  // Angle (radians) covered by [phase] once it has run for fraction [t]
  // (0..1) of its own duration — a closed form of the phase's velocity
  // profile integrated over time, not a per-frame numerical integration.
  //
  // The slow point lives entirely inside the trough hold, at its midpoint —
  // not at the boundary between shrink and the trough hold. The arc visually
  // finishing its shrink (tail meeting head) at the exact same instant
  // rotation crawls to its slowest reads as one combined "everything
  // stopped" illusion, even when neither one, alone, is a real discontinuity.
  // So shrink keeps constant velocity all the way through (matching peak
  // hold exactly, no ramp at all), and the trough hold's velocity is
  // ω₀·(1 - depth·_midBump(t)): full speed at both t=0 (matching shrink) and
  // t=1 (matching grow), dipping to (1-depth) of normal speed at t=0.5, well
  // after the arc has already settled at its minimum size.
  double _angleGainedInPhase(_PulsePhase phase, double t) {
    switch (phase) {
      case _PulsePhase.grow:
        final double seconds =
            kM3XCircularWavyLoadingPhaseDuration.inMicroseconds / 1e6;
        return _omega0 * t * seconds; // constant velocity
      case _PulsePhase.peakHold:
        final double seconds = _holdController.duration!.inMicroseconds / 1e6;
        return _omega0 * t * seconds; // constant velocity
      case _PulsePhase.shrink:
        final double seconds =
            kM3XCircularWavyLoadingPhaseDuration.inMicroseconds / 1e6;
        return _omega0 * t * seconds; // constant velocity — no dip here
      case _PulsePhase.troughHold:
        final double seconds = _holdController.duration!.inMicroseconds / 1e6;
        return _omega0 *
            seconds *
            (t -
                kM3XCircularWavyLoadingTroughHoldDipDepth *
                    _midBumpIntegral(t));
    }
  }

  void _startNextPhase() {
    if (!mounted) return;

    switch (_pulsePhase) {
      case _PulsePhase.grow:
        _resumeWaveScroll();
        final double width = widget.peakWidthMin +
            _random.nextDouble() *
                (widget.peakWidthMax - widget.peakWidthMin);
        _phaseFrom = _headAbs;
        _phaseTo = _tailAbs + width;
        _phaseController.forward(from: 0);
        break;
      case _PulsePhase.peakHold:
        _pauseWaveScrollAtZeroCrossing();
        _holdController.duration = _scaledDuration(
            widget.rotationDuration, widget.peakHoldRevolutions);
        _holdController.forward(from: 0);
        break;
      case _PulsePhase.shrink:
        _resumeWaveScroll();
        final double width = widget.troughWidthMin +
            _random.nextDouble() *
                (widget.troughWidthMax - widget.troughWidthMin);
        _phaseFrom = _tailAbs;
        _phaseTo = _headAbs - width;
        _phaseController.forward(from: 0);
        break;
      case _PulsePhase.troughHold:
        _pauseWaveScrollAtZeroCrossing();
        _holdController.duration = _scaledDuration(
            widget.rotationDuration, widget.troughHoldRevolutions);
        _holdController.forward(from: 0);
        break;
    }
  }

  // The wave squiggle only scrolls while the arc's length is actively
  // changing (grow/shrink) — it holds still during the peak/trough holds,
  // matching the real M3 spec reference, where the ripple visibly pauses
  // whenever the arc itself isn't currently growing or shrinking.
  void _resumeWaveScroll() {
    if (widget.waveSpeed > 0) {
      _wavePhaseController.repeat();
    }
  }

  double get _radius {
    final double maxStroke = math.max(widget.strokeWidth, widget.trackStrokeWidth);
    return (widget.size - maxStroke) / 2;
  }

  // widget.wavelength, unless forceWavy is set and the plain wavelength
  // would fit fewer than kM3XCircularWavyForceWavyMinWaveCount cycles around
  // this ring — only ever lowers the wavelength (raising the wave count),
  // never raises it.
  double get _effectiveWavelength {
    if (!widget.forceWavy) return widget.wavelength;
    final double capForMinCount =
        2 * math.pi * _radius / kM3XCircularWavyForceWavyMinWaveCount;
    return math.min(widget.wavelength, capForMinCount);
  }

  // Number of wave cycles around the full ring at the current size — the
  // same formula the painter itself uses, duplicated here since choosing a
  // pause point needs to know it too.
  double get _waveCycleCountForCurrentSize {
    return waveCycleCount(radius: _radius, wavelength: _effectiveWavelength);
  }

  // The next wavePhase value (>= the current one, so it's always reached by
  // continuing to scroll forward, never jumping backward) at which the wave
  // crosses zero at the tail's angle — i.e. exactly half way between a peak
  // and a trough, rather than sitting at one of the extremes when it freezes.
  double _nextZeroCrossingWavePhase() {
    final double n = _waveCycleCountForCurrentSize;
    final double tailAngle = -math.pi / 2 + _tailAbs * 2 * math.pi;
    // Solve tailAngle*n + phase*2π = k·π for the smallest phase >= current,
    // stepping in halves of a cycle (zero-crossings occur twice per cycle).
    final double base = -(tailAngle * n) / (2 * math.pi);
    final double current = _wavePhaseController.value;
    final double stepsNeeded = ((current - base) / 0.5).ceilToDouble();
    return base + 0.5 * stepsNeeded;
  }

  // Keeps the wave scrolling forward, at its normal speed, until it reaches
  // the next zero-crossing (see _nextZeroCrossingWavePhase), then stops —
  // rather than freezing wherever the continuous scroll happened to be at
  // the instant the hold began, which could just as easily be at a peak.
  void _pauseWaveScrollAtZeroCrossing() {
    if (widget.waveSpeed <= 0) {
      _wavePhaseController.stop();
      return;
    }

    final double current = _wavePhaseController.value;
    final double target = _nextZeroCrossingWavePhase();
    final Duration cycleDuration = _wavePhaseController.duration!;
    final Duration settleDuration = Duration(
      microseconds:
          ((target - current) * cycleDuration.inMicroseconds).round(),
    );

    _wavePhaseController
        .animateTo(target, duration: settleDuration, curve: Curves.linear)
        .then((_) {
      if (!mounted) return;
      // Fold back into the controller's normal [0, 1) range — subtracting a
      // whole number of cycles from the phase doesn't change the rendered
      // pattern, since sin is periodic — so _resumeWaveScroll's repeat()
      // starts from a value it can loop from cleanly next time.
      _wavePhaseController.value = _wavePhaseController.value % 1.0;
      _wavePhaseController.stop();
    });
  }

  void _completePhase() {
    if (!mounted) return;

    _rotationAngleAtPhaseStart += _angleGainedInPhase(_pulsePhase, 1.0);

    switch (_pulsePhase) {
      case _PulsePhase.grow:
        _headAbs = _phaseTo;
        _pulsePhase = _PulsePhase.peakHold;
        break;
      case _PulsePhase.peakHold:
        _pulsePhase = _PulsePhase.shrink;
        break;
      case _PulsePhase.shrink:
        _tailAbs = _phaseTo;
        _pulsePhase = _PulsePhase.troughHold;
        break;
      case _PulsePhase.troughHold:
        _pulsePhase = _PulsePhase.grow;
        break;
    }

    _startNextPhase();
  }

  @override
  void dispose() {
    _wavePhaseController.dispose();
    _phaseController.dispose();
    _holdController.dispose();
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
          _phaseController,
          _holdController,
        ]),
        builder: (context, child) {
          final activeColor =
              widget.color ?? M3XProgressIndicatorDefaults.activeColor(context);

          final bool isHold = _pulsePhase == _PulsePhase.peakHold ||
              _pulsePhase == _PulsePhase.troughHold;
          final double t =
              isHold ? _holdController.value : _phaseController.value;

          double headFraction;
          double tailFraction;
          switch (_pulsePhase) {
            case _PulsePhase.grow:
              headFraction = lerpDouble(_phaseFrom, _phaseTo, t)!;
              tailFraction = _tailAbs;
              break;
            case _PulsePhase.peakHold:
              headFraction = _headAbs;
              tailFraction = _tailAbs;
              break;
            case _PulsePhase.shrink:
              headFraction = _headAbs;
              tailFraction = lerpDouble(_phaseFrom, _phaseTo, t)!;
              break;
            case _PulsePhase.troughHold:
              headFraction = _headAbs;
              tailFraction = _tailAbs;
              break;
          }

          final double rotationRadians =
              _rotationAngleAtPhaseStart + _angleGainedInPhase(_pulsePhase, t);

          final double sizeAmplitude = widget.forceWavy
              ? 1.0
              : ((widget.size - kM3XCircularWavyMinSize) /
                      (kM3XCircularWavyFullSize - kM3XCircularWavyMinSize))
                  .clamp(0.0, 1.0);

          return CustomPaint(
            painter: M3XCircularWavyLoadingPainter(
              rotation: rotationRadians,
              headFraction: headFraction,
              tailFraction: tailFraction,
              wavePhase: _wavePhaseController.value,
              amplitude: sizeAmplitude,
              color: activeColor,
              trackColor: trackColor,
              strokeWidth: widget.strokeWidth,
              trackStrokeWidth: widget.trackStrokeWidth,
              gapSize: widget.gapSize,
              wavelength: _effectiveWavelength,
              isLtr: Directionality.of(context) == TextDirection.ltr,
            ),
          );
        },
      ),
    );
  }
}
