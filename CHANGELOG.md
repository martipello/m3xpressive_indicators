## 0.1.4

- `M3XLinearWavyProgressIndicator`: added `isFlat` to render a plain straight bar with
  no wave motion (the wave animation is skipped entirely, not just visually flattened),
  for platforms/contexts the wave motion wasn't tuned for. Defaults to `false` —
  non-breaking.
- `M3XLinearWavyProgressIndicator`: bars much shorter than `wavelength` now clamp to the
  nearest whole number of wave cycles (minimum one) instead of rendering a cut-off
  partial wave — fixes a cramped/malformed look at small sizes.

## 0.1.3

- `M3XCircularWavyProgressIndicator`: added `loadingFillDuration` to control how long one
  fill-and-repeat cycle takes in loading mode — previously fixed internally. Defaults to
  the previous fixed value — non-breaking.

## 0.1.2

- `M3XCircularWavyLoadingIndicator`: added `rotationDuration` to control how fast the
  cycloid rotation completes a revolution — previously fixed internally. Defaults to the
  previous fixed value — non-breaking.

## 0.1.1

- `M3XCircularWavyLoadingIndicator`: added `peakWidthMin`/`peakWidthMax` and
  `troughWidthMin`/`troughWidthMax` to control the randomized arc width range (the fixed
  defaults didn't read well at larger sizes), and `peakHoldDuration`/`troughHoldDuration` to
  control how long the arc dwells at each extreme independently (e.g. a longer peak, a
  brief trough). All default to the previous fixed behavior — non-breaking.

## 0.1.0

- Initial release.
- `M3XCircularWavyProgressIndicator` and `M3XLinearWavyProgressIndicator`: determinate wavy
  progress indicators, with a "loading" mode (`value: null`) that fills 0→1 and repeats.
- `M3XCircularWavyLoadingIndicator`: vibes-accurate rotating indeterminate circular wavy
  indicator — head/tail grow-then-collapse motion with randomized peak/trough widths, and a
  cycloid-based rotation that speeds up and slows down without ever reversing direction.
