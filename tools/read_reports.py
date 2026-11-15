#!/usr/bin/env python3
"""Turn pasted cro/x bug reports (and /x export text) into one audit summary.

Usage:  python3 tools/read_reports.py reports.txt        (many reports pasted into one file)
        python3 tools/read_reports.py - < reports.txt

Reports start with 'cro/x bug report'. Exports start with 'cro/x export'. The summary shows counts by version,
what was reported, errors grouped together, the reasons presses stayed quiet, and every flagged or awkward moment.
"""
import re
import sys
from collections import Counter, defaultdict


def split_reports(text):
    parts = re.split(r"(?m)^(?=cro/x (?:bug report|export))", text)
    return [p.strip() for p in parts if p.strip().startswith("cro/x")]


def parse_bug(p):
    r = {"kind": "bug", "raw": p}
    m = re.search(r"cro/x bug report · (v\.?[\w.]+) · game ([\d.]+) \((\w+)\)", p)
    r["version"] = m.group(1) if m else "?"
    r["game"] = f"{m.group(2)} ({m.group(3)})" if m else "?"
    m = re.search(r"(?m)^what: (.+)$", p)
    r["what"] = m.group(1).strip() if m else "?"
    m = re.search(r"(?m)^note: (.+)$", p)
    r["note"] = m.group(1).strip() if m else ""
    m = re.search(r"(?m)^character: (.+)$", p)
    r["character"] = m.group(1).strip() if m else "?"
    m = re.search(r"(?m)^hook: (\S+)", p)
    r["hook"] = m.group(1) if m else "?"
    m = re.search(r"(?m)^last error(?: \(x(\d+)\))?: (.+)$", p)
    r["error"] = re.sub(r"\d+", "N", m.group(2)).strip() if m else ""
    m = re.search(r"(?m)^recent quiet: (.+)$", p)
    r["quiet"] = [q.split(": ", 1)[-1].strip() for q in m.group(1).split(" | ")] if m else []
    fight = p.split("last fight", 1)
    r["fight"] = [l.strip() for l in fight[1].splitlines()[1:] if l.strip()] if len(fight) > 1 else []
    return r


def parse_export(p):
    r = {"kind": "export", "raw": p}
    m = re.search(r"cro/x export · (v\.?[\w.]+)", p)
    r["version"] = m.group(1) if m else "?"
    m = re.search(r"(?m)^character: (.+)$", p)
    r["character"] = m.group(1).strip() if m else "?"
    r["flags"] = re.findall(r"(?m)^\s+(\d+:\d+ .+?) \| FLAG: (.+)$", p)
    r["quiet"] = [m.group(1).strip() for m in re.finditer(r"(?m)^\s+\d+:\d+ quiet \| [^|]*\| [^|]*\| (.+)$", p)]
    return r


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "-"
    text = sys.stdin.read() if src == "-" else open(src, encoding="utf-8").read()
    reports = [parse_bug(p) if p.startswith("cro/x bug report") else parse_export(p) for p in split_reports(text)]
    if not reports:
        print("No cro/x reports found. Each should start with 'cro/x bug report' or 'cro/x export'.")
        return
    bugs = [r for r in reports if r["kind"] == "bug"]
    exports = [r for r in reports if r["kind"] == "export"]
    print(f"cro/x report summary: {len(bugs)} bug report(s), {len(exports)} export(s)\n")

    print("Versions:", ", ".join(f"v{v} x{n}" for v, n in Counter(r["version"] for r in reports).most_common()))
    if bugs:
        print("Game builds:", ", ".join(f"{v} x{n}" for v, n in Counter(r["game"] for r in bugs).most_common()))
        print("\nWhat was reported:")
        for k, n in Counter(r["what"] for r in bugs).most_common():
            print(f"  {n} x {k}")
        broken = [r for r in bugs if r["hook"] not in ("ok", "?")]
        if broken:
            print(f"\n!! {len(broken)} report(s) say the button hook is NOT WORKING (nothing can speak).")

        errs = defaultdict(list)
        for r in bugs:
            if r["error"]:
                errs[r["error"]].append(r["version"])
        if errs:
            print("\nErrors (numbers folded to N, grouped):")
            for e, vs in sorted(errs.items(), key=lambda kv: -len(kv[1])):
                print(f"  {len(vs)} x {e}   [v{', v'.join(sorted(set(vs)))}]")

        print("\nCharacters in the reports:")
        for c, n in Counter(r["character"].split(" · homeland")[0] for r in bugs).most_common():
            print(f"  {n} x {c}")

        notes = [(r["what"], r["note"], r["version"]) for r in bugs if r["note"]]
        if notes:
            print("\nNotes from testers:")
            for w, n, v in notes:
                print(f"  [v{v}, {w}] {n}")

        awkward = [r for r in bugs if r["fight"] and "awkward" in r["what"].lower()]
        if awkward:
            print("\nFights attached to 'awkward line' reports (read the tester's note, then the lines):")
            for r in awkward:
                print(f"  -- {r['character'].split(' · homeland')[0]} · {r['note'] or 'no note'}")
                for l in r["fight"]:
                    print(f"     {l}")

    quiet = Counter()
    for r in reports:
        for q in r.get("quiet", []):
            quiet[re.sub(r"\d+", "N", q)] += 1
    if quiet:
        print("\nWhy presses stayed quiet (all reports):")
        for q, n in quiet.most_common(8):
            print(f"  {n} x {q}")

    flags = [(f, why) for r in exports for f, why in r["flags"]]
    if flags:
        print("\nFlagged moments from exports:")
        for f, why in flags:
            print(f"  {f}\n     -> {why}")


if __name__ == "__main__":
    main()
