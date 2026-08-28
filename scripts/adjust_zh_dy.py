#!/usr/bin/env python3
"""Raise Chinese station names by 1px in RMP-exported SVG (dy -1 -> -2).

Usage:
  python scripts/adjust_zh_dy.py RMP.svg
  python scripts/adjust_zh_dy.py "hsr map/拼接.svg"
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SVG = ROOT / "hsr map" / "拼接.svg"

pattern = re.compile(
    r'(<g\s[^>]*id="stn_name_[^"]+"[^>]*transform="(?!matrix)[^"]*"[^>]*>)(.*?)(</g>)',
    re.DOTALL,
)

zh_pattern = re.compile(
    r'(<text\b(?=[^>]*font-family="SimHei)[^>]*\sdy=")-1(")',
    re.DOTALL,
)


def adjust(path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    count = 0
    changed_names: list[tuple[str, int]] = []

    def repl(match: re.Match[str]) -> str:
        nonlocal count
        header, body, footer = match.group(1), match.group(2), match.group(3)
        id_match = re.search(r'id="(stn_name_[^"]+)"', header)
        name = id_match.group(1) if id_match else "?"

        def zh_repl(zh_match: re.Match[str]) -> str:
            nonlocal count
            count += 1
            return zh_match.group(1) + "-2" + zh_match.group(2)

        new_body, n = zh_pattern.subn(zh_repl, body)
        if n:
            changed_names.append((name, n))
        return header + new_body + footer

    new_text, groups = pattern.subn(repl, text)
    print(f"groups matched: {groups}")
    print(f"zh texts updated: {count}")
    for name, n in changed_names:
        print(f"  {name}: {n}")

    if count:
        path.write_text(new_text, encoding="utf-8")
        print("written")
    else:
        print("no changes")

    return count


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SVG
    if not path.is_file():
        raise SystemExit(f"file not found: {path}")
    adjust(path)


if __name__ == "__main__":
    main()
