> Historical development log. Counts, limits and earlier designs below describe
> their original checkpoints. See [current testing](TESTING.md), [content](CONTENT.md)
> and [menus](MENUS.md) for the current configuration.

# ApX Deathrun maintenance audit

October 17, 2026. Target: CoD4x, server executable `cod4x_dedrun`.
Base: BraXi's Death Run 1.2.1. Preserve base features while cleaning the whole
project and correcting gameplay faults. This pass includes intentional behavior
changes; it is not only a mechanical extraction.

## Structure and tooling delivered

| Finding | Delivered |
| --- | --- |
| 2,282-line core mixed responsibilities | Bootstrap/public facade and focused gameplay modules |
| Large admin, rank, mission, map and voting implementations | Separate authentication/actions/UI, progression/unlocks, challenge data/events/progress, map data/traps and vote candidates/input/HUD |
| Large UI macro, HUD and customization files | Component includes, individual HUD menus and focused main/customization definitions |
| Long map references a missing stock FX script | Package the SDK Crash createfx script required by its downloaded fastfile |
| Large map switch | Three CSVs: 60 finish-trigger rows, 17 trap-map rows and 5 unique collision rows |
| Flat source and assets | `src/`, `assets/`, `config/`, `manifests/`, `tools/` and explicit `project.json` mappings |
| Large server/gameplay configs | Ordered entry configs and focused files; local credentials preserved separately |
| Batch entry points and bundled 7-Zip | PowerShell tooling and .NET archives; all batch entry points removed |
| One manifest and legacy package names | Numbered asset fragments and `apx_dr` package names |
| Destructive publication and unreliable linker status | Staging, rollback, diagnostics checks, SDK lock, raw/zone backup and restoration |
| No repeatable checks | Source validator, source decision tests and isolated SDK recovery tests |

Public GSC signatures, engine paths, menu contracts and saved IDs remain where
needed by maps/plugins. Contributor credits remain. Binary assets were organized
rather than cosmetically rewritten. Original weapon gameplay values remain.

## Gameplay and administration fixes

| Area | Result |
| --- | --- |
| Activator selection | One filtered candidate snapshot, empty-pool handling, fair minimum counts without skipped players or unbounded retries, previous-player avoidance when possible, role claimed before callbacks |
| Round transitions | Mark the round ended before notifications to prevent duplicate transitions |
| Customization | Reject invalid indices including `id == count`, normalize persisted choices and respect unlocks |
| Missing characters | Retire four unavailable models/picker choices; IDs 1, 2, 3 and 9 remain Marine fallbacks |
| Player initialization | Initialize persistence before the connected event, reset finish state and initialize spawn state synchronously |
| Spawns | Avoid empty-array selection and provide a defined last fallback; maps still need valid authored spawn points |
| Lives | Restrict use to dead jumpers in a live round; clamp counts, replace old icons and cancel pending respawns at round end |
| Records | Require a timer, living player and live round; guard absent HUD elements |
| Voting | Exclude the current map even for short rotations, handle no/one candidates, wrap offsets, bound counts and reject duplicate/malformed rotation entries |
| Map data | Handle short/multiword labels, filter missing traps, avoid duplicate finish triggers/collisions and restore Jurapark's finish target name |
| Traps/equipment | Bind trigger cancellation to the trigger, stop round-owned watchers, validate trigger players and entity lifetime after waits, correct spray bounds |
| Progression | Reject unknown/invalid XP rewards and prevent negative accumulated XP |
| Admin actions | Correct teleport indexing, missing-player access and stale menu actions; require the admin menu and clamp inspected selection |
| Admin login | Disable RCON client transfer by default, clear submitted passwords, bound/throttle responses and skip empty account slots |
| Server-owned access | Replace embedded personal bans/name harassment with `dr_banned_guids`; keep the old harassment hook inert for compatibility |
| Dvars/HUD | Honor zero lower bounds, publish clamped settings, remove unrelated encoded server info and duplicate HUD initialization, guard zero maximum health |
| Presentation | ApX branding with original attribution; remove an unrelated donation advert from the Qube plugin |

Four unavailable character model entries were removed at the owner's request.
Two SDK rumble profiles referenced missing console curves; local profiles share
a zero-strength curve. Their vibration is disabled without changing weapon
damage, handling, sounds or animations. The original missing model pack is not
available locally.

## Validation and limits

- Source validator: 81 local GSC files, 70 packaged scripts (including one SDK script); references, table IDs,
  UI includes, config paths/cycles and direct inputs checked.
- Python suite: 42 tests pass. They exercise source inspection, real source
  decisions for selection/voting/unlocks/lives, all extracted map data and HTTP
  mirror recovery/preservation and rectangular interface texture decoding.
  Fairness covers 81 count combinations. The texture decode test uses Pillow.
- Isolated Windows PowerShell 5.1 build suite: 40 assertions pass, covering
  exit-zero linker errors, output preservation, raw/existing zone restoration
  on success/failure, IWD reproducibility, archive paths, private config
  separation, overlap protection, traversal and missing dependencies.
- All 350 original BraXi function signatures remain at their original script paths.
- The real Windows PowerShell 5.1 full build passes: 459 manifest assets and
  1,223 mapped source files. `build/logs/linker-20261017-152706-162.log` has no errors
  or warnings. Both IWDs (303 and 23 entries) pass integrity checks and match
  their mapped source bytes; loose configs also match their sources.
- Map mirror: all 1,921 indexed files are present under the game's `usermaps/`.
  Two transfer/status errors were recovered. The source supplies lengths, not
  cryptographic checksums; state retains recovery details. Rotation stays explicit.

The test interpreter supports only the source constructs needed by decision
tests, with explicit engine test doubles. It is not a GSC compiler or emulator.
Linking packages text and cannot prove runtime compilation, event scheduling,
HUD presentation or multiplayer behavior.

The latest HUD pass moves XP to the screen edge, adds the generated transparent
ApX logo and native weapon silhouette, replaces bullet ticks with explicit ammo
counts, and compacts practice/health information. Health uses a native HLSL
red/gold/mint palette with actual-loss damage flash and bounded floating feedback.
The isolated `Hud` native suite passed ammo, burst aggregation, healing, feedback
cleanup, spectator and respawn checks:
`build/runtime-tests/20261017-152629-121-mp_backlot/main/qconsole.log`.
The SDK shader registry was restored to its original SHA-256 after the test.

## Runtime verification

The supplied Windows `cod4x18_dedrun.exe` successfully compiles/initializes the
built mod on `mp_backlot` and `mp_deathrun_long` and answers Deathrun status
queries during separate 15-second loopback tests. No fatal script compilation
or runtime errors appear in these successful runs. Logs:

- `build/runtime-tests/20261017-135402-650-mp_backlot/main/qconsole.log`
- `build/runtime-tests/20261017-135425-907-mp_deathrun_long/main/qconsole.log`

The first Long test exposed a missing `maps/createfx/mp_crash_fx.gsc` dependency
in the downloaded map's FX script. The stock SDK script is now explicitly linked,
and the repeat succeeds. Earlier `iw3mp.exe` crashes were from a different local
executable and are not the result of testing the supplied CoD4x server.

`tools/test-runtime.ps1` provides a bounded repeat: isolated home/logs, no private
or public-server config, loopback binding, occupied-port rejection, fatal-log
checking, UDP status verification and cleanup of its own process. Its default
map is Deathrun Long. It does not build automatically or simulate player input.

The supplied runtime still logs unavailable Steam integration (`steam_api.dll`),
an optional `codescripts/delete.gsx` lookup and a missing optional
`CodeCallback_ScriptCommand` label. These do not stop these idle server tests;
external authentication and script-command integration are not verified by them.

Two-client joining, first/free rounds, both selection modes, disconnect/death
during a round, life respawn, map completion, rank/challenge persistence,
retired/locked customization, admin actions and short/empty vote rotations still
need live gameplay verification. Exercise Qube, Mario and Sky Pillar plugin fixes
on their maps. These checks remain necessary before release.

Recovery snapshots are in `.codex-backups/before-maintenance-*.zip` and
`.codex-backups/before-full-refactor-*.zip`, excluded from version control.
They contain local settings and must remain private. This workspace currently
has no Git history; the snapshots preserve pre-edit sources.


## Progression and scoreboard extension

Added 70 levels, 50 prestiges, 120 custom badges, updated tables/localization,
server-validated prestige confirmation and native Tab menu replacement. See
[PROGRESSION.md](PROGRESSION.md) for the profile contract and validation limits.
A real CoD4x test bot passed all 50 transitions, retained lifetime/ability/challenge
stats, rejected duplicate/capped resets and exercised 64-row pagination.

Builds are now incremental per artifact, with content-checked project inputs and
outputs, conservative SDK metadata tracking, changed-only configs, force rebuilds
and state publication after successful output publication. Menu compiler errors
are fatal even when the SDK returns zero. An unchanged real build skipped all
three binaries and all configs in 3.7 seconds. Earlier menu-parser failures were
not caught by the old diagnostics filter; that filter and regression tests were
corrected together with the menu source.

## Image buttons

Added four custom steel/gold button textures and editable SVG/PNG sources.
Shared DR/APX buttons, SDK choice controls and character/weapon/ability selectors
use the artwork. Hover and keyboard focus brighten it; actions use an activated
state. Locked selectors and prestige actions use a muted, noninteractive state.
Hidden DR buttons no longer leave a clickable foreground, and ability casing
reads the saved ability stat instead of comparing player rank against a stat ID.

The real build links all four interface materials; shipped IWI bytes match the
source, and regeneration is byte-for-byte reproducible. The rectangular DXT5
payload decodes successfully with its transparent corners and complete mip chain.
The latest Lithium loading/status smoke test passed on the final build:
`build/runtime-tests/20261017-144035-344-mp_dr_lithium`.
An unchanged build skipped all three binaries and all configs in 4.2 seconds.
Client-side mouse/focus appearance still needs in-game verification.

The scoreboard header now receives the authoritative server `mapname`, avoiding
the stale client map-selection dvar. A regression exercises Lithium followed by
a map change while the client selection stays on Backlot. Button labels now
clear the left chevron in both enabled and disabled states; the hover accent
no longer crosses their upper text area.

All 120 progression badges were regenerated at 512x512 from 1024x1024 artwork,
with lossless BGRA pixels, full mip chains and no picmip reduction. Tests verify
every engine payload against its PNG exactly, plus offsets and material sizes.
The 160 MiB of uncompressed badge mip data compresses into the 25.27 MB main IWD
together with its other assets; all 300 entries pass ZIP integrity checks.

## Admin progression commands

Replaced the added alive-only XP branch, which awarded seven 2,000-XP gameplay
rewards while reporting 4,000, with a dedicated admin progression handler.
`xp`, `setrank`, `setprestige` and full-profile `reset` use the existing trusted
server/RCON dvar route. Input and target validation reject malformed values,
invalid slots and ambiguous names. Player-context calls additionally require
authenticated admin permission `p`. See [ADMINISTRATION.md](ADMINISTRATION.md).

Each mutation synchronizes native rank, saved profile, menu dvars, customization
and integrity mirrors. XP controls bypass free-run/reward restrictions without
inflating lifetime or match score. Reset clears table-owned lifetime stats,
challenge progress, earned abilities, selections and live personal match caches,
then restores fresh challenge availability. Moderation history and camera
settings retain their values.

Six source tests cover all displayed levels and prestige values, bounds, target
ambiguity, real permission checks, lifetime retention and complete reset behavior.
The isolated CoD4x bot fixture also passed the actual server-dvar XP/setrank/
setprestige/reset route, invalid-rank rejection, player permission rejection/
acceptance, profile cache reset and native integrity verification after reset:
`build/runtime-tests/20261017-144952-143-mp_backlot`.

## EFR, HUD and native shaders

Enabled and rebuilt Endless Free Run around the round controller. Participants
include dead teammates; spectators do not count. The start countdown cancels on
population loss. A preserving restart resets registered traps, and a one-use
handoff/grace prevents restart loops. Practice does not consume rounds or award
gameplay XP, challenges or personal bests. Existing first-free-round behavior
and progression remain available. A queued respawn now rejects spectator teams,
fixing an entity/array error exposed by the lifecycle test.

Replaced the inherited HUD layout with compact round, compass, practice status,
health, progression and weapon information. Removed XP ticks and the 854-unit
branch, reduced text sizes/glow within the engine's 1.4 minimum, moved course/life
indicators, and removed the remaining targeted harassment UI. Health and XP
fractions are clamped; a shared service sends changed data only.

Added native HLSL vertex/pixel stages for a subtle static XP-bar finish, a stock
SM2 fallback, and per-stage compiler/cache support using Windows D3DCompiler.
No external compiler executable is downloaded. Failed compilation preserves good
assets; corrupt outputs are repaired. Eleven native compiler assertions pass,
including pixel-only compilation, no-op/force behavior and SDK preservation.
The real SDK shader registry hash matches its pre-build value after restoration.
An unchanged full build skips shaders, three binaries and configs in 5.3 seconds.

The real EFR bot lifecycle test passed practice respawn, dead-player counting,
spectator cancellation, XP/challenge guards and one preserving restart/handoff:
`build/runtime-tests/20261017-150721-223-mp_backlot`.
The progression/admin bot suite still passes with EFR enabled:
`build/runtime-tests/20261017-151014-291-mp_backlot`.
Final in-client layout and GPU appearance need human visual verification.

## Menu system and customization previews

The shared menu generator produces 28 native menu files and 42 routes, including
separate disconnected navigation and themed confirmation dialogs. Primary
contains the existing single-weapon choices; secondary was removed. Fixed-size
catalog pages support name search, unlocked filtering, direct page entry and
inspection selection without growing the number of menu items. Server actions
validate origin, entitlement and equipment unlocks; admin targets bind both slot
and GUID. Core precached pages stay within the native 32-name limit.

Twenty actual game models have packaged 32-view turntables and high-resolution
stills. Rendered camera bounds cover every angle, including the widest pistol
views. Shoulder transforms preserve hierarchy; two ported rigid-attachment models
retain their authored bind poses. Neutral studio lights cover front and back.
These are rendered images played locally by HLSL, not live client geometry.

Client QA exposed three issues dedicated-server bot tests cannot catch. Settings
menus attempted client statset on server-only slots 2400-2404; those writes now
go through validated GSC, while disconnected settings use archived renderer
dvars. Native edit fields lacked the SDK's blank caption, displaying their dvar
twice; both search and page entry now supply it, and server snapshots no longer
overwrite edit buffers. Turntables crossfaded distinct silhouettes, creating
ghost trails; the shader now displays one angle at a time in forward order.

The native menu suite covers saved FOV/fullbright across a preserving restart,
access rejection, stale-target protection, and a fixture containing 100 extra
catalog choices. The 50-test source/asset suite also checks all 640 atlas cells
for content and clipping, registration, offline navigation, popup focus colors,
and native edit/settings contracts. Client mouse/keyboard behavior and GPU
presentation still require in-game QA.

Latest verification: all 50 source/asset tests pass; the menu bot suite passes
at `build/runtime-tests/20261017-170357-875-mp_backlot`; release Lithium loads
at `build/runtime-tests/20261017-170345-056-mp_dr_lithium`. The linker reports
555 manifest assets and 74 packaged scripts without diagnostics. Both IWDs pass
ZIP integrity checks. An unchanged All build skips shaders, both IWDs and the
fastfile, completing in 4.4 seconds.
