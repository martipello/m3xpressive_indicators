## 0.1.5

- `M3XCircularWavyLoadingIndicator`: reworked the indeterminate pulse into an explicit
  cycle — grow, hold at peak, shrink, hold at trough, repeat — with rotation speed tied
  to that cycle instead of running on its own independent clock:
  - Grows and shrinks at constant rotation speed.
  - Holds at the peak width for an exact number of full revolutions
    (`peakHoldRevolutions`, default 1.5) before shrinking.
  - Shrinks by the tail catching up to a fixed head, down to a resting trough width.
  - Holds at the trough width while rotation briefly dips partway through the hold
    (never to a full stop) before easing back to normal speed and growing again.
  - `peakHoldDuration`/`troughHoldDuration` (`Duration`) are replaced by
    `peakHoldRevolutions`/`troughHoldRevolutions` (`double`), since the holds are now
    specified in rotation-periods rather than wall-clock time.
  - The wave squiggle now pauses while the arc is holding at the peak or trough,
    resuming only once the arc starts growing or shrinking again.
  - Added `forceWavy` to render a small ring with full wave amplitude instead of the
    below-44dp taper that otherwise flattens it to a plain arc — a deliberate brand
    choice for callers who want a small indicator that still reads as wavy. Small
    `forceWavy` rings are also guaranteed at least 7 visible wave cycles, regardless of
    size — the default wavelength alone would otherwise fit as few as 4 on a 32dp ring.

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
