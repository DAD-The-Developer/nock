# Contributing

Nock is licensed under the GNU General Public License, version 3. See LICENSE. Bug reports and change requests from people who use the addon are welcome on GitHub.

If you are maintaining Nock in this repo (including automated work on Ben's behalf):

- The working copy is this git repository. Always `git pull --rebase origin main` before you start, so GitHub is the source of truth.
- Every Nock change should be committed with a clear message, pushed to `main`, and version-tagged. Pushing a `v*` tag publishes the GitHub Release and the CurseForge file (see `RELEASING.md`). Do not also run `gh release create`.
- Follow `RELEASING.md` for the full checklist (version bump, tests, optional local pack, tag).
- Do not commit SavedVariables, backups, error logs, character names, personal screenshots, tokens, or PC paths.

The addon folder you copy into `Interface\AddOns` is `Nock/` at the repo root.
