# cro/x — Combat Roleplay Options /x

**Current build: cro_x 0.66-beta** · [Download the latest](../../releases/latest) · [Changelog](CHANGELOG.md)

A World of Warcraft: Forever add-on for the Horde. Your character speaks and emotes in combat, in their own voice: shaped by temperament, homeland, upbringing, what drives them, class, spec and professions.

- Lines fire only when they're true for the moment (the facts rule).
- About 2–4 lines a minute solo; cro/x users in a party take turns and answer each other (call and response).
- Blizzard-style window: `/x` to open, `/x flag` to review a fight, `/x export` to share a log.
- Horde only. Alliance characters get one screen: LOK'TAR OGAR.

## Install
Copy the `CROX` folder into `World of Warcraft/_classic_/Interface/AddOns/` (the folder Forever uses), so the path ends `AddOns/CROX/CROX.toc`. Restart the game.

## Repository
- `CROX/` — the add-on. `Lines.lua` and `Abilities.lua` are generated; edit the docs instead.
- `docs/` — design, approved lines, tag pools and the archetype map.
- `tools/` — the line generator (`gen_lines.py`), the test harness (Lua 5.1 with stand-ins for the game's API) and `read_reports.py`, which summarizes pasted bug reports.
- `docs/beta/` — the Discord thread template and the per-build tester checklist.

**Reporting a problem:** in game, type `/x bug`, copy the report, and paste it into the beta Discord or a new issue here.

Status: beta. Credits for every asset and source are in the add-on's Credits section.
