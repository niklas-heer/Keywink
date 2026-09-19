+++
schema_version = 1
id = "01M2XHZ78113EKNV14B9TNB7AJ"
title = "Remove the notch connector and outlined edges"
date = "2026-09-19"
status = "accepted"
tags = []
supersedes = []
superseded_by = []
depends_on = []
related_to = []
+++
Status: revised implementation following visual feedback; layout refined by Decision 7.

Niklas rejected the short stem above the larger panel, described the edges as etched, and found the result awkward on both notched and ordinary displays. This supersedes Decision 5's decorative camera bridge.

Use one continuous, softly rounded panel with the same spacing beneath the usable top edge on every display. The notch affects safe placement only; it does not change the silhouette. Remove the custom contour and border stroke, shorten the header/rows, and show row backgrounds only on hover. Keep native system materials, accessibility settings, keyboard navigation, and bounded resizing. The precise revised proportions remain open to visual feedback.
