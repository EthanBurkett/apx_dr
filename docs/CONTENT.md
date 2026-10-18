# Content catalog

The official-client profile activates 30 primaries, 9 standalone knives/melee items and 80 operators, including existing selections and 102 community additions. The complete imported library (89 primaries, 9 melee items and 104 operators, including 185 community additions) remains in the source workspace. Attribution, source pages and active/inactive status are listed in [CONTENT_CREDITS.md](CONTENT_CREDITS.md) and shipped as `content_credits.txt` inside the client IWD.

## Progression

There are 10 prestiges with 70 levels each. Every prestige has ten content rewards at levels 7, 14, 21, 28, 35, 42, 49, 56, 63 and 70. Base progression retains its original selections and adds the FNC at level 40 and Mandalorian at level 70. Requirements compare prestige first, then level: earlier prestige content remains available, while current prestige rewards require their listed level. The Progression menu includes a tier and page browser for the actual reward table.

`ui/content_profile.json` selects permanent catalog IDs, prestige count, reward milestones and runtime asset budgets. Run `python tools/apply_content_profile.py`, `python tools/generate_menus.py` and `python tools/content_report.py` after changing it. Inactive rows retain their IDs, raw files, renders, provenance and original unlock metadata. They are excluded from the generated browser, community manifest and preview manifests, and are not precached or equipped; saved inactive selections fall back to base equipment. Never reassign their IDs to different content.

`mp/apx_content_unlocks.csv` stores category/ID, prestige and level. GSC converts displayed levels to zero-based ranks. Existing catalog IDs are permanent; retired and moved IDs remain disabled reservations rather than shifting player saves. Four incomplete new ports are quarantined in `ui/content_catalog.json`, retaining provenance and reasons.

## Melee classification

Eight zero-ammo, zero-bullet-damage melee ports were removed from Primary and placed in `mp/knifeTable.csv`: Ballistic Knife, MW2 ending knife, ice pick, Ghosts knife, BO2 knife, Homerun bat, CQB bayonet and street sign. Primary search, primary families and equip validation exclude their reserved former IDs. Each knife has its own static render and 32-angle rotating preview. Tactical-knife/Beretta remains a primary because it is a working firearm.

Knife selection is server-owned stat 2405 and is cleared by full profile reset. Human players carry the selected knife alongside their primary (or the Activator tomahawk). Normal weapon cycling selects it; action slot 2 also selects it directly without rebinding controls. Use the normal melee attack while holding it; these ports do not fire bullets. Spawns start with the primary. Knife-only free runs carry only the knife, including respawns; dog form carries only its bite weapon. Returning to human form restores the current loadout. A firearm's attached melee model remains part of its compiled definition.

Arms use independent server-owned stat 2406: zero follows the operator, and positive IDs are permanent `ui/glove_catalog.json` IDs plus one. The arms browser lists the nine active sets plus the automatic option, reusing existing renders and models. A set unlocks when any active operator using it is unlocked. It applies on the next spawn, survives operator changes and reconnects, and resets with the full profile. Disabled and locked choices fall back to the operator's arms. No new models or textures are loaded.

## Assets and build tools

`ui/content_catalog.json` records download SHA-256, author, source page, category, stable ID and unlock requirement. The download/staging tools retain original archives and readmes below `build/`. Importing accepts raw model, material, animation, weapon and sound data; it rejects conflicting global asset replacements and does not import pack scripts, configs or menus. Sound aliases are namespaced per pack. Camos and per-gun skin variants remain deferred.

Previews are rendered from the installed meshes in Blender with stable glove IDs from `ui/glove_catalog.json`. They are offline 32-angle renders sampled by HLSL, not live skeletal models in the UI. Run prepare_model_assets.py, render_models.py and render_turntables.py in Blender, then package_model_previews.py, package_turntables.py and generate_menus.py after changing the planned catalog. Preserve existing IDs when adding content.

### Texture memory

`ui/texture_budget.json` controls runtime packaging. Full-size still previews use DXT5, with eight portraits or props sharing each material. `package_preview_atlases.py` copies their original 512x1024 / 1024x512 pixels into 2048-square atlases and records cells in `ui/preview_atlas.json`. The shader decodes a constant vertex-red cell index while preserving normal UI alpha; eight mutually exclusive menu items provide the cell selection on the stock client. Both SM2 and SM3 use these stills. This saves 182 material slots for the active collection without reducing still resolution.

Rotating previews retain all 32 views but compile to 1024-square DXT5 atlases. Original PNG renders and 2048-square rotating authoring atlases remain untouched. The combined active preview IWI budget is 512 MiB, checked by the asset tests; the previous full collection consumed about 1.94 GiB in previews alone. This is a texture payload budget, not a measurement of total client RAM or VRAM. `ui/inactive_images.json` excludes inactive/individual preview textures and retired prestige icons from the client IWD while retaining their source files.

Run `python tools/optimize_content_images.py` after importing content and before building. Oversized imported 2D images reuse their existing mip levels up to 1024 pixels, without decoding or recompressing packed normal maps. Originals are SHA-256 backed up under `art/source-images/`; `ui/texture_optimization.json` records the source/runtime hashes and dimensions. Model preparation uses those originals for authoring. Future imports accept only the exact recorded original as an existing optimized dependency; unrelated conflicting textures are still rejected.

Asset counts and texture memory are separate limits. The client launcher requests supported larger image/model/FX/sound pools before loading the mod UI. The official-client profile targets at most 156 weapon definitions and 1900 materials after stock/map assets load, below the fixed client limits of 168 and 2048. `tools/test-runtime.ps1 -Map <map> -ClientBudget` measures and enforces the profile's budgets, including stock/map assets. Each supported map needs that check; a different map can consume more assets. Server pool changes alone do not enlarge the client's fixed pools. Dedicated-server tests do not verify GPU allocation or client rendering.

The stock SDK linker's fixed vertex/index save streams are too small for the combined collection (about 86 MiB vertices and 17 MiB indices). The `cod4-sdk-large-content-v1` build profile verifies the original executable's exact SHA-256, creates a private sibling copy with 128/64 MiB ranges, and deletes it afterward. Only the two capacity constants change; assertions and serialization code remain intact. The original SDK executable is never patched. These are build-time stream limits, not client asset pools or increased weapon limits.

`tools/isolate_content.py` tests batches in a disposable SDK view. Its owned child runs on an unshown desktop so failed SDK assertions cannot interrupt the game. Diagnostic source links are read-only: never edit fixture assets in place. Changes to client pool limits or a dedicated server alone are not a guarantee of client compatibility; the full catalog still requires in-game rendering and multiplayer checks on the supported client.
