#!/usr/bin/env python3
"""Write RELEASE_NOTES.md (GitHub release + CurseForge changelog, via .pkgmeta
manual-changelog) from Nock/Changelog.lua, the same notes the in-game
What's New window shows. Usage: python3 tools/release_notes.py [--print]"""
import sys
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parent.parent


def notes():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("Nock = {}; _G.Nock = Nock")
    g = lua.globals()
    g._SRC = (ROOT / "Nock" / "Changelog.lua").read_text()
    lua.execute('assert(loadstring(_SRC, "Changelog.lua"))("Nock")')
    return lua.eval("Nock.WhatsNew.Markdown(Nock.Changelog[1])") + "\n", lua.eval("Nock.Changelog[1].version")


if __name__ == "__main__":
    text, ver = notes()
    if "--print" in sys.argv:
        print(text)
    else:
        (ROOT / "RELEASE_NOTES.md").write_text(text)
        print("Wrote RELEASE_NOTES.md for", ver)
