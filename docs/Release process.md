# Release process

**Public label:** `cro_x v.57a2` = build 57, alpha 2. This is what GitHub, Discord and testers see.
**Private working builds:** `v.57a2.1`, `v.57a2.2`, ... Delivered as a zip in the working chat. Never pushed.

## Day to day (private)
1. Work on the local `dev` branch.
2. `python3 tools/bump_version.py build "what changed"` (label goes up by one, note goes in docs/WORKLOG.md).
3. Run the tests, commit on `dev`, send the zip in chat. Nothing reaches GitHub or Discord.

## Milestone (public)
1. `python3 tools/bump_version.py release 0.58 "what changed" ...` (label becomes `v.58a2`; updates CROX.toc, README, CHANGELOG).
2. Commit, then `git checkout main && git merge dev && git push`.
3. The release workflow publishes it; the daily Discord workflow announces it.
