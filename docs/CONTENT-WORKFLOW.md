# Content and preview workflow

The repository retains the full import library. Runtime uses the smaller
official-client profile in `ui/content_profile.json`. Do not enable every import:
weapon/material pools are shared with map dependencies on the client.

## Sources of truth

| Location | Role |
| --- | --- |
| `ui/content_catalog.json` | IDs, source pages/authors, archive hashes, quarantine/move history |
| `ui/content_profile.json` | Enabled content and ten rank gates per prestige |
| `src/mp/*Table.csv` | Stable persistent IDs and runtime definitions |
| `ui/glove_catalog.json` | Stable arms IDs; zero saved selection follows the operator |
| `ui/texture_budget.json` | Runtime texture policy |
| `ui/texture_optimization.json` | Original/runtime hashes and dimensions |
| `art/source-images/` | Full original optimized-texture inputs, SHA-256 named in LFS |
| `ui/preview_atlas.json` | Generated still-atlas material/cell mapping |
| `ui/inactive_images.json` | Generated archive exclusions |

Never renumber IDs to close gaps. Disabled, quarantined and moved entries retain
history. Melee belongs in Knife, not Primary. One firearm is carried with the
selected knife as secondary.

## Discover and stage

```powershell
python tools/content_archive.py --index
python tools/content_archive.py --download --limit 10
python tools/content_stage.py
```

Downloads/extracted archives stay in build. Review attribution, redistribution
terms and model/animation dependencies before importing. The stager treats packs
as data and does not execute supplied scripts.

CFGFactory pages establish provenance, not permission. Record a license or
written permission before public distribution. See [licensing](LICENSING.md).

## Import and curate

```powershell
python tools/import_content.py
python tools/optimize_content_images.py
```

These mutate source assets/registries. Inspect the Git diff and reports.
Conflicting shared resources are rejected instead of replacing stock data.
The optimizer reuses compressed mip payloads under the runtime budget and keeps
full originals in LFS for future rendering.

Edit the active profile deliberately, then run:

```powershell
python tools/apply_content_profile.py
python tools/content_report.py
```

The profile must fill five prestiges × ten ranks: 7, 14, 21, 28, 35, 42, 49, 56,
63 and 70. Earlier prestige content stays available. Arms access derives from
unlocked active operators using that model.

Newly enabled items need previews before profile finalization. Prepare/render
missing jobs first, then repeat profile generation. The classification migration
is only needed for miscategorized melee; do not routinely rerun migrations.

## Render real assets

```powershell
.\tools\render-previews.ps1
# Regenerate existing views too:
.\tools\render-previews.ps1 -Force
```

The wrapper prepares a read-only hardlink asset view, obtains the pinned importer,
runs isolated Blender still/32-angle renders, packages turntables and individual
previews, builds shared still atlases, reapplies the profile and regenerates menus.

Original authoring textures live in `art/source-images/`. Older workspaces can
use the compatibility fallback `build/content-original-images/`. Missing/damaged
originals fail explicitly. Never edit hardlinked build views.

For selective authoring, pass job keys after Blender's `--`:

```powershell
python tools/prepare_model_assets.py
blender --background --factory-startup --python-exit-code 1 --python tools/render_models.py -- character:0 --force
blender --background --factory-startup --python-exit-code 1 --python tools/render_turntables.py -- character:0 --force
```

The wrapper must install the importer first. Finish selective work with the
packaging/profile/menu steps in [tooling](TOOLING.md). Frames are build data:
packaging a fresh turntable requires rendering frames.

Still view is default, with full-resolution cells in shared 2048-square atlases.
Optional rotation samples pre-rendered angles in HLSL, not live 3D geometry.

## Validate and measure

```powershell
python tools/check.py --suite full
.\tools\build.ps1
.\tools\build-client-audit.ps1
.\tools\test-runtime.ps1 -Map mp_backlot -Duration 20 -AssetUsage -ClientBudget
.\tools\test-progression.ps1 -Suite Content
.\tools\test-progression.ps1 -Suite Equipment
```

Repeat pool checks on every supported map. The enlarged linker and custom server
do not remove official client limits. A successful link does not prove client
memory headroom or animation quality. Inspect new items in the official client.

See [content](CONTENT.md) for budgets and [releasing](RELEASING.md) for packaging.
