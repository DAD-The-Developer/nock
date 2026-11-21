# Releasing Nock

This is the public repo: https://github.com/DAD-The-Developer/nock

The working copy that gets edited is this repository (the directory that contains `Nock/`, `tests/`, and this file). Future Nock work should happen here, not in a loose copy of the addon folder.

## Every change

Whenever Nock is updated:

1. `git pull --rebase origin main` first, so any edits already pushed to GitHub are in the tree before you start.
2. Make the change in `Nock/` (and `tests/` or `art/` if needed).
3. Bump the version in `Nock/Nock.toc`, `Nock/Nock_Forever.toc`, `Nock.lua` (`VERSION`), the tests that assert the version, `CHANGELOG.md`, and the "New in" blurb in `Nock/README.txt`.
4. Run the tests:

       python3 tests/run_style.py
       python3 tests/run_threat.py
       python3 tests/run_fresh_load.py
       python3 tests/run_pins.py
       python3 tests/run_tools.py

5. Build the shareable zip:

       python3 tools/pack_release.py

6. Commit with a clear message (what changed, and the version).
7. Push `main`.
8. Tag the version (`v3.2.1`, and so on) and push the tag.
9. Create a GitHub Release for that tag and attach `share/Nock-<version>.zip`.

Example:

```
git pull --rebase origin main
# ...edit, test, pack...
git add -A
git status   # confirm nothing personal or generated slipped in
git commit -m "Nock 3.2.1: short description of the change"
git push origin main
git tag -a v3.2.1 -m "Nock 3.2.1"
git push origin v3.2.1
gh release create v3.2.1 share/Nock-3.2.1.zip --title "Nock 3.2.1" --notes "$(sed -n '/^## 3.2.1/,/^## /p' CHANGELOG.md | sed '$d')"
```

## What must not be committed

- SavedVariables, account or character names, key bindings from a live WTF folder
- Backups (`Nock.bak-*`)
- Error logs
- In-game screenshots or mockups drawn over a live UI
- Tokens, credentials, `.env` files, or PC paths (for example a user's home directory or `Program Files` install script)

The shareable zip should stay a single top-level `Nock/` folder and should not include tests, art masters, or any of the above.

## First-time textures

New or replaced `.tga` files need a full WoW restart to load. Lua-only changes can use `/reload` if the textures are already in place.
