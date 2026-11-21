#!/usr/bin/env python3
"""Nock 3.3.0 map pins and quiver counter tests (Lua 5.1 via lupa)."""
import sys
from pathlib import Path
try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().NOCK_DIR = str(ROOT / "Nock") + "/"
try:
    lua.execute((ROOT / "tests" / "test_pins.lua").read_text())
except Exception as e:
    print("LUA ERROR:", e)
    sys.exit(1)
