# Working notes for Nock

Public repo: https://github.com/DAD-The-Developer/nock

This directory (`/workspace/nock` on the shared box) **is** the git working copy. Edit `Nock/` here. Do not keep a second unsynced copy of the addon as the place you ship from.

Before any Nock change:

1. `git pull --rebase origin main`
2. Make the change, bump the version, run tests, and optionally `python3 tools/pack_release.py` for a local zip check
3. Commit with a clear message, push `main`, and tag `vX.Y.Z`. Pushing the tag publishes the GitHub Release and CurseForge file via `.github/workflows/release.yml`. Do not also run `gh release create`.

Details are in `RELEASING.md` and `CONTRIBUTING.md`.

Do not commit SavedVariables, backups, error logs, character names, personal UI screenshots, tokens, or PC paths. `.gitignore` already excludes the common cases; still read `git status` before you commit.
