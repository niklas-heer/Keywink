+++
schema_version = 1
id = "01M2XHZ787SVF7M984G7CC7SBX"
title = "Make the launcher a compact keyboard guide"
date = "2026-09-19"
status = "accepted"
tags = ["docs", "shell"]
supersedes = []
superseded_by = []
depends_on = []
related_to = ["01M2XHZ78KQFZ8PFR9G2PCP4ZN"]
+++
Status: accepted and implemented; position and visual treatment superseded by Decision 9.

Niklas explicitly accepted the proposed keyboard-guide design and interactive concept with “Okay sounds good then. Let's implement that.” This settles the direction left open in Decision 6: prioritize keys and labels in two columns, remove the permanent app title/logo, close button, and instruction footer, and show a small breadcrumb only within groups. Keep native system material, a soft shadow, modest corners, and a safe gap below the menu bar and camera. Maintain the same width and top position while navigating, with brief transitions that respect reduced motion.

The implementation caps width at 536 points, falls back to one column on narrow screens, and lets height follow the current group up to six visible rows before scrolling. The breadcrumb names the navigation path and offers **All shortcuts**; Backspace retains its existing root-reset behavior, and Escape dismisses. Configuration reload feedback remains a temporary message. Exact dimensions and row limits are implementation choices within the accepted direction. Keep the existing themes and explicit user selections.

Verification: the Debug build and required mise checks pass (51 native tests, strict formatting, and release-script syntax). Native root/group renders were inspected in light and dark appearances. The panel test verifies stable width/top position, keyboard group entry and Backspace reset, configuration replacement, dismissal, and rapid reopening; geometry tests cover notch clearance and external-display coordinates.
