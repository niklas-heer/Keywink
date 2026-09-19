# Decisions

## 1. Continue Leader Key as Keywink

Date: 2026-09-19. Status: accepted; repository created, app rebranding pending.

Niklas selected **Keywink** and explicitly requested a fork of the original project under that name. The repository is [niklas-heer/Keywink](https://github.com/niklas-heer/Keywink), a GitHub fork of [mikker/LeaderKey](https://github.com/mikker/LeaderKey). Its initial default-branch baseline is [`16bcb307dcc5309fbc3a00fe398d913e1f7ddc51`](https://github.com/mikker/LeaderKey/commit/16bcb307dcc5309fbc3a00fe398d913e1f7ddc51).

Preserve upstream Git history, contributor attribution, and the existing MIT license. Develop the continuation under a distinct name, consistent with the [upstream maintainer's request](https://github.com/mikker/LeaderKey/issues/323#issuecomment-5152927484). This fork does not transfer control of upstream issues, pull requests, or releases.

The initial setup establishes the repository and its documentation. Application identifiers, configuration migration, signing, update feeds, and release automation still need separate implementation and verification before a Keywink release. The first proposed milestone is documented in the README; no blanket acceptance of the upstream feature backlog is implied.
