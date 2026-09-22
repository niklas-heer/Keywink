+++
schema_version = 1
id = "01M35MGESV58YBHHFKBZYANAYJ"
title = "Offer TOML as an equal configuration format next to JSON"
date = "2026-09-22"
status = "accepted"
tags = ["config", "dependencies"]
supersedes = []
superseded_by = []
depends_on = []
related_to = []
+++
Status: implemented and verified.

## Decision

Keywink keeps JSON as its default configuration format and adds TOML as an equal alternative. The format is decided by which file exists in the configuration directory: `config.toml` wins, otherwise `config.json`. Both files encode the same `Group` model through Codable, so every field, key name, and validation rule is identical; TOML only changes the syntax and allows comments. Settings → Advanced offers a Format picker that converts the current configuration, moves the previous file aside as a `.backup-<uuid>` copy, and switches Keywink to the new file. Leader Key imports still read JSON and are re-encoded when the destination is TOML.

Encoding and decoding use the TOMLKit package (a Swift wrapper around toml++), pinned to the 0.6 series.

## Context

Upstream Leader Key issue #68 and PR #303 ask for a more readable hand-edited format. The upstream PR designs a compact schema where `t = "Ghostty"` implies an application and infers types from values. That form is shorter but lossy: labels, icons, and the difference between a folder and a command need extra rules, and the Leader Key importer, the validator, and the editor would need a second model. Keeping one model and letting the format be a serialization choice avoids that split and keeps JSON round-trips byte-stable for imports.

Alternatives considered: YAML (no maintained Swift parser without Ruby-style pitfalls, and less common for app configs), replacing JSON entirely (would break every existing installation and the Leader Key importer), and a hand-written TOML emitter (toml++ already handles escaping, arrays of tables, and error positions).

## Consequences

TOMLKit adds a C++ dependency to the build; it compiles with the Xcode toolchain and needs no extra tooling. toml++ serializes keys in sorted order and prefers single-quoted literal strings, so a converted file looks different from a hand-written one until the user edits it. Two configuration files may coexist only as an active file plus a backup. A future compact TOML dialect could be added as a third `ConfigFormat` without touching the model.
