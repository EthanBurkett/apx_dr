# Release procedure

This is manual. No repository tool creates a public release or uploads credentials.

## Prepare a candidate

1. Resolve the [rights inventory](LICENSING.md) before the first public Git/LFS
   push, including asset and converter permissions. Keep private correspondence
   outside the public repository.
2. Hydrate assets; run `git lfs fsck` and confirm LFS storage/transfer capacity.
3. Run `python tools/check.py --suite full`, `.\tools\test-build.ps1` and
   `.\tools\test-shaders.ps1`.
4. Build `.\tools\build.ps1 -OutputDirectory dist/release-candidate -Force`.
5. Test that candidate using `test-runtime.ps1 -ModDirectory` and pool checks on
   each intended map. Run relevant native suites and
   [human-client checks](TESTING.md#human-client-release-checks).
6. If the server changed, rebuild it and verify server/build.json hashes.
   Retain the matching AGPL source ZIP and license with its binary.

Commit intentional profile, generator and generated-output changes together.
Set a release version/tag after verification; none is invented by the tools.

## Package by destination

**Public client download allowlist:**

- `mod.ff`
- `apx_dr.iwd`
- `apx_dr_sounds.iwd`
- Public release notes, attribution and applicable licenses

Inspect IWDs using `python -m zipfile -l <file.iwd>`. Private config must never
appear. Do not ZIP the working directory, whole dist/build or a server homepath.

**Private server deployment:** install artifacts, public defaults, operator-managed
private config, maps and matching server. Retain rollback files outside the
public download root. Stop your own processes before replacing locked packages.

**Server distribution:** provide the binary with AGPL notice, matching complete
corresponding source ZIP, patch and build record. Follow applicable AGPL
source/network-use requirements; the ApX notice does not replace them.

## Hash and inspect

```powershell
Get-FileHash dist/release-candidate/mod.ff -Algorithm SHA256
Get-FileHash dist/release-candidate/apx_dr.iwd -Algorithm SHA256
Get-FileHash dist/release-candidate/apx_dr_sounds.iwd -Algorithm SHA256
python tools/repo_audit.py --assets
git diff --check
git status --short
```

Inspect staged paths. Private config, downloads, native logs and backups must
remain ignored. Do not attach unredacted logs to public issues.

Before a remote push, inspect `git lfs ls-files` and test a clean clone.
Uploading only Git objects leaves unusable pointers. Preserve the LFS pre-push
hook so payloads are uploaded too.

Record commit, artifact hashes, active profile, map budgets, server revision
and verification limitations in release notes.
