# Getting started

## Requirements

| Task | Requirements |
| --- | --- |
| Clone the full repository | Git + Git LFS; several GB free for files and LFS objects |
| Build the mod | Windows, PowerShell 5.1+, licensed CoD4 + installed CoD4 Mod Tools |
| Launch locally | Official CoD4x client, matching ApX server, installed map |
| Run Python checks | Python 3.12+ and `requirements-dev.txt` |
| Regenerate previews | Blender 5.2, Python/Pillow, game/SDK files; optional importer download |
| Rebuild the server | Git, NASM on PATH, Windows tar; builder downloads a pinned i686 compiler |

The game, SDK and map collection are not included. Linux server builds and other
Blender versions are not covered by the Windows verification.

## Obtain a complete checkout

Install Git LFS, then clone this repository using its actual hosting URL. The
recommended location is `Call of Duty 4/Mods/apx_dr`.

```powershell
git lfs install
git lfs pull
git lfs fsck
```

The first command is normally run before cloning. If you cloned with LFS smudging
disabled, the latter two hydrate and verify assets. A tiny text file beginning
`version https://git-lfs.github.com/spec/v1` where a material, image or executable
should be is a pointer, not usable game data.

Keep the project source separate from its generated `dist/` install. Do not copy
the repository over a different mod or overwrite the game's `main/` directory.

## Configure

Copy the template only if you do not already have private settings:

```powershell
if (!(Test-Path config/private.cfg)) {
    Copy-Item config/private.example.cfg config/private.cfg
}
```

Edit `config/private.cfg` locally for RCON, passwords and admin credentials.
It is ignored by Git and never packed into IWDs. It **is copied into the local
deployment's loose configuration** when present, so do not upload all of `dist/`
to a public download host.

Public defaults live in `config/server.cfg`, `config/deathrun.cfg`,
`config/server/` and `config/deathrun/`. See [administration](ADMINISTRATION.md)
before enabling privileged actions.

## Build and install the matching server

```powershell
.\tools\build.ps1 -Target Check
.\tools\build.ps1
Copy-Item server/bin/apx_cod4x_dedrun.exe ..\..\apx_cod4x_dedrun.exe
```

The server binary and corresponding source are supplied through LFS.
To rebuild it instead:

```powershell
.\tools\build-server.ps1 -Install
```

This installs a separate executable; it does not replace the official client.
If the installed server is locked, the builder stages a `.next.exe` for a later
restart. See [server/README.md](../server/README.md) for the pinned revision,
asset-pool changes, checksums and AGPL source obligations.

The SDK is normally two directories above the checkout. Builds elsewhere can use
`.\tools\build.ps1 -GameRoot 'C:\Games\Call of Duty 4'`. Launching and native tests
still need a mod path relative to that game root; use the recommended placement
for the first setup.

If Windows blocks scripts, invoke the entry point in a process with
`-NoProfile -ExecutionPolicy Bypass`; do not change machine-wide policy:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\build.ps1
```

## Start a local session

Install the map first. Backlot is useful for a stock-map smoke test; a Deathrun
course is required to evaluate real traps.

```powershell
.\tools\launch.ps1 -Mode Server -Map mp_backlot -Dedicated 1
.\tools\launch.ps1 -Mode Client -Address localhost
```

Default mod directory is `dist/` and default game port is 28960. The launcher uses
`apx_cod4x_dedrun.exe` for the server and applies supported pool overrides to the
official client. It does not patch a client DLL.

For automated startup validation:

```powershell
.\tools\test-runtime.ps1 -Map mp_backlot -Duration 20 -AssetUsage -ClientBudget
```

This uses isolated loopback configuration and its own homepath. It does not load
your private config or exercise public admin credentials.

Next: [testing](TESTING.md), [tool reference](TOOLING.md) and
[troubleshooting](TROUBLESHOOTING.md).
