# ApX CoD4x server

This is a source-built Windows CoD4x server for the expanded ApX content catalog.
Upstream: https://github.com/callofduty4x/CoD4x_Server
Pinned revision: `ddd65fce1a1093017bad2dbb6840d75d11c0d56f`.

The reviewed patch in `patches/asset-pools.patch` changes the database pools:

| Asset | Upstream | ApX |
|---|---:|---:|
| Weapon definitions | 128 | 512 |
| Models | 1000 | 2048 |
| Materials | 2048 | 4096 |
| Images | 2400 | 4096 |
| Effects | 400 | 1024 |
| Loaded sounds | 1200 | 4096 |

The definition pool includes stock and map weapon assets as well as mod assets.
It is separate from the active/precache weapon ID table. The latter and the
network/player-state layouts retain their existing limits and format. The
current catalog is checked by the native Content fixture before publication.
The upstream startup override excludes weapon definitions, so setting
`r_xassetnum weapon=512` on an unmodified server does not solve this failure.

Build and install from the mod directory:

```powershell
.\tools\build-server.ps1 -Install
.\tools\launch.ps1 -Mode Server
```

The builder uses the upstream Windows CI's portable i686 GCC 8.1 toolchain,
verifies its archive SHA-256, and requires NASM on PATH. It runs natively on
Windows and installs `apx_cod4x_dedrun.exe` beside the original server without
replacing it. This is a non-OFFICIAL build, so the upstream auto-update path does
not overwrite these local changes. Server launch and smoke-test tools default
to the ApX executable; an explicit `-Executable` still overrides that choice.
Unchanged source/toolchain inputs reuse the verified binary and source bundle.
If the installed executable is running, `-Install` stages a `.next.exe` copy;
stop the server and rerun `build-server.ps1 -Install` to replace the locked file.

`bin/` contains the resulting executable; `build.json` records its checksum,
patch checksum and revision. `apx-cod4x-source.zip` contains the full corresponding
tracked source with the modifications applied; `LICENSE.md` retains upstream's
AGPL-3.0 license. Preserve this source/license bundle when distributing the server
and make the corresponding source available to its network users.

The server does not change a client's own database capacities or renderer.
The custom defaults are advertised through the existing CoD4x capacity
handshake for pools supported by the client. The complete imported library
exceeded the official client's limits; its source assets remain archived. The
active official-client profile loads 152 weapon definitions / 1565 materials on
Lithium, and 153 / 1878 on Backlot, including stock/map assets and overrides.
The installed official 21.8 client DLL was inspected
read-only: its weapon database pool initializes to 168. Weapon and material
capacity requests are excluded by the public client's resize path. No client
DLL, authentication setting or installed game profile has been changed.
Client-side rendering and joining still require checks with the supported
CoD4x client. Use `tools/test-runtime.ps1 -ClientBudget -Map <map>` to check the
active profile's asset targets before adding a map to rotation. Build-time SDK linker stream changes are separate and documented
in `docs/CONTENT.md`.
