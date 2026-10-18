# Tool reference

Paths are relative to the repository root. Python entry points use
`python tools/<name>.py`; PowerShell entry points use `.\tools\<name>.ps1`.
Use Python 3.12+ and [requirements-dev.txt](../requirements-dev.txt) for authoring
and tests. Normal builds only need Windows PowerShell and the installed SDK.

“Source” below means checked-in files change and should be reviewed; “build”
means ignored work data; “dist” means local deployment. Normal builds do not
download content, import packs or regenerate artwork.

## Everyday development

| Entry point | Inputs and dependencies | Outputs / mutation |
| --- | --- | --- |
| `tools/build.ps1` | Project, manifests, hydrated assets, SDK; [options](BUILDING.md) | Fastfile, IWDs and loose configs in dist; state/logs in build |
| `tools/launch.ps1` | Game, built mod; `-Mode Client\|Server`, `-Address`, `-Map`, `-Port`, `-Dedicated`, `-Executable`, `-ServerConfig`, `-ModDirectory`, `-GameRoot` | Starts official client or matching ApX server |
| `tools/check.py` | Python/Pillow; `--suite core\|full`, optional `--game-root` | Repository audit, validator and selected Python tests |
| `tools/repo_audit.py` | Git checkout; optional `--assets` | Index paths, redacted public-credential checks, docs links, tool coverage and optional LFS hydration |
| `tools/validate.py` | Scripts/tables/configs; `--root`, `--game-root`, `--source-only` | Static references/packaging diagnostics; never opens private.cfg |
| `tools/build-server.ps1` | Git, NASM, Windows tar, network for pinned source/compiler; `-GameRoot`, `-Install` | Server EXE, build record and full source ZIP under server; cache/logs in build |
| `tools/download_maps.py` | `--url`, `--destination`, `--state-directory`, `--workers` 1–8 | Explicit mirror download; resumable parts, length checks, atomic replacement and previous-file backups |

A map mirror URL is supplied by the operator. Length checks do not establish
authenticity; retain trusted source/checksum records for distributed maps.

## Verification

| Entry point | Scope | Requirements and outputs |
| --- | --- | --- |
| `tools/test-build.ps1` | SDK transactions, rollback, archives and cache | Windows/.NET Framework C# compiler; fake SDK in build; no real SDK |
| `tools/test-shaders.ps1` | HLSL compile/cache/errors and SM2 contracts | Windows D3D compiler, hydrated inputs; fixtures in build |
| `tools/test-runtime.ps1` | Real-server startup, marker and optional pool budgets | Built mod/server/map; `-Map`, `-Duration` 10–120, `-Port`, `-GameType`, `-RequiredMarker`, `-AssetUsage`, `-ClientBudget`, `-ModDirectory`, `-GameRoot`, `-Executable` |
| `tools/test-progression.ps1` | Bot progression, EFR, HUD, menus, content, traffic or equipment | SDK/server/assets; `-Suite Progression\|Efr\|Hud\|Menus\|Content\|Traffic\|Equipment`; isolated fixture in build; never copies private.cfg |

Native tests use loopback, their own homepath and an owned child process.
Fixtures can require several GB. See [testing](TESTING.md) for coverage limits.

## Catalog discovery and import

| Entry point | Inputs and dependencies | Outputs / mutation |
| --- | --- | --- |
| `tools/content_archive.py` | CFGFactory static archive; `--index`, `--download`, `--limit` (default 200) | Inventory, attribution HTML, metadata and downloads in build/content-cache |
| `tools/content_stage.py` | Cached archive inventory; ZIP or Windows tar | Safe extracted data/dependency inventory in build/content-staging; never executes pack scripts |
| `tools/import_content.py` | Curated staged inventory, stock assets | **Source:** namespaced assets, weapon definitions, append-only catalogs/manifests and provenance; rejects shared-resource conflicts |
| `tools/classify_content.py` | Imported catalog/tables | **Source:** maintenance migration moving melee to Knife and retaining retired IDs; not a routine build step |
| `tools/apply_content_profile.py` | Active profile, full catalog, previews | **Source:** enabled rows, rank/prestige rewards, active manifests, image exclusions and preview tables |
| `tools/content_report.py` | ui/content_catalog.json | **Source:** docs/CONTENT_CREDITS.md and src/content_credits.txt; attribution is not redistribution permission |
| `tools/optimize_content_images.py` | Imported IWIs, texture budget | **Source:** mip-trimmed images, hash/dimension registry and original textures in art/source-images (LFS) |

Import/classification/repair tools have source side effects. Review candidates,
rights and dependency conflicts first. Preserve IDs for disabled/moved content.
See [content workflow](CONTENT-WORKFLOW.md).

## Artwork and model previews

| Entry point | Inputs and dependencies | Outputs / mutation |
| --- | --- | --- |
| `tools/generate_interface.py` | Pillow, brand/background art, material template | **Source:** button SVG/PNG, IWI/materials and interface manifest |
| `tools/generate_progression.py` | Pillow, active prestige count, material template | **Source:** badge art/engine assets, progression tables/localization and manifest |
| `tools/generate_menus.py` | Registry, tables, active profile, preview metadata | **Source:** native menus/routes, UI index, catalog tables and manifest |
| `tools/preview_menus.py` | UI art, menus, labeled sample stats; Pillow | **Source:** art/ui/menus layout proofs; not an engine renderer |
| `tools/render-previews.ps1` | Blender 5.2, Python/Pillow, game/SDK; `-Blender`, `-Python`, `-Force` | Preparation, renders, packaging, shared atlases, active profile and menus; source + build changes |
| `tools/prepare_model_assets.py` | Game raw/main IWDs, active tables, original authoring textures | Read-only hardlinks and jobs in build/model-render; fails on missing originals |
| `tools/render_models.py` | Blender-only, jobs, importer; job keys/`--force` after Blender `--` | Actual-mesh front/back PNGs in art/ui/models; render record in build |
| `tools/render_turntables.py` | Blender-only; same scene inputs/selection arguments | 32-view frames in build/model-render/frames and source turntable artwork |
| `tools/package_model_previews.py` | Still PNGs, Pillow, templates | **Source:** individual preview IWIs/materials/catalog; intermediate, not final shared profile |
| `tools/package_turntables.py` | Frames/Pillow; optional keys such as `character:0` | **Source:** runtime turntable assets and authoring PNG atlases |
| `tools/package_preview_atlases.py` | Active stills, tables, glove registry; Pillow | **Source:** eight-cell 2048-square atlases/mapping; follow with profile and menus |

Normal builds consume checked-in previews without Blender. Default stills and
optional HLSL turntables are pre-rendered actual assets, not live 3D geometry.
Shoulder hierarchy and neutral lighting are authored in the Blender scripts.

The wrapper downloads importer v3.5 from
[mauserzjeh/cod-asset-importer](https://github.com/mauserzjeh/cod-asset-importer)
only into build and verifies its pinned SHA-256. See its
[GPL notice](../tools/licenses/cod-asset-importer.txt).
Rendering uses a factory-startup background scene, not an open Blender project.

## Diagnostics and repair

| Entry point | Inputs and dependencies | Outputs / mutation |
| --- | --- | --- |
| `tools/isolate_content.py` | SDK/assets; `--kind weapon\|xmodel\|sound\|all`, `--batch`, `--start`, `--refresh`, `--combined` | Dependency/link batches, logs and results.jsonl in build/content-linker; read-only hardlink views |
| `tools/repair_content.py` | Positional linker-log path, staged packs | **Source:** repaired dependencies/quarantined entries; review changes and rerun profile/budgets |
| `tools/ContentLinkerHost.cs` | Compiled by isolation tool | Hidden desktop linker host/captured diagnostics; avoids interactive assertion dialogs |
| `tools/iwi2dds.exe` | Legacy Windows IWI converter | DDS authoring conversion; unresolved provenance/license (see licensing guide) |

Do not edit hardlinked files in diagnostic/authoring views: that edits source
data too. Repair tools are not automatically run after release-build failure.

## Shared implementation modules

| Module | Responsibility |
| --- | --- |
| `tools/gsc.py` | Import-only lexer/masking and function extraction |
| `tools/menu_catalog_data.py` | Catalog metadata, stable arms labels and browser data |
| `tools/menu_showcase.py` | Generated loadout/catalog layouts |
| `tools/build/Project.ps1` | Project paths/source mappings |
| `tools/build/Manifest.ps1` | Manifest plan/input validation |
| `tools/build/Archives.ps1` | Deterministic archives and loose configs |
| `tools/build/Linker.ps1` | SDK transaction/linker process |
| `tools/build/Publish.ps1` | Artifact publication/rollback |
| `tools/build/Cache.ps1` | Incremental fingerprints |
| `tools/build/Shaders.ps1` | Native HLSL compile/cache/registry |
| `tools/build/Shaders.cs` | D3D compiler bridge |

The audit checks that every maintained .py/.ps1/.cs file under tools appears here.
Add documentation when adding a tool.
