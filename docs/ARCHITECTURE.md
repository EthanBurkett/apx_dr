# ApX Deathrun architecture

## Project boundaries

| Directory | Ownership |
| --- | --- |
| `src/braxi/` | Gameplay, administration, progression and compatibility APIs |
| `src/maps/`, `src/plugins/` | Engine entry points, maps and plugins |
| `src/ui_mp/`, `src/ui/` | Menus, components and shared macros |
| `src/mp/`, `src/english/` | Gameplay tables and localization |
| Other `src/` directories | Textual weapon, rumble, vision, audio alias and animation definitions |
| `assets/` | Models, images, materials, effects, animations and audio |
| `config/server/`, `config/deathrun/` | Focused server and gameplay settings |
| `manifests/` | Numbered fastfile fragments grouped by asset type |
| `tools/build/` | Project mapping, validation, archives, linking and publication |
| `tests/` | Source decision, map-data, inspection and downloader regressions |
| `dist/`, `build/` | Release outputs and temporary/log/test state |

`project.json` defines source roots, archives and loose configuration mappings.
Each source root overlays the SDK `raw` namespace: `src/braxi/_mod.gsc` still
loads as `braxi/_mod.gsc`, and `assets/images/` packages as `images/`.

## Gameplay ownership

`src/maps/mp/gametypes/deathrun.gsc` installs callbacks and calls
`braxi/_mod.gsc::main`. The former 2,282-line core is now a bootstrap and public
facade. Original public function names and parameter lists remain; forwarders
preserve `self`, return values and caller threading. Internal calls go directly
to the owning implementation.

| Modules under `src/braxi/` | Responsibility |
| --- | --- |
| `_mod` | Bootstrap and original core API |
| `_assets`, `_profile` | Precaching, spawn discovery, tables and saved customization |
| `_player`, `_teams` | Connection, spawn, spectator state, cleanup, AFK and teams |
| `_combat`, `_movement`, `_equipment` | Damage/death, jumping, sprays and equipment |
| `_rounds`, `_selection` | Round state and bounded activator selection |
| `_hud`, `_lives`, `_records`, `_events` | HUD, life use, course records and match events |
| `_admin`, `_admin_auth`, `_admin_ui`, `_admin_commands`, `_admin_progression` | Public API, authentication, UI, actions and progression testing controls |
| `_rank`, `_rank_integrity`, `_rank_tables`, `_rank_players`, `_rank_progression`, `_rank_hud`, `_unlocks` | Public API, persistence, progression and unlocks |
| `_missions`, `_challenge_data`, `_challenge_events`, `_challenge_progress` | Public API, definitions, event watching and progress |
| `_mapvoting`, `_vote_maps`, `_vote_players`, `_vote_hud` | Public API, candidates, input and presentation |
| `_maps`, `_map_data`, `_map_traps` | Map setup, table loading and trap lifecycle |
| `_common`, `_dvar`, `_menus` | Shared helpers, normalized settings and menu dispatch |
| `_menu_service`, `_menu_catalog`, `_menu_browser`, `_preferences` | Access, validated equipment, scalable browsing and saved presentation settings |

Facades intentionally preserve calls from existing maps/plugins. Implementations
live in focused modules. Original notices and plugin compatibility version
remain. Map-specific scripts and stock utility overrides retain their boundaries;
this is not a claim that every individual file needed splitting.

`level` owns per-round state, `game` survives restarts and player `pers` retains
team/progression/life state. Round states remain `readyup`, `playing`,
`round ended` and `endmap`. End-round ownership is claimed before notifications;
activator ownership is claimed before spawning. Keep guards and claims together
without intervening waits. Existing event names remain integration points.
Entity-owned threads must cancel on relevant death/disconnect/deletion events.

## Data and UI

Map coordinates, trap names and collision fixes live in `src/mp/apx_*.csv`.
The loader processes only the current map, filters missing trap entities and
respects an existing finish trigger. Collision IDs start at 1 and are contiguous.
Finish rows use map-name keys; trap names use semicolon-separated lists.

Character IDs 1, 2, 3 and 9 remain reserved as Marine fallbacks. Missing models
are not linked or offered in the picker. Column 8 of `characterTable.csv` marks
enabled characters; saved IDs are never renumbered.

`dr_common.inc` aggregates eight macro components. `hud.menu` aggregates tokens
and 21 individual menu definitions under `ui_mp/hud/`. Main/customization menus
live under `ui_mp/menus/`; challenge setup is under `ui_mp/components/`.
Preserve engine include paths and macro continuations. These are compiler
includes, not separately linked menus.

Map-generated `maps/createart/<map>_art.gsc` and `maps/mp/<map>_fx.gsc` belong to
each map's fastfile. Active plugin dependencies are explicitly packaged; unused
examples remain disabled.

## Build boundaries

`tools/build.ps1` orchestrates seven modules. `Project.ps1` resolves paths;
`Manifest.ps1` validates the full plan; `Archives.ps1` creates stable ZIPs and
copies configs; `Linker.ps1` overlays/restores SDK files and captures diagnostics;
`Publish.ps1` replaces outputs with rollback. `Cache.ps1` fingerprints inputs
and published outputs, skips unchanged artifacts and commits state after success.
`Shaders.ps1` compiles changed HLSL stages through the Windows compiler helper,
merges the SDK name registry into generated assets and caches individual stages.
The normal SDK overlay/restore transaction handles the generated shader files.

| Output | Inputs |
| --- | --- |
| `mod.ff` | Manifest fragments and mapped source/SDK inputs |
| `apx_dr.iwd` | Images, weapons, original readme and spray list |
| `apx_dr_sounds.iwd` | Audio and song list |
| Loose configs | Entry configs, grouped settings and private settings |

Local launch and smoke tests use `fs_game Mods/apx_dr/dist`.
Server configuration executes private settings last. Credentials are excluded
from client archives. Deploy the entire `dist/` tree. The README supplies the
Linux `cod4x_dedrun` command and Windows build/client/server commands.
`tools/test-runtime.ps1` tests loading and status on the supplied Windows
`apx_cod4x_dedrun.exe` with isolated loopback settings.
The stock SDK `maps/createfx/mp_crash_fx.gsc` is explicitly linked because
the downloaded Long map FX calls it without supplying the dependency.


The expanded progression and native Tab scoreboard replacement are documented in
[PROGRESSION.md](PROGRESSION.md). The existing public rank APIs remain available;
prestige rules live in `_prestige.gsc` and scoreboard data in `_scoreboard_panel.gsc`.

Image button artwork and the SDK choice wrapper are documented in
[INTERFACE.md](INTERFACE.md). Art generation stays outside the build; generated
engine assets are normal incremental build inputs, so no Python is needed to build.

EFR and HUD ownership are documented in [HUD-AND-PRACTICE.md](HUD-AND-PRACTICE.md).
`plugins/_efr.gsc` gates round setup without a competing game-logic thread;
`_hud_state.gsc` sends changed client values, while the UI includes own layout.
Native HLSL assets and incremental compilation are documented in [SHADERS.md](SHADERS.md).

The redesigned menu generator and native response bridge are documented in
[MENUS.md](MENUS.md). `ui/menu_catalog.json` owns the navigation registry;
`generate_menus.py` and `menu_showcase.py` generate distinct page layouts.
The client index and manifest package all pages without precaching every page
into the 32 server menu configstrings. Actual model stills and turntables have
an optional isolated Blender pipeline; no Blender dependency enters normal builds.
