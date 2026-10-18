# Contributing

Original ApX work requires permission for use or modification. Contact the
repository owner before starting outside an existing authorization;
see [LICENSE.md](LICENSE.md). Third-party files retain their own terms.
A pull request does not establish rights to imported assets.

## Prepare a change

1. Follow [setup](docs/GETTING-STARTED.md); run `python tools/check.py`.
2. Keep changes focused and follow [module ownership](docs/ARCHITECTURE.md)
   and the [tool reference](docs/TOOLING.md).
3. Edit generators/registries before generated menus, tables or art. Commit
   intended regenerated output with its generator.
4. Preserve persisted content/stat IDs and public plugin entry points.
5. Record provenance and redistribution evidence for added assets.
6. Run appropriate checks and describe actual scope. A Python pass does not
   imply native/client verification.

## Review checklist

- No credentials, private configs, native logs, downloads or backups.
- Binary assets use LFS; build products remain ignored.
- New tools document options, inputs, outputs and dependencies.
- Server enforces unlocks and admin/VIP/equipment permissions.
- SDK files are restored after successful and failed builds.
- Official-client pool/memory budgets and Deathrun rules remain respected.

Use issue forms for reproducible bugs and feature proposals. Include map, profile,
command, expected/actual behavior and redacted diagnostics. Do not include private
files or full player identifiers.

Run `git diff --check` and inspect `git diff --cached --stat` before review.
[Testing](docs/TESTING.md) defines source, asset, native and human checks.
