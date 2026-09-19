+++
schema_version = 1
id = "01M2XHZ78S6BS6JZQRX26DX803"
title = "Use a single-column guide with parent navigation and local usage ranking"
date = "2026-09-19"
status = "accepted"
tags = ["docs"]
supersedes = []
superseded_by = []
depends_on = []
related_to = []
+++
Status: implemented under the requested guide refinement.

Niklas requested a tighter developer-style list, shortcut combinations on the right, a Hyper symbol, subtle animation, and Backspace moving up one hierarchy level through arbitrarily nested groups. Use one column with compact rows, native icons/emoji, right-aligned key hints, and **✦** for the four Hyper modifiers. The header shows the shortcut sequence to its group; direct root-group shortcuts appear beside their rows. Backspace and the back button pop one group, with no effect at the root. Preserve the centered position, native appearance, and reduced-motion/transparency behavior from Decision 9.

Niklas also requested statistics on openings in different applications and optional frequency ranking. Store aggregate launcher openings, group views, and action selections locally in Keywink preferences, attributed to the application active at invocation. Do not store window titles, document content, commands, URLs, or a timestamped activity log. Provide tracking and ranking toggles and a reset control in Statistics settings. Tracking starts enabled; ranking starts disabled. These defaults, the Hyper glyph, and ranking details are implementation choices within the requested feature, not separately established personal preferences.

Ranking is per sibling list using source-app counts, with overall counts as a fallback when that app has no history for the list. Preserve configuration order for ties and never reorder the JSON or change assigned keys. Statistics identify items by normalized key paths, so nested keys do not collide and config reloads preserve history. Reassigning an existing path inherits its counts; reset clears that history. A group view means entering or returning to that group; an action selection does not claim the external action succeeded. Automatic config-reload presentations and invalid keys do not count as launcher openings or action selections.

Verification: Debug build and all required mise checks pass (62 native tests, strict formatting, release-script syntax). Tests exercise three nested levels through actual Backspace events, direct root-group switching, isolated statistics persistence/reset, stable app-specific ranking, tracking disabled, source-app context across sessions, and config-refresh exclusion. Native guide renders were inspected in light/dark appearance; the running personal setup showed its Hyper hints, parent navigation, and populated Statistics pane.

Follow-up refinement (2026-09-19): Niklas requested each key before its name and a narrower guide. Move the row key badge to the leading edge and reduce the maximum width from 520 to 440 points; retain global Hyper hints on the right. Niklas also explicitly confirmed that frequency means group opens and action uses per source application.
