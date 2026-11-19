#!/usr/bin/env python3
"""Run Nock 3.1.0 style-system tests with Lua 5.1 via lupa."""
import sys
from pathlib import Path

try:
    from lupa import LuaRuntime
except ImportError:
    from lupa.lua51 import LuaRuntime

ROOT = Path("/workspace/nock/Nock")
TESTS = Path("/workspace/nock/tests")

# Reuse threat stubs, but drop the canned NockTheme so Theme.lua can own it.
stubs = (TESTS / "stubs_threat.lua").read_text()
# The stub assigns NockTheme at the end; strip that block.
cut = stubs.find("NockTheme = {")
if cut < 0:
    raise SystemExit("could not strip stub NockTheme")
stubs = stubs[:cut] + "\nNockTheme = nil\n"

src = stubs + "\n" + (ROOT / "Theme.lua").read_text() + "\n" + (ROOT / "Styles.lua").read_text() + "\n" + (TESTS / "test_style.lua").read_text() + "\n"

lua = LuaRuntime(unpack_returned_tuples=True)
try:
    lua.execute(src)
except Exception as e:
    print("LUA ERROR:", e)
    sys.exit(1)

ok = bool(lua.globals().STYLE_TEST_OK)
print("STYLE_TEST_OK" if ok else "STYLE_TEST_FAIL")
sys.exit(0 if ok else 1)
