+++
schema_version = 1
id = "01M35N7W1V2KG04R7DEKMXZYXP"
title = "Add KDL with an in-house reader and a node-per-item mapping"
date = "2026-09-22"
status = "accepted"
tags = ["config", "formats"]
supersedes = []
superseded_by = []
depends_on = []
related_to = ["01M35MGESV58YBHHFKBZYANAYJ"]
+++
Status: implemented and verified.

## Decision

KDL is the third configuration format next to JSON and TOML. Unlike TOML, it does not reuse the Codable structure: `KDLConfig` maps every item to one node whose name is the action type, whose first argument is the key, whose second argument is the target, and whose `label=` and `icon=` properties are optional. Groups nest their items as children. Reading and writing go through `KDL.swift`, a small reader and writer kept in the app rather than a package dependency.

The import flow accepts any of the three formats, chosen by file extension, and re-encodes into the active format.

## Context

Niklas asked for KDL because he likes the format. Two Swift packages exist: `danini-the-panini/kdl-swift` keeps node names, arguments, and children internal, so a client cannot walk a document, and CuddleKit describes itself as not production ready and requires macOS 14. Keywink's schema needs a narrow subset (strings, numbers, keywords, properties, children, comments, slashdash, raw and multi-line strings, line continuations), which fits in about 350 lines with tests, and owning the writer keeps the emitted file stable and readable.

A node-per-item mapping was chosen over a Codable-style one because it is what makes KDL attractive for this configuration: `application "s" "/Applications/Safari.app"` reads better than a table of fields.

## Consequences

The reader covers the KDL 2 constructs above and ignores type annotations; unsupported syntax fails with a line number. If the format grows beyond the subset, replacing `KDL.swift` with a package is contained to that file. The mapping is lossless for every field the JSON model has. Both other formats keep working; only one active configuration file exists at a time.
