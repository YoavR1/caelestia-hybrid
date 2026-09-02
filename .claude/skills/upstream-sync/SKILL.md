---
name: upstream-sync
description: >-
  Integrate new work from one of the three upstreams (caelestia-dots/shell, OP-Caelestia, or
  MiDnight) into the hybrid shell. Use when asked to sync, merge, update from, catch up with,
  or pull in upstream changes, when checking how far behind we are, or when resolving conflicts
  from such a merge. Covers the merge-vs-cherry-pick rule, conflict classification, and the
  Phase 2 config-rewrite catch-up specifically.
---

# Syncing an upstream

## Rules that do not bend

1. **One upstream per branch.** `sync/caelestia/YYYY-MM-DD`, `sync/op/YYYY-MM-DD`. Never a
   combined "sync everything" branch — you lose the ability to attribute a regression.
2. **Merge upstream, cherry-pick OP.** `caelestia/main` is a true ancestor, so `git merge` is
   correct. OP shares ancestor `ad8dca0a`, so `git cherry-pick -x <sha>` works directly.
3. **Never rebase our branch onto an upstream.** It rewrites our history and destroys the
   provenance the GPL attribution depends on.
4. **`git rerere` must be on.** `bootstrap.sh` enables it. The same conflicts recur every sync;
   this is the highest-value setting in the project.
5. **Never merge into `main` automatically.** CI may open an issue; a human opens the PR.

## Start here

```bash
./hybrid/tools/upstream-status.sh --areas --commits
```

It reports, per upstream: commits behind, merge-base, incoming diffstat, changed areas, and
flags high-risk paths (`plugin/src/Caelestia/{Config,Settings,Plugins}/`, `modules/drawers/`,
`services/{Audio,Colours,Wallpapers}.qml`).

For anything more than a handful of commits, hand the range to the `upstream-triage` agent to
get a classified table before touching the working tree.

## Classification

Every incoming change lands in one of four buckets:

| | Bucket | Action |
|---|---|---|
| **A** | Clean import — we have not meaningfully modified this area | Take upstream's version. Default outcome; most changes are this. |
| **B** | Adapter update — upstream changed an API our code uses | Take upstream's version, then fix our call sites. Do not fork the API. |
| **C** | Real conflict — we and upstream both changed the same thing substantially | Needs a decision. Usually upstream wins on infrastructure, we win on features. Record why in the merge commit. |
| **D** | Not applicable — does not belong in our tree | Skip, and note it, so the next sync does not re-litigate it. |

Two recurring shapes worth knowing:

- **Additive service conflicts** (T8) look like C but are A. `services/Audio.qml` has OP adding
  stream helpers and MiDnight adding sound effects, in adjacent hunks. Keep both sides.
- **Superseded work** (T7) looks like C but is D-for-us. If upstream implemented natively what a
  fork implemented locally, delete ours and take upstream's — `NetworkUsage.qml` and MiDnight's
  per-monitor config are both this.

## The merge

```bash
git switch -c sync/caelestia/$(date +%F)
git merge caelestia/main            # expect conflicts; rerere replays known ones

# after each resolution
git add <file> && git rerere        # records the resolution for next time
```

Resolve in dependency order: C++ plugin first (it defines the API), then services, then modules,
then Nexus pages. Resolving QML against a stale plugin produces confusing errors.

Then the full gate from `shell-verify` — including `smoke-matrix.sh`, which catches load-order
breakage that lint cannot see.

## Phase 2 specifically: the config rewrite

The first `caelestia` sync is the big one, and it is deliberately Phase 2 rather than deferred
(D7). Upstream shipped, after both fork points:

- `refactor(config): rewrite config module (#1861)` — `ConfigObject`/`RootConfig`/`ConfigList`
  replaced by `settings::ObjectNode`/`RootNode` and the `CONFIG_NODE` macro
- `refactor: rearrange plugin layout (#1896)` — both forks still carry the old layout
  (`Internal/`, `appdb`, `imageanalyser`)
- A new `plugin/src/Caelestia/Settings/` module including `layerregistry.hpp`
- `feat(services): migrate NetworkUsage from QML to C++ (#1860)`
- A mass style sweep — scoped enums, `u""_s`, sorted includes, clang-tidy

Sequencing that works:

1. Take the **style sweep first**, alone, and commit it. It touches almost everything and mixing
   it with semantic changes makes every later conflict unreadable.
2. Take the **plugin layout rearrange** next — pure moves.
3. Take the **config rewrite**, porting our config classes from `ConfigObject` to
   `settings::ObjectNode` (see the `config-property` skill for both shapes).
4. **Delete** MiDnight's `monitorconfigmanager` / `ConfigList` per-monitor config and adopt
   `settings::LayerRegistry` + `ConfigRoot::forScreen()` (T7).
5. **Delete** both forks' `services/NetworkUsage.qml`; take upstream's C++.
6. Only then build presets on top (Phase 3) — that is the whole reason this phase comes first.

## After any sync

- Update affected rows in `hybrid/docs/provenance.md` with the new source commits.
- If upstream changed something our adapter wrapped, prefer deleting the adapter over growing it.
  An adapter larger than the edit it replaced is the wrong trade (CLAUDE.md, rule 6).
- Note anything classified **D** in the PR body so the next sync skips it quickly.
