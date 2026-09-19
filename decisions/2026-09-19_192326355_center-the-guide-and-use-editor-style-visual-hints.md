+++
schema_version = 1
id = "01M2XHZ78KQFZ8PFR9G2PCP4ZN"
title = "Center the guide and use editor-style visual hints"
date = "2026-09-19"
status = "accepted"
tags = ["docs"]
supersedes = []
superseded_by = []
depends_on = []
related_to = []
+++
Status: accepted direction; implemented as Key Guide. List layout and navigation refined by Decision 10.

Niklas reconsidered the top position in favor of the screen center, where attention already sits, and requested a developer aesthetic inspired by IDE completion lists and Helix. Keep the compact keyboard-guide interaction from Decision 7, but center it in the selected display's usable frame. Use a wide, restrained shape with monospace keys and group context, native material, app icons, SF Symbols, and emoji labels. The visible theme name becomes **Key Guide**; preserve the `topEdge` preference value so existing selections receive the revision.

Use the existing native icon support instead of adding a separate SVG-rendering dependency. Leading emoji labels suppress the extra icon. Dimensions, the theme name, and icon mechanics are implementation choices within the requested direction. Preserve native light/dark appearance and reduced-motion/transparency behavior.

Global group shortcuts resolve from the root even when another group is open. This supports the requested Hyper-plus-group workflow without treating a new group shortcut as a child key. The user's personal Hammerspoon migration belongs in their chezmoi dotfiles, while Keywink keeps its general JSON configuration and preference-backed shortcut schema.

Run shell commands on a serial background queue so long-running actions such as selected-text speech leave the launcher responsive while preserving command order. Capture output in private temporary files to avoid pipe-buffer deadlocks, and present failures on the main thread.

Verification: all 55 tests and required mise checks pass. Native root/group renders were inspected in light and dark appearances, and the running app loaded the migrated five groups and displayed the application group. Geometry coverage checks centered placement on ordinary, narrow, and offset displays; command coverage checks responsiveness, large output, and nonzero exit reporting. The final command-queue refinement also passes its focused regression. Physical use of the migrated shortcuts and custom automation remains a user trial.
