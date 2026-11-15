#!/usr/bin/env python3
"""Bump the cro/x build number everywhere it appears, so nothing drifts.

Usage: python3 tools/bump_version.py 0.56 "One-line summary of what changed" ["Another line" ...]

Updates CROX/CROX.toc, the VERSION in CROX/Core.lua, the README's "Current build" line, and adds a section to
CHANGELOG.md. Pushing to main then publishes a release named v<version> (see .github/workflows/release.yml).
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def edit(rel, pattern, repl, count=1):
    p = os.path.join(ROOT, rel)
    s = open(p, encoding="utf-8").read()
    new, n = re.subn(pattern, repl, s, count=count)
    if n == 0:
        sys.exit(f"Could not find {pattern!r} in {rel}")
    open(p, "w", encoding="utf-8").write(new)


def main():
    if len(sys.argv) < 3 or not re.fullmatch(r"\d+\.\d+", sys.argv[1]):
        sys.exit(__doc__)
    v, notes = sys.argv[1], sys.argv[2:]
    edit("CROX/CROX.toc", r"(?m)^## Version:.*$", f"## Version: {v}")
    edit("CROX/Core.lua", r'(?m)^local VERSION = "[^"]*"', f'local VERSION = "{v}"')
    edit("README.md", r"\*\*Current build: v[\d.]+ \(alpha 2\)\*\*", f"**Current build: v{v} (alpha 2)**")
    section = f"## v{v} (alpha 2)\n" + "".join(f"- {n}\n" for n in notes) + "\n"
    edit("CHANGELOG.md", r"(?m)^## v", lambda m: section + "## v")
    print(f"Bumped to v{v}. Now commit and push.")


if __name__ == "__main__":
    main()
