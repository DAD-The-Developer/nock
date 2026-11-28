# Releasing Nock

This is the public repo: https://github.com/DAD-The-Developer/nock

The working copy that gets edited is this repository (the directory that contains `Nock/`, `tests/`, and this file). Future Nock work should happen here, not in a loose copy of the addon folder.

Nock is also listed on CurseForge as [Nock Hunter HUD](https://www.curseforge.com/wow/addons/nock-hunter-hud) (project id 1820419). The short name "Nock" was already taken. The addon folder and package name stay `Nock`.

## Every change

Whenever Nock is updated:

1. `git pull --rebase origin main` first, so any edits already pushed to GitHub are in the tree before you start.
2. Make the change in `Nock/` (and `tests/` or `art/` if needed).
3. Bump the version in `Nock/Nock.toc`, `Nock/Nock_Forever.toc`, `Nock.lua` (`VERSION`), the tests that assert the version, `CHANGELOG.md`, and the "New in" blurb in `Nock/README.txt`. Add the version's entry at the top of `Nock/Changelog.lua` (the in-game What's New window; New / Improved / Fixed), then run `python3 tools/release_notes.py` to write `RELEASE_NOTES.md`. The packager uses that file (`.pkgmeta` manual-changelog) as the GitHub release notes and the CurseForge changelog. `tests/run_news.py` fails if they drift apart.
4. Run the tests:

       python3 tests/run_style.py
       python3 tests/run_threat.py
       python3 tests/run_fresh_load.py
       python3 tests/run_pins.py
       python3 tests/run_tools.py
       python3 tests/run_window.py
       python3 tests/run_petbar.py
       python3 tests/run_dash.py
       python3 tests/run_binds.py
       python3 tests/run_news.py
       python3 tests/run_questdrops.py
       python3 tests/run_flights.py
       python3 tests/run_check.py
       python3 tests/run_auto.py
       python3 tests/run_rewards.py

5. Optionally build a local shareable zip to check the contents:

       python3 tools/pack_release.py

   This still writes `share/Nock-<version>.zip` for local testing. The zip that is attached to the GitHub Release (and uploaded to CurseForge) is built by the packager workflow when you push the tag. That zip also includes `LICENSE`.
6. Commit with a clear message (what changed, and the version).
7. Push `main`.
8. Tag the version (`v3.5.1`, and so on) and push the tag. Pushing a `v*` tag is what publishes the release.

Example:

```
git pull --rebase origin main
# ...edit, test, optionally pack a local zip...
git add -A
git status   # confirm nothing personal or generated slipped in
git commit -m "Nock 3.5.1: short description of the change"
git push origin main
git tag -a v3.5.1 -m "Nock 3.5.1"
git push origin v3.5.1
```

Do **not** also run `gh release create` for that tag. `.github/workflows/release.yml` runs [BigWigsMods/packager](https://github.com/BigWigsMods/packager) on `v*` tags. The packager creates the GitHub Release (or updates it if it already exists), attaches its zip, and uploads to CurseForge when both of these are set:

- `## X-Curse-Project-ID: 1820419` in `Nock/Nock.toc` and `Nock/Nock_Forever.toc`
- the repo secret `CF_API_KEY` (a CurseForge author API token)

If either is missing, CurseForge is skipped and the GitHub Release is still created. If you create the GitHub Release by hand first, the packager will update that release and attach a second zip, which is confusing, so leave the release to the workflow.

The packager reads `## Interface: 16001` and uploads the file for **Forever / 1.60.1** (not Classic Era / 1.15.x). Do not override that with a `-g` classic flag.

The first tag after this workflow lands on `main` should be a **new** version (`v3.5.1` or later). `v3.5.0` is already tagged and already has a GitHub Release; pushing that tag again will not run the new workflow.

Watch the run at https://github.com/DAD-The-Developer/nock/actions

The packager zip is typically named from the git tag, for example `Nock-v3.5.1.zip`. The local `pack_release.py` zip stays `Nock-3.5.1.zip`. Both should contain a single top-level `Nock/` folder.

## What must not be committed

- SavedVariables, account or character names, key bindings from a live WTF folder
- Backups (`Nock.bak-*`)
- Error logs
- In-game screenshots or mockups drawn over a live UI
- Tokens, credentials, `.env` files, or PC paths (for example a user's home directory or `Program Files` install script)
- The CurseForge API token (`CF_API_KEY` lives only as a GitHub Actions secret)

The shareable zip should stay a single top-level `Nock/` folder and should not include tests, art masters, or any of the above.

## First-time textures

New or replaced `.tga` files need a full WoW restart to load. Lua-only changes can use `/reload` if the textures are already in place.
