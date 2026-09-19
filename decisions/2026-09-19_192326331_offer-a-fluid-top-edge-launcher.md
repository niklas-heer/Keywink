+++
schema_version = 1
id = "01M2XHZ77V0D5ZVXBN3NMB5BFF"
title = "Offer a fluid top-edge launcher"
date = "2026-09-19"
status = "accepted"
tags = ["shell", "extension"]
supersedes = []
superseded_by = []
depends_on = []
related_to = ["01M2XHZ78113EKNV14B9TNB7AJ"]
+++
Status: implemented direction; the notch-bridge styling is superseded by Decision 6.

Niklas disliked the centered square and proposed a top-oriented, more fluid launcher that follows the system theme and fits newer MacBook camera housings. A screenshot from another shell project served as visual inspiration, not a request to copy that project's functionality.

Implement **Top Edge** as the default for an unset theme preference. Keep existing themes and explicit selections. Use native macOS material, light/dark colors, a curved bridge below a detected notch, and a rounded floating fallback below the menu bar on ordinary displays. Keep shortcut hints within the wide panel; resize for each group and scroll large groups. Respect reduced motion and reduced transparency. The exact layout, name, and default are implementation choices within this requested direction.

Position against the selected display's current visible frame and camera safe-area information, including external monitors with nonzero or negative origins and side Docks. Bound the panel to that usable area. Guard animation completions so dismissing and reopening cannot close a new presentation.

Verification: all 51 tests and strict formatting pass, including geometry cases and native panel presentation/navigation/dismissal, config-replacement invalidation, and rapid dismiss/reopen behavior. Light and dark renders were inspected; the notch silhouette was also rendered with simulated camera geometry. This does not claim an end-to-end check on every physical notch/display configuration.
