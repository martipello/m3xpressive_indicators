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
