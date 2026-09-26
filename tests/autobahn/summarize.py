#!/usr/bin/env python3
"""
Summarize Autobahn client reports, or compare two runs.

usage:
  summarize.py <report_dir>                 per-section counts
  summarize.py <before_dir> <after_dir>     counts plus every case that changed
"""

import json
import sys
from collections import Counter, OrderedDict
from pathlib import Path


def load(report_dir):
    index = json.loads((Path(report_dir) / "clients" / "index.json").read_text())
    (agent, cases), = index.items()
    return cases


def case_key(case_id):
    return [int(p) for p in case_id.split(".")]


def section(case_id):
    parts = case_id.split(".")
    return ".".join(parts[:2]) if parts[0] in ("6", "7", "9") else parts[0]


def status(result):
    # 'behavior' is the case verdict; a failed close handshake downgrades it
    b = result["behavior"]
    if b in ("OK", "NON-STRICT", "INFORMATIONAL") and result["behaviorClose"] not in ("OK", "INFORMATIONAL"):
        return "FAILED-CLOSE" if result["behaviorClose"] == "FAILED" else b
    return b


def counts(cases):
    by_section = OrderedDict()
    for cid in sorted(cases, key=case_key):
        by_section.setdefault(section(cid), Counter())[status(cases[cid])] += 1
    return by_section


def print_counts(title, cases):
    total = Counter(status(r) for r in cases.values())
    print(f"\n{title}: {len(cases)} cases  " + "  ".join(f"{k}={v}" for k, v in sorted(total.items())))
    for sec, c in counts(cases).items():
        print(f"  {sec:<6} " + "  ".join(f"{k}={v}" for k, v in sorted(c.items())))


def main():
    runs = [load(d) for d in sys.argv[1:3]]
    if len(runs) == 1:
        print_counts(sys.argv[1], runs[0])
        return

    before, after = runs
    print_counts("before", before)
    print_counts("after", after)
    # only compare cases both runs have, so a partial run (CASES=...) diffs cleanly
    common = sorted(set(before) & set(after), key=case_key)
    changed = [c for c in common if status(before[c]) != status(after[c])]
    only = len(set(before) ^ set(after))
    note = f" ({only} cases not in both runs, skipped)" if only else ""
    print(f"\n{len(changed)} of {len(common)} cases changed{note}:")
    for c in changed:
        print(f"  {c:<10} {status(before[c]):>13} -> {status(after[c])}")


if __name__ == "__main__":
    main()
