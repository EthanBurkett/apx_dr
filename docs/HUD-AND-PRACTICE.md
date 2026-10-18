# ApX HUD and Endless Free Run

EFR is enabled by default. It provides endless practice at round setup until
enough players have joined a team. Dead teammates still count; spectators do not.
Practice has free respawns and disabled registered traps, while allowing selected equipment.
It awards no gameplay XP, challenges or personal best course records. Admin
progression commands remain available for testing.

```cfg
set plugin_efr_enable 1
set plugin_efr_minplayers 3
set plugin_efr_restarttime 5
```

Settings live in `config/deathrun/rounds.cfg`. EFR also respects `dr_usePlugins`.
The start countdown requires enough participants continuously. Dropping below
the threshold cancels it. On completion, one preserving map restart resets traps
and practice state without consuming a round or resetting profiles. A one-use
handoff and reconnection grace avoid a restart loop. The normal first free round,
round limit and activator selection still run afterward. Existing competitive
rounds finish normally; EFR decides whether practice is needed at round setup.
Setting `plugin_efr_enable 0` during practice exits through a clean restart.

`plugins/_efr.gsc` owns practice and its countdown. `_rounds::gameLogic` calls it
before normal round startup. Plugins initialize before round logic begins.
This replaces the old delayed thread that killed the normal controller, counted
only living players and could stop processing during the first free round.

The HUD uses the 640x480 virtual canvas:

- Top left: transparent steel/gold ApX logo and small current-mode label.
- Top center: small practice population/countdown; the compass is removed.
- Top right: small round, timer, surviving jumpers and life indicators.
- Bottom left: compact health label/bar and course time above it.
- Bottom edge: continuous three-unit XP fill; small rank/prestige info above it.
- Bottom right: native weapon silhouette, numeric clip/reserve counts and offhands.

The weapon icon ownerdraw expects a square base rectangle. It expands width by
the weapon definition's 1:1, 2:1 or 4:1 icon ratio and shifts left to retain the
right edge. The 24x24 base at X=592 therefore produces 24/48/96x24 silhouettes
ending at X=616. Supplying an already-wide rectangle applies the ratio twice.

The XP ticks and alternate 854-unit layout have been removed. The bar fraction
is clamped, handles empty/corrupt XP ranges safely and updates correctly after
admin changes, reset, prestige and healing. `_hud_state.gsc` checks state ten
times per second and sends only changed values. Menu includes own visual layout;
the existing server timer handles remain available to round/map integrations.
The old health updater is a compatibility initializer for the shared service.

Server font scales respect CoD4's 1.4 minimum. Text glow, oversized timers and the
inherited targeted harassment overlay have been removed. Gameplay hints,
action slots, offhand ammo and messages retain their engine ownerdraws. The
scoreboard and end-of-map flow hide the new menu HUD.

The XP fill has a small static HLSL metallic ridge. The health shader smoothly
changes from red through gold to mint with health. Actual health loss triggers a
350 ms local bar flash and a 650 ms floating negative number. Rapid hits within
250 ms accumulate into one number. Healing, max-health changes and spawning do
not produce damage feedback. `_hud_damage.gsc` bounds the lifetime of its single
client element and clears it on respawn. There is no scene-wide shader effect.
See [SHADERS.md](SHADERS.md) for the native shader pipeline.

The generated logo source is `art/brand/apx-logo.png`. The interface generator
preserves that transparent PNG, fits it to a 512x256 lossless, mipmapped IWI and
registers its material in `manifests/13-interface.csv`.
`components/brand.inc` shares the logo across the HUD, scoreboard, menu footer,
main menu, About popup, notice overlay and prestige header. Server browser names
and chat messages remain text because those channels do not draw menu materials.

Verification includes source tests for participant counts/countdown cancellation
and bar bounds. The isolated `tools/test-progression.ps1 -Suite Efr` checks real
bot respawn, spectator transitions, XP/challenge guards, countdown cancellation,
one preserving restart and successful handoff. The normal progression suite
still checks every prestige and the admin controls. Final HUD appearance requires
a connected game client; dedicated-server checks do not exercise the GPU/UI.
`tools/test-progression.ps1 -Suite Hud` separately exercises native ammo reads,
burst damage, healing, transient cleanup, spectator hiding and spawn baselines.
