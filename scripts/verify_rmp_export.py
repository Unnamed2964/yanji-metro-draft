#!/usr/bin/env python3
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
svg = (ROOT / "RMP.svg").read_text(encoding="utf-8")

vb = re.search(r'viewBox="([^"]+)"', svg)
print("viewBox:", vb.group(1) if vb else "missing")

rmp = re.search(
    r'transform="translate\(([^)]+)\)"[^>]*id="rmp_info"',
    svg,
)
print("rmp_info:", rmp.group(1) if rmp else "missing")

dy_m2 = svg.count('dy="-2"')
dy_m1 = svg.count('dy="-1"')
print("dy=-2:", dy_m2, "dy=-1:", dy_m1)

webp = ROOT / "RMP.webp"
print("webp:", webp.exists())

ok = (
    vb is not None
    and rmp is not None
    and dy_m2 > 0
    and dy_m1 == 0
    and webp.exists()
)
sys.exit(0 if ok else 1)
