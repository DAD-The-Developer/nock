# Contributing

This repo has no license yet, so there is no general invitation to reuse or republish the code or art. Bug reports and change requests from people who use the addon are welcome on GitHub.

If you are maintaining Nock in this repo (including automated work on Ben's behalf):

- The working copy is this git repository. Always `git pull --rebase origin main` before you start, so GitHub is the source of truth.
- Every Nock change should be committed with a clear message, pushed to `main`, version-tagged, and published as a GitHub Release with a clean `Nock-<version>.zip` attached.
- Follow `RELEASING.md` for the full checklist (version bump, tests, pack script, tag, release).
- Do not commit SavedVariables, backups, error logs, character names, personal screenshots, tokens, or PC paths.

The addon folder you copy into `Interface\AddOns` is `Nock/` at the repo root.
