#!/usr/bin/env python3
"""Run Nock 3.0.12 threat-meter tests with Lua 5.1 via lupa."""
import sys
from pathlib import Path

try:
    from lupa import LuaRuntime
except ImportError:
    from lupa.lua51 import LuaRuntime

ROOT = Path("/workspace/nock/Nock")
TESTS = Path("/workspace/nock/tests")
STUBS = (TESTS / "stubs_threat.lua").read_text()
THREAT = (ROOT / "Threat.lua").read_text()
TEST = (TESTS / "test_threat.lua").read_text()

# Strip LuaJIT / 5.1-incompatible bits if any; Threat.lua is 5.1-clean.
src = STUBS + "\n" + THREAT + "\n" + TEST + "\n"

lua = LuaRuntime(unpack_returned_tuples=True)
# lupa Lua 5.1
try:
    lua.execute(src)
except Exception as e:
    print("LUA ERROR:", e)
    sys.exit(1)

# test file should set _G.THREAT_TEST_OK and print results
g = lua.globals()
ok = bool(g.THREAT_TEST_OK)
print("THREAT_TEST_OK" if ok else "THREAT_TEST_FAIL")
sys.exit(0 if ok else 1)
