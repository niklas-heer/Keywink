+++
schema_version = 1
id = "01M2XMMWAKS94HJG79FHT8W2AY"
title = "Rename the Xcode project, targets, and module to Keywink"
date = "2026-09-19"
status = "accepted"
tags = ["naming", "tooling"]
supersedes = []
superseded_by = []
depends_on = []
related_to = ["01M2XHZ77F45K2B89121322H2Z"]
+++
Status: implemented and verified.

Before the first release, Niklas asked to rename everything that still carried the Leader Key name in code and file names: "what's the point if we keep our old stuff there?" This replaces the clause in "Separate Keywink's runtime identity and import explicitly" that kept the inherited Xcode project, targets, scheme, source paths, and `Leader_Key` module. The rest of that record, including the runtime identity, import behaviour, and version sequence, still applies.

Rename the Xcode project, scheme, app target, and test target to `Keywink` and `KeywinkTests`; move the source directories to `Keywink/` and `KeywinkTests/`; rename the entitlements file; and drop the explicit `PRODUCT_MODULE_NAME` so the Swift module defaults to `Keywink`. Tests import `Keywink`, and the storyboard references that module. Update the mise tasks, release scripts, icon generator, and contributor documentation to the new names. Remove the inherited Cursor rule that told agents not to build or run the project, because it contradicts the mise workflow.

Keep the strings that describe the Leader Key import feature, the fork attribution in the README and LICENSE, the upstream Git history, and historical decision records. The `TopEdge`/`topEdge` theme names are a Keywink preference-compatibility choice, not upstream branding, and are unchanged.

Alternatives: keeping the internal names avoided churn but left every build path, scheme, and module carrying the old identity, which the maintainer did not want to publish. A gradual rename would have spread the churn across releases with no benefit.

Consequences: existing local `build/` derived data must be discarded once. Renaming the Swift module does not affect stored data because the app uses Codable JSON and Defaults keys, not archived class names. Verification: all 62 tests, strict lint, and script checks pass on the renamed project. One live-window Key Guide test failed once in a full run and passed on rerun and in isolation, consistent with a focus-timing flake rather than the rename.
