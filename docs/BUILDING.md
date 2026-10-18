# Building and packaging

`project.json` defines source roots, ordered manifest fragments, archive entries,
loose configs and obsolete output names. `tools/build.ps1` is the build entry
point. No Python, Blender or external ZIP program is needed for normal builds.

```powershell
.\tools\build.ps1
.\tools\build.ps1 -Target Fastfile
.\tools\build.ps1 -Target Iwd
.\tools\build.ps1 -Target Check
.\tools\build.ps1 -Force
.\tools\build.ps1 -GameRoot 'C:\Games\Call of Duty 4' -OutputDirectory build/candidate
```

| Option | Default | Effect |
| --- | --- | --- |
| `-Target` | `All` | `All`, `Fastfile`, `Iwd` or input-only `Check` |
| `-GameRoot` | Checkout's grandparent | Game/Mod Tools installation |
| `-OutputDirectory` | `dist` | Candidate output directory |
| `-Language` | `english` | SDK language and isolated cache key |
| `-Force` | Off | Ignore incremental state |
| `-Pause` | Off | Wait at the end for interactive use |

## Artifact boundary

| Output | Contents | Public download? |
| --- | --- | --- |
| `mod.ff` | GSC text, menus, tables, models, materials and dependencies | Subject to rights review |
| `apx_dr.iwd` | Selected images, weapon definitions, credits and spray config | Subject to rights review |
| `apx_dr_sounds.iwd` | Sounds and song config | Subject to rights review |
| Entry configs and `config/` | Loose server configuration | Review separately; never upload secrets |
| `build/` | Logs, cache, downloads, temporary SDK files and backups | No |

A partial build updates requested artifact families plus loose configs.
Use `All` for releases. Successful publication removes obsolete `deathrun.iwd`
and `deathrun_sounds.iwd` outputs to prevent duplicate asset loading.

## Transactions and cache

Inputs and outputs are fingerprinted with SHA-256. State is separated by SDK,
language and output directory under `build/state/`. The SDK namespace is tracked
conservatively with file metadata. Missing or modified outputs invalidate cache.
Unchanged loose configs keep their timestamps.

IWDs use stable entry order and timestamps. Fastfiles are produced by the SDK;
the project does not promise byte-identical fastfiles across SDK installations.

The builder locks the shared SDK, backs up overlaid raw/zone files, stages inputs,
runs an owned hidden linker process, checks diagnostics and restores SDK files.
Publication occurs only after requested work succeeds, with rollback on failure.
Exit code zero is not accepted if the log reports an error. Recovery data remains
under `build/tmp/` if restoration cannot finish. Forced termination can interrupt
cleanup; inspect recovery files before another build.

## Linker capacity versus client capacity

The `cod4-sdk-large-content-v1` profile creates a checksum-verified private copy
of the stock linker and enlarges its vertex stream from 32 to 128 MiB and index
stream from 8 to 64 MiB. The original SDK executable remains unchanged.

This permits linking the library. It **does not** increase the official client's
weapon/material pools or guarantee texture memory availability. The active
profile and texture policy remain required. See [content](CONTENT.md).

## Module ownership

| Module | Responsibility |
| --- | --- |
| `tools/build/Project.ps1` | Project discovery, paths and source mappings |
| `tools/build/Manifest.ps1` | Build plan and input validation |
| `tools/build/Archives.ps1` | Deterministic IWDs and loose-config copying |
| `tools/build/Linker.ps1` | SDK lock, staging, child process, diagnostics and restoration |
| `tools/build/Publish.ps1` | Artifact replacement and rollback |
| `tools/build/Cache.ps1` | Fingerprints and incremental state |
| `tools/build/Shaders.ps1` | HLSL compilation, cache and shader-registry merge |
| `tools/build/Shaders.cs` | Windows D3D compiler bridge |

These modules are sourced by the entry point, not independent scripts.
See [testing](TESTING.md) for transaction and shader checks.
