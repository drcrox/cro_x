#!/usr/bin/env python3
"""Bump the cro_x build label everywhere it appears, so nothing drifts.

Two kinds of build:
  Private working build (the default; never published):
      python3 tools/bump_version.py build "What changed" ["Another line" ...]
    0.57-alpha2 -> 0.57-alpha2.1 -> 0.57-alpha2.2 ... Changes only the label in CROX/Core.lua and logs the note in
    docs/WORKLOG.md. Commit on the local `dev` branch and hand the zip over in chat. Do not push.

  Public release (a milestone; this is what Discord and GitHub show):
      python3 tools/bump_version.py release 0.58 "What changed" ["Another line" ...]
    Sets the label to 0.58-alpha2 (the stage carries over; to change it use STAGE=beta in the environment),
    and updates CROX/CROX.toc, the README, CHANGELOG.md and the tester checklist. Then merge dev into main and
    push; the release workflow publishes v0.58-alpha2 (tag v0.58-alpha2, title "cro/x v0.58-alpha2") from CROX.toc (see .github/workflows/release.yml).
"""
import datetime
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def path(rel):
    return os.path.join(ROOT, rel)


def edit(rel, pattern, repl, count=1):
    s = open(path(rel), encoding="utf-8").read()
    new, n = re.subn(pattern, repl, s, count=count)
    if n == 0:
        sys.exit(f"Could not find {pattern!r} in {rel}")
    open(path(rel), "w", encoding="utf-8").write(new)


def current_build():
    s = open(path("CROX/Core.lua"), encoding="utf-8").read()
    m = re.search(r'(?m)^local BUILD = "(\d+\.\d+)-([a-z]+\d*)(?:\.(\d+))?"', s)
    if not m:
        sys.exit("Could not read local BUILD in CROX/Core.lua")
    return m.group(1), m.group(2), int(m.group(3) or 0)


def set_build(label):
    edit("CROX/Core.lua", r'(?m)^local BUILD = "[^"]*"', f'local BUILD = "{label}"')


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ("build", "release"):
        sys.exit(__doc__)
    kind, notes = sys.argv[1], None
    num, stage, n = current_build()
    if kind == "build":
        notes = sys.argv[2:]
        label = f"{num}-{stage}.{n + 1}"
        set_build(label)
        log = path("docs/WORKLOG.md")
        old = open(log, encoding="utf-8").read() if os.path.exists(log) else "# Working builds (private, not published)\n\n"
        head, _, rest = old.partition("\n\n")
        entry = f"## {label} · {datetime.date.today()}\n" + "".join(f"- {x}\n" for x in notes) + "\n"
        open(log, "w", encoding="utf-8").write(head + "\n\n" + entry + rest)
        print(f"Working build {label}. Commit on dev; do not push.")
        return
    if not re.fullmatch(r"\d+\.\d+", sys.argv[2]) or len(sys.argv) < 4:
        sys.exit(__doc__)
    v, notes = sys.argv[2], sys.argv[3:]
    stage = os.environ.get("STAGE", stage)
    label = f"{v}-{stage}"
    edit("CROX/CROX.toc", r"(?m)^## Version:.*$", f"## Version: {label}")
    edit("CROX/Core.lua", r'(?m)^local VERSION = "[^"]*"', f'local VERSION = "{v}"')
    set_build(label)
    edit("README.md", r"\*\*Current build: [^*]*\*\*", f"**Current build: cro_x {label}**")
    section = f"## {label}\n" + "".join(f"- {x}\n" for x in notes) + "\n"
    edit("CHANGELOG.md", r"(?m)^## ", lambda m: section + "## ")
    edit("docs/beta/Tester checklist.md", r"\*\*Build: [^*]*\*\*", f"**Build: {label}**")
    edit("docs/beta/Tester checklist.md", r"should say `[^`]*`", f"should say `cro_x {label} loaded`")
    print(f"Release {label}. Merge dev into main and push to publish.")


if __name__ == "__main__":
    main()
