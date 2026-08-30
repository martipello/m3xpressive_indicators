// Vendored from package:m3e_progress_indicator (https://pub.dev/packages/m3e_progress_indicator)
// because that package requires Dart SDK >=3.12.1 / Flutter >=3.47.0, newer
// than this project's SDK. Ported to plain package:flutter/material.dart.
//
// Simplified per the M3 spec anatomy (https://m3.material.io/components/progress-indicators/specs):
// the active wavy indicator only ever covers part of the ring, with a plain
// track covering the rest. There is no separate "indeterminate" rendering
// mode — when [value] is null this is a "loading" indicator: the active arc
// fills from 0% to 100% and then repeats, reusing the same determinate
// rendering the whole time.
//
// Copyright (c) 2026 Mudit Purohit
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:ui';

import 'package:flutter/material.dart';

import 'm3x_progress_indicator_defaults.dart';
import 'painters/m3x_circular_wavy_progress_painter.dart';

const Duration kM3XCircularWavyLoadingFillDuration =
    Duration(milliseconds: 1600);

/// A Material 3 Expressive circular wavy progress indicator.
///
/// The active arc is drawn as a sinusoidal wave bent around the circle (the
/// radius oscillates in and out as the stroke travels around the ring), with
/// a plain circular track covering the remainder.
///
/// When [value] is `null` this is a "loading" indicator: the active arc
/// fills from empty to a full circle, then repeats.
class M3XCircularWavyProgressIndicator extends StatefulWidget {
  /// The progress value, between 0.0 and 1.0.
  /// If null, the indicator repeatedly fills from empty to full ("loading").
  final double? value;

  /// The color of the active progress indicator.
  final Color? color;

  /// The animation of the active progress indicator color.
  final Animation<Color?>? valueColor;

  /// The background color of the track.
  final Color? backgroundColor;

  /// The stroke width of the active wavy line.
  final double strokeWidth;

  /// The stroke width of the track.
  final double trackStrokeWidth;

  /// The gap size between the active progress and the track (logical pixels).
  final double gapSize;

  /// The preferred wavelength of the wave (logical pixels).
  final double wavelength;

  /// The speed of the wave scrolling (logical pixels per second).
  final double waveSpeed;

  /// The size/diameter of the indicator.
  final double size;

  /// Optional function that returns amplitude (0.0 – 1.0) based on progress.
  /// Defaults to [M3XProgressIndicatorDefaults.indicatorAmplitude].
  final double Function(double)? amplitude;

  const M3XCircularWavyProgressIndicator({
    super.key,
    this.value,
    this.color,
    this.valueColor,
    this.backgroundColor,
    this.strokeWidth = M3XProgressIndicatorDefaults.circularStrokeWidth,
    this.trackStrokeWidth = M3XProgressIndicatorDefaults.circularStrokeWidth,
    this.gapSize = M3XProgressIndicatorDefaults.circularIndicatorTrackGapSize,
    this.wavelength = M3XProgressIndicatorDefaults.circularWavelength,
    this.waveSpeed = M3XProgressIndicatorDefaults.circularWavelength,
    this.size = M3XProgressIndicatorDefaults.circularContainerSize,
    this.amplitude,
  });

  @override
  State<M3XCircularWavyProgressIndicator> createState() =>
      _M3XCircularWavyProgressIndicatorState();
}

class _M3XCircularWavyProgressIndicatorState
    extends State<M3XCircularWavyProgressIndicator>
    with TickerProviderStateMixin {
  /// Wave-phase controller: 0 → 1 in (wavelength / waveSpeed) seconds.
  /// One full cycle = one wavelength of travel on the arc.
  late AnimationController _wavePhaseController;

  /// Amplitude morph: 0 → 1 when the amplitude target changes.
  late AnimationController _amplitudeController;

  /// Smooth progress value transitions (determinate mode).
  late AnimationController _progressController;
  late CurvedAnimation _progressCurve;

  /// Loading mode: repeatedly fills 0 → 1, then resets and repeats.
  late AnimationController _loadingFillController;

  double _targetAmplitude = 1.0;
  double _fromProgress = 0.0;
  double _toProgress = 0.0;

  bool get _isLoading => widget.value == null;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final double waveCycleSec =
        widget.waveSpeed > 0 ? widget.wavelength / widget.waveSpeed : 1.0;
    _wavePhaseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (waveCycleSec * 1000).round()),
    );
    if (widget.waveSpeed > 0) {
      _wavePhaseController.repeat();
    }

    _targetAmplitude = _isLoading
        ? 1.0
        : (widget.amplitude ?? M3XProgressIndicatorDefaults.indicatorAmplitude)(
            widget.value!,
          );
    _amplitudeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: _targetAmplitude,
    );

    _loadingFillController = AnimationController(
      vsync: this,
      duration: kM3XCircularWavyLoadingFillDuration,
    );
    if (_isLoading) {
      _loadingFillController.repeat();
    }

    // Progress value animation (smooth transitions between determinate values)
    _fromProgress = widget.value ?? 0.0;
    _toProgress = widget.value ?? 0.0;
    _progressController = AnimationController(
      vsync: this,
      duration: M3XProgressIndicatorDefaults.progressAnimationDuration,
      value: 1.0, // Start completed — no animation on initial render
    );
    _progressCurve = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(covariant M3XCircularWavyProgressIndicator old) {
    super.didUpdateWidget(old);

    if (widget.waveSpeed != old.waveSpeed ||
        widget.wavelength != old.wavelength) {
      if (widget.waveSpeed > 0) {
        final double waveCycleSec = widget.wavelength / widget.waveSpeed;
        _wavePhaseController.duration = Duration(
          milliseconds: (waveCycleSec * 1000).round(),
        );
        _wavePhaseController.repeat();
      } else {
        _wavePhaseController.stop();
        _wavePhaseController.value = 0.0;
      }
    }

    if (widget.value != old.value) {
      if (widget.value == null) {
        _loadingFillController.repeat();
        _targetAmplitude = 1.0;
        _amplitudeController.animateTo(1.0, curve: Curves.easeOut);
      } else {
        if (old.value == null) {
          _loadingFillController.stop();
          _fromProgress = widget.value!;
          _toProgress = widget.value!;
          _progressController.value = 1.0;
        } else {
          // Animate progress from current interpolated position to new value
          _fromProgress = lerpDouble(
            _fromProgress,
            _toProgress,
            _progressCurve.value,
          )!;
          _toProgress = widget.value!;
          _progressController.forward(from: 0.0);
        }

        final double newTarget = (widget.amplitude ??
            M3XProgressIndicatorDefaults.indicatorAmplitude)(widget.value!);
        if (newTarget != _targetAmplitude) {
          _targetAmplitude = newTarget;
          _amplitudeController.animateTo(
            _targetAmplitude,
            curve: Curves.easeOut,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _wavePhaseController.dispose();
    _amplitudeController.dispose();
    _loadingFillController.dispose();
    _progressCurve.dispose();
    _progressController.dispose();
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
          _amplitudeController,
          _progressController,
          _loadingFillController,
          if (widget.valueColor != null) widget.valueColor!,
        ]),
        builder: (context, child) {
          final activeColor = widget.valueColor?.value ??
              widget.color ??
              M3XProgressIndicatorDefaults.activeColor(context);
          final double progress = _isLoading
              ? _loadingFillController.value
              : lerpDouble(_fromProgress, _toProgress, _progressCurve.value)!;

          return CustomPaint(
            painter: M3XCircularWavyProgressPainter(
              progress: progress,
              wavePhase: _wavePhaseController.value,
              amplitude: _amplitudeController.value,
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
