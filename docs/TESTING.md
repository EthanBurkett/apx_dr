# Verification

Run commands from the repository root. Python 3.12+ and
`python -m pip install -r requirements-dev.txt` are needed for Python suites.

## Fast checks without the SDK

```powershell
python tools/check.py
.\tools\test-build.ps1
```

Core validates local references, table IDs, public configs, documentation links,
tool coverage and script decision tests. It skips image decoding, binary-material
assertions and SDK-owned references. LFS can remain unhydrated. Private configs
are excluded before reading.

The build suite uses a fake SDK/linker to test publication, restoration, rollback,
locking, cache invalidation and deterministic IWD behavior. It needs Windows and
the .NET Framework C# compiler, not the proprietary SDK.

## Full source and asset checks

```powershell
git lfs pull
git lfs fsck
python tools/check.py --suite full
.\tools\test-shaders.ps1
.\tools\build.ps1 -Target Check
```

Full mode adds binary/PNG assertions and SDK import checks; use `--game-root` for
another SDK location. It fails early on LFS pointers. The shader suite compiles
native HLSL and covers caching, failures and supported SM2 behavior.

`tests/gsc_runtime.py` runs selected GSC decisions with explicit native doubles.
It is not a VM, network simulator, renderer or replacement for CoD4x compilation.
Asset tests inspect real encoded layouts, atlas cells and packaging contracts.

## Real server checks

Build first, install the matching server and use an installed map:

```powershell
.\tools\build.ps1
.\tools\test-runtime.ps1 -Map mp_backlot -Duration 20 -AssetUsage -ClientBudget
.\tools\test-progression.ps1 -Suite Progression
.\tools\test-progression.ps1 -Suite Equipment
```

`test-progression.ps1` accepts `Progression`, `Efr`, `Hud`, `Menus`, `Content`,
`Traffic` and `Equipment`. Each builds an isolated package with a test driver and
bot. It does not modify human profiles or load private config.
GSC fixtures live in `tests/runtime/`.

| Suite | Main responsibility |
| --- | --- |
| Progression | Level/prestige transitions, persistence and reset boundaries |
| Efr | Population transitions and practice behavior |
| Hud | Live HUD state/lifecycle |
| Menus | Routes, paging/search, preferences and confirmations |
| Content | Catalog/unlock behavior with live assets |
| Traffic | Initialization/menu synchronization volume |
| Equipment | Primary + knife inventory, arms, unlocks and special-mode rules |

Fixtures copy assets and can need several GB. Logs remain in build for inspection.
Ports must be free. The engine's fs_game path is limited to 63 characters, so
fixtures use short generated names; keep the parent checkout path short too.

**Bot limitation:** equipment tests check inventory, command acceptance, arms and
rules. Bots do not faithfully reproduce human weapon input; the fixture explicitly
draws a weapon with setSpawnWeapon after checking command acceptance. This does
not prove client cycling, animation or melee feel.

## Human-client release checks

Use the official client on a stock map and intended Deathrun maps:

- Join, spawn, reconnect, change map and transition from practice to a round.
- Open every offline/in-server menu; check hover/focus text, settings/back routes
  and leave-server confirmation.
- Type in search and page entry; each character should appear once.
- Browse Primary, Knife, Operators and Arms; check search/filter/page entry,
  still default, optional rotation, equip and next-spawn persistence.
- Cycle primary/knife; test melee animation, sound and damage.
- Check dog, knife-only and Activator equipment rules.
- Confirm full reset, prestige confirmation and reward browsing.
- Check HUD aspect ratios, damage feedback and saved display options.
- Exercise real-client joins/menu traffic; bots do not reproduce the same
  reliable-command queue.

## CI boundary

[CI](../.github/workflows/checks.yml) runs SDK-free checks on Linux and Windows
without LFS downloads. Windows also runs fake-SDK build tests. An explicit manual
asset-check input hydrates LFS and runs all Python tests, without pretending that
hosted runners have the proprietary SDK.

Native server, real linker and human-client checks remain local. CI does not
publish releases or execute downloaded model packs. [AUDIT.md](AUDIT.md) is a
historical record; current results come from running these checks on the release
commit.
