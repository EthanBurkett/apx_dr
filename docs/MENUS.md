# ApX menus and model previews

All layout uses CoD4's 640x480 virtual canvas. Fullscreen background art uses
the engine's fullscreen alignment so widescreen clients do not get black edges.

## Player flow

The offline main menu provides server browsing/hosting, profiles, settings,
controls, credits, mods and quit. Its settings navigation only opens offline
pages. In-server navigation adds the run overview, loadout, progression,
challenges, field guide and entitled VIP/admin pages. Client visibility is a
convenience; the server checks entitlement again on every privileged action.

Loadout has a dedicated operator showcase, the saved **Primary**, knife and
independently selectable arms. Every firearm belongs to Primary (stat 981),
with the selected knife carried as the secondary (stat 2405). Selecting
equipment saves it for the next spawn. Browsing an item does not equip it.
The Equipment tab in Controls exposes normal weapon cycling and a direct knife
selection binding (action slot 2), alongside insertion and night vision.

The customization browser uses eight result rows at every catalog size. It
supports name search, All/Unlocked filters, direct page entry, and previous/next
selection across the complete filtered result. Empty results have a defined
state. The server owns the result IDs, page and inspected ID; Equip revalidates
the real unlock rule. Retired character IDs stay reserved and cannot be equipped.

Character, primary, knife and arms selection pages default to high-resolution
stills. Rotate view remains available as an explicit option.
These are **pre-rendered 360-degree turntables of the installed meshes**, not
live geometry or an orbit camera. A native HLSL material advances through 32 angles over
four seconds, displaying one view at a time to avoid overlapping silhouettes. Still view uses the high-resolution PNG render. Per-frame rotation
runs on the client GPU; GSC only updates the selected material after interaction.
Shader Model 2 clients use the still-image branch. Knife, arms and prestige rewards
are registered for server-driven opening, so they load in-game independently of
the offline UI index.

The Tab scoreboard keeps its normal score-key behavior and has no mouse buttons.
Leave, quit, prestige, reset and moderation confirmations have explicit focus
colors and cancel-first focus. The main menu restores native scoreboard dimensions
after disconnecting from the mod.

## Source ownership and packaging

| File | Owns |
| --- | --- |
| `ui/menu_catalog.json` | Navigation and loadout section registry |
| `tools/generate_menus.py` | Main, overview, settings, controls, progression, challenges, privileged pages and dialogs |
| `tools/menu_showcase.py` | Loadout and inspection/browser layouts |
| `tools/menu_catalog_data.py` | Searchable catalog metadata and readable stock names |
| `src/ui_mp/components/shell.inc` | Shared typography, surfaces, image/button placement |
| `src/ui_mp/components/buttons.inc` | Hover, focus and activation behavior |
| `tools/generate_interface.py` | Button geometry, logo/HUD materials and background packaging |
| `src/braxi/_menus.gsc` | Validated response envelope and legacy dispatch |
| `src/braxi/_menu_service.gsc` | Access checks, preferences, VIP and admin controls |
| `src/braxi/_menu_browser.gsc` | Search/filter/page/inspection state |
| `src/braxi/_menu_catalog.gsc` | Authoritative unlock snapshots and equip validation |
| `src/braxi/_preferences.gsc` | Persistent presentation preferences |

Edit the generators rather than generated `.menu` files. Run:

```powershell
python tools/generate_menus.py
python tools/generate_interface.py  # only after changing artwork/generator
.\tools\build.ps1
```

The generator registers menu files in `manifests/07-menus.csv`, the client index
`src/ui_mp/menus.txt`, and access metadata `mp/apx_menu_routes.csv`. The index is
also packaged as a rawfile. Script imports alone do not register or package menus.

CoD4 has 32 server-registered menu names. Keep `precacheMenu` for core pages the
server actually opens. Native browser/profile/utility menu files are explicitly
relinked against the shared ApX wrappers, rather than relying on their older
precompiled common-fastfile versions. Additional pages load through the global client index and
use native `scriptMenuResponse` with a bounded `ui:<page>:<payload>` envelope.
The native handler uses index -1 for unregistered pages. GSC validates the declared
origin and access before dispatch. This does not increase the stock configstring
limit and does not require a server fork.

Search/page fields use CoD4x user cvars, documented in the
[CoD4x function reference](https://github.com/callofduty4x/CoD4x_Server/blob/master/scriptdocumentation/script_functions_reference.md#getuserinfostring-variable_name).
The client registers them with `setu`; the server reads `getUserinfo`. Both edit
fields have an explicit blank caption, matching the SDK: an absent caption makes
the native caption painter display the dvar again before the editable value.
Edit buffers belong to the client and are never overwritten by result snapshots.
Search is
bounded to 32 characters and page values are parsed and clamped. Catalog text is
never executed as a command. The source catalog preserves IDs and metadata under
`mp/apx_catalog.csv`; adding characters does not add menu pages or menu items.

## Saved preferences and privileges

| Stat | Meaning |
| --- | --- |
| 2400 | Presentation schema version, currently 1 |
| 2401 | FOV, 65-120; default 90 |
| 2402 | Fullbright, 0/1 |
| 2403 | FPS counter, 0/1 |
| 2404 | Minimal HUD, 0/1 |
| 2405 | Knife secondary selection, server validated |
| 2406 | Independent arms; zero follows operator, server validated |
| 988 | Existing third-person preference |

Stock FOV uses `cg_fov 80` plus `cg_fovScale = desired/80`. Preferences are
sanitized and reapplied on connect and survive prestige/profile progression
resets. Minimal HUD hides the decorative logo/XP presentation while retaining
health, ammo and round essentials. Controls use native binding items and the
game profile's binding persistence.

Slots 2400-2405 are server-only. Connected menus send validated preference
requests to GSC and display its synchronized dvars; they never run client
`statset`. Main-menu settings use archived client renderer dvars independently
of the server profile. Connecting restores the server's saved preferences.

Admin navigation follows authenticated `pers["admin"]`; each action still checks
its existing permission. Progression tools require `p`. Admin targets bind both
client slot and GUID so a disconnect/reused slot cannot redirect an action.
Reset confirmations are one-use and expire after 30 seconds.

VIP navigation follows server-owned `pers["vip"]`. Existing integrations can
set that flag; alternatively configure `apx_vip_guids` as semicolon-separated
full GUIDs in private server settings. Shared GUID `0` is ignored. Authenticated
admin accounts can explicitly receive permission `v` to grant VIP without relying
on a GUID (useful for local testing). VIP cosmetics recheck entitlement on use.

## Actual model art pipeline

The normal incremental build consumes generated IWI/material files and does not
require Python or Blender. Art regeneration is an optional authoring operation:

```powershell
.\tools\render-previews.ps1 -Python python
.\tools\render-previews.ps1 -Python python -Force  # changed source meshes/lighting
.\tools\build.ps1
```

`-Blender` selects a Blender executable; the default is the local Blender 5.2
installation. The pinned importer archive is downloaded into `build/model-render`
and checked against its SHA256 before extraction. No add-on is installed into
the user's Blender preferences, and no live Blender scene is modified.

`prepare_model_assets.py` creates a read-only hardlink view of SDK/project meshes,
materials and images, and extracts referenced textures from installed IWDs.
Never edit that hardlink view: it shares files with the SDK/project. Weapon world
models come from the real weapon definitions, including definitions in stock IWDs.
Enabled character rows supply body/arms models. A corrected joint-direction pose
preserves the shoulder hierarchy. Juggernaut and 50 Cent retain their authored
bind poses to preserve rigid attachments (configured in
`ui/model_render_profiles.json`); neutral softboxes illuminate both sides.

`render_models.py` outputs portrait 512x1024 and landscape 1024x512 stills.
`render_turntables.py` outputs 32 angles per model. `package_model_previews.py`
writes lossless BGRA still textures and lookup tables. `package_turntables.py`
assembles 2048x2048 DXT5 atlases, with separate tall/wide shader layouts. The
shader selects one cell per 125 ms and insets cell UVs to protect silhouettes.
Adjacent viewing angles are not crossfaded: that produces double limbs rather
than actual intermediate poses. The preview is a discrete turntable, not live 3D.
UI text and progression badges are never packed into these lossy atlases.

Materials are declared in manifests 14 and 15, tables in manifest 04, and images
ship in `apx_dr.iwd`. The original mesh/texture credits remain in the base mod.
Importer: [Soma Rádóczi's CoD Asset Importer 3.5.0](https://github.com/mauserzjeh/cod-asset-importer),
GPL-3.0; license copy under `tools/licenses/`. It is a development dependency.

The main menu background is separate generated environment artwork, not a
character preview. Its source and generation prompt are in `art/ui/menus/`.

## Verification

```powershell
python tools/validate.py
python -m unittest discover -s tests
.\tools\test-progression.ps1 -Suite Menus
.\tools\test-runtime.ps1 -Map mp_dr_lithium
```

The native menu fixture adds 100 synthetic locked choices only to its isolated
catalog. It checks search, direct final-page selection and wrapping, plus saved
preferences, malformed inputs, retired/locked equipment, privileged access,
stale admin target identity and restart persistence. It never modifies human
profiles. Linker/server tests cannot prove mouse rendering or GPU animation.
`tools/preview_menus.py` is only an offline coordinate proof using sample data.
Final client mouse, layout, shader and animation checks remain necessary.

`tools/test-progression.ps1 -Suite Equipment` checks all nine knife/primary
inventories, native selection-command acceptance, all nine independent arms
sets, respawns, unlock rejection, dog/round restrictions, and reward navigation.
Bot draw state is set explicitly: bots do not execute the human client's weapon
cycling and animation path. Verify actual cycling and melee input on the client.
Runtime test mod paths must fit the engine's 63-character `fs_game` limit.

Menu snapshots must stay bounded by the visible page. The retired full-catalog
unlock broadcast sent over 200 individual dvar commands at the first menu open,
exceeding the real client's 128-entry reliable-command queue. No menu consumes
those flags now; unlock checks remain server-owned and browsers publish only
eight rows plus the selected item. Overview metadata sends once per map.
`tests/test_menu_traffic.py` counts actual GSC sends with large catalogs and
checks packet size. `tools/test-progression.ps1 -Suite Traffic` exercises repeated
native menu envelopes and all browser categories. Native bots bypass the
reliable-command queue, so bot survival alone is not a network-overflow test.
