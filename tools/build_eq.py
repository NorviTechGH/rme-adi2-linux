#!/usr/bin/env python3
"""Recreated EQ builder — thin wrapper around adi2.eqbuild (see that
module for the full help). Kept at tools/build_eq.py, the path of the
lost 2026-05 original."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1] / "src"))
from adi2.eqbuild import main  # noqa: E402

if __name__ == "__main__":
    raise SystemExit(main())
