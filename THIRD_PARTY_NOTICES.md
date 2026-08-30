# Third-party notices

## package:m3e_progress_indicator

`m3e_progress_indicator` (https://pub.dev/packages/m3e_progress_indicator) requires a
newer Dart/Flutter SDK than this package targets, so rather than depending on it, the
following files were vendored from its source and adapted to compile against a plain
`package:flutter/material.dart` import (the original used a `material_ui` re-export):

- `lib/src/m3x_circular_wavy_progress_indicator.dart`
- `lib/src/m3x_linear_wavy_progress_indicator.dart`
- `lib/src/m3x_progress_indicator_defaults.dart`
- `lib/src/painters/m3x_circular_wavy_progress_painter.dart`
- `lib/src/painters/m3x_linear_wavy_progress_painter.dart`
- `lib/src/painters/wavy_arc_path.dart` (wave-arc geometry factored out of the circular painter above)

These were further simplified to match the Material 3 spec anatomy (an active indicator
covering part of the ring/track with a gap, never a fully wavy ring) and to replace the
original's indeterminate mode with a "loading" mode that fills 0→1 and repeats.

`lib/src/m3x_circular_wavy_loading_indicator.dart` and
`lib/src/painters/m3x_circular_wavy_loading_painter.dart` are original work — a
from-scratch implementation of the vibes-accurate rotating indeterminate motion — that
reuses the wave-arc geometry in `wavy_arc_path.dart` above but does not derive from the
original package's indeterminate implementation.

See LICENSE for the full text of the original package's MIT license.
