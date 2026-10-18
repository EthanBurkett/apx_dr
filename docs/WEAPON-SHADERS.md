# Native weapon shaders

The base-weapon shader route starts with **Beretta M9 / RIFTHEART**. Selecting the
normal Beretta equips the treatment automatically; no extra weapon variant or
progression ID is created. All eight base primaries in the current catalog now
have separate treatments, and the default knife uses **PHASEWIRE**.

## Base collection

![Native GPU previews of all eight base primaries](../art/weapons/base-collection/collection.png)

| Base primary | Treatment | Motion and surface |
| --- | --- | --- |
| Beretta M9 | RIFTHEART | Dimensional plasma, fractures and circuitry |
| Colt M1911 | INKBOUND | Black flowing ink over porcelain, moving red sigils |
| USP .45 | GHOST CIRCUIT | Open green holographic scan bands and telemetry |
| Desert Eagle | SOLARFORGE | Molten rivers, coal crust and solar shock rings |
| M40A3 | ABSOLUTE ZERO | Ice facets, sixfold frost stars and freezing fronts |
| Gold Desert Eagle | MIDAS PARADOX | Counter-rotating gold clockwork on black enamel |
| Remington 700 | EVENT HORIZON | Deep parallax starfields, recessed black cores and lensed accretion disks |
| Colt Anaconda .44 | STORMCOIL | Branching electrical arcs and moving charge packets |

These are separate pixel programs with different procedural structures, not
palette variants. The collection generator retains all original weapon fields
except the two scoped view/world model references. Damage, ammo, animations,
hands, melee, scope lenses, reticles and progression IDs are preserved.
Community primaries keep their existing materials.

### EVENT HORIZON depth

The Remington 700 treats its surface like a window into a cosmic volume.
Foreground dust, nebula clouds, distant stars and the black-hole core occupy
different simulated depths. A tangent frame derived from mesh/UV derivatives
offsets each layer according to the viewing direction, including mirrored UV
islands. The metallic shell stays surface-bound while the interior shifts.
The accretion disk bends the distant starfield around a dark recessed core;
antialiased stars and a photon ring keep small details readable in motion.

This is view-dependent layered parallax, not displaced geometry or a ray-marched
volume. It remains active with time frozen. First-person sway, ADS and reloads
change the gun's relative viewing angle; turning the camera and gun together
does not supply absolute world-motion tracking. No GSC updates, new textures,
material registrations or weapon IDs are needed. Grazing-angle offsets are
bounded, and collapsed UV triangles safely fall back to zero parallax.

The seven additional primaries and Activator tomahawk use ten scoped materials
and sixteen model assets, with no new camo images. The USP body/laser housing and M40 body/scope
housing retain separate diffuse maps. Protected lenses, sights, bullets and
attachment masks are excluded from material substitution. GHOST CIRCUIT uses
transparent sorting and omits opaque depth/shadow passes; the other new effects
keep the stock opaque depth, shadow and additional-light paths. Both model
technique prefixes and SM/HSM paths are provided. SM2 retains stock appearance
for these primaries.

New body materials are loaded through the scoped models' dependencies. The
manifest intentionally omits standalone registrations, which would allocate
additional unused non-model variants from the official client's material pool.

The Activator's tomahawk receives **BLOOD MOON**, with moving lunar crescents,
eclipse rings and a beating red metallic surface. It keeps its original gameplay
and has no primary-browser tile or new unlock ID.

![BLOOD MOON tomahawk, native GPU preview](../art/weapons/base-collection/tomahawk.png)

```powershell
python tools/generate_base_weapon_shaders.py
.\tools\render-previews.ps1 -PrepareOnly
blender --background --factory-startup --python-exit-code 1 --python tools/export_weapon_shader_mesh.py -- --all
python tools/preview_weapon_shader.py --effect midas --output build/shader-lab/midas.png
.\tools\test-shaders.ps1
.\tools\build.ps1
```

`generate_base_weapon_shaders.py` is the authoring source for the generated
`ps_3_0_apx_base_*.hlsl` programs. The common lighting helpers are shared; each
effect has its own body. Original definitions in `art/weapons/base-definitions`
provide an offline gameplay-preservation audit. They and installed game assets
retain their original rights. The registry/manifest writer preserves the M9 and
knife entries when regenerating the collection.

The GPU exporter separates material batches. Actual custom HLSL is used on
treated surfaces; protected surfaces use a simple studio approximation of their
stock diffuse/lighting response in the authoring renderer. In-game protected
materials retain the original engine techniques. These previews are not client
screenshots and do not replace checks on intended maps, ADS, firing and reload.

![RIFTHEART, rendered from the actual M9 mesh and HLSL](../art/weapons/beretta-rift/showcase.png)

[Animated GPU preview](../art/weapons/beretta-rift/showcase.gif)

## The effect

RIFTHEART combines an obsidian metallic surface with three independently moving
plasma layers, view-dependent parallax, luminous cellular fractures, pulsing
micro-circuitry and traveling energy sweeps. A second additive pass supplies a
transparent chromatic clearcoat. The weapon body remains opaque; the dimensional
glass is a layered shading effect, not holes through the gun or ray tracing.
Map reflection probes and model ambient lighting provide environmental response.

Animation reads the native gameTime constant. It does not run a GSC animation
loop or send per-frame network updates. Hands, iron sights, animations, damage,
ammo and weapon identity retain their stock definitions. The scoped view/world
models replace only the M9's body material. Stock materials are not globally
overwritten.

## Files and budgets

| Location | Responsibility |
| --- | --- |
| `ui/weapon_shaders.json` | Current per-base-weapon treatment registry |
| `src/weapons/mp/beretta_mp` | Stock weapon definition with scoped view/world models |
| `assets/xmodel/apx_m9_rift_view`, `apx_m9_rift_world` | Original model binaries with equal-length body-material substitution |
| `assets/materials/apx_m9_rift_chrome` | Original material flags/constants, relocated texture table and camo sampler |
| `art/weapons/beretta-rift/camo-fields.png` | Seeded editable RGBA turbulence/circuit/fault fields |
| `assets/images/apx_m9_rift_fields.iwi` | 512-square BGRA data texture with mips |
| `src/shaders/*apx_rift*.hlsl` | One packed-model vertex stage and two pixel stages |
| `assets/techsets/*apxrift*` | SM/HSM and model-prefixed technique selection |
| `assets/statemaps/apx_weapon_corona.sm` | Additive clearcoat with depth writes disabled |
| `manifests/18-weapon-shaders.csv` | Material and scoped-model declarations |

This adds one runtime material, one data texture and two scoped models, while
keeping the existing weapon ID. SM3 full-color paths use the effect. Stock
depth/shadow/debug and additional-light passes remain, and SM2 techsets retain
the original M9 appearance.

CoD4 model vertices are not HUD vertices: UVs are packed half floats and normals
are packed bytes. The shader decodes those streams before transforming with the
camera-relative world matrix. A HUD vertex shader used on this mesh will not work.

## Authoring

Normal builds consume the checked-in assets. Regenerate the treatment explicitly:

```powershell
python tools/generate_weapon_shaders.py
.\tools\test-shaders.ps1
.\tools\build.ps1
```

The generator requires the installed SDK/game and Pillow. It reads stock inputs
without editing the SDK. Its deterministic fields and equal-length material
substitution keep regeneration reviewable.

For native GPU previewing without launching CoD4:

```powershell
.\tools\render-previews.ps1 -PrepareOnly
blender --background --factory-startup --python-exit-code 1 --python tools/export_weapon_shader_mesh.py
python tools/preview_weapon_shader.py --output build/shader-lab/rift-preview.png
python tools/preview_weapon_shader.py --frames 72 --fps 24
python tools/preview_weapon_shader.py --turntable --width 512 --frames-directory build/model-render/frames/apx_turn_weapon_0
```

The exporter uses the pinned Blender importer to obtain real mesh vertices.
The Windows preview tool creates an invisible D3D9 window/device, compiles the
same HLSL with the same native compiler options, binds packed vertex data and
renders both passes. It uses controlled studio ambient/reflection textures:
this verifies shader behavior, UVs and temporal stability, not an in-game
screenshot or every map's lighting.

`render-previews.ps1` performs the native shader override after Blender renders
and before atlas packaging, so the M9 catalog still and optional turntable match.
Still view remains the default.

## Default knife / PHASEWIRE

![Actual default knife mesh with PHASEWIRE](../art/weapons/knife-phasewire/showcase.png)

[Animated native GPU preview](../art/weapons/knife-phasewire/showcase.gif)

The old `knife_mp` used `tag_origin` as its gun model and claymore holding
animations. It therefore showed empty hands while selected. The held knife now
uses the original CoD4 knife geometry, with its root renamed from `tag_knife` to
`j_gun` to match the already imported BO2 knife idle, draw, sprint and melee
animations. Independent arms still use the normal hand override. The stock SDK
files and knife materials used by other weapons are not modified.

PHASEWIRE renders thick, antialiased edges of the actual mesh triangles.
Vertices are split per triangle, with barycentric basis coordinates stored in
the texture UV stream. This avoids depending on vertex colors that can be
replaced by the game's viewmodel draw path. The pixel shader discards triangle interiors; no opaque depth
prepass, shadow silhouette or stock additional-light pass fills the gaps.
Both faces are visible, with additive rainbow wires and native gameTime animation.
The material uses transparent sorting/default-state metadata, and supplies both
model and model-with-vertex-color technique variants.
It adds a scoped material and two model assets, with no new image or weapon ID.

The blade and guard smoothly change between pseudorandom scales from 0.72 to
1.62, with a new target every 1.39 seconds. The grip remains anchored inside the
hand. This is visual vertex displacement: melee damage, reach and inventory
rules are unchanged. Model culling bounds cover the growth. SM2 retains the
animated transparent triangle wires with a fixed relative line width; SM3 uses
screen derivatives for a consistent pixel width.

Regenerate or inspect explicitly:

```powershell
python tools/generate_knife_shader.py
.\tools\render-previews.ps1 -PrepareOnly
blender --background --factory-startup --python-exit-code 1 --python tools/export_weapon_shader_mesh.py -- --effect phasewire
python tools/preview_weapon_shader.py --effect phasewire --frames 96 --fps 24 --start-time 0 --frames-directory build/shader-lab/knife-animation
```

Normal preview authoring replaces both the knife's still and optional turntable
with native D3D9 shader renders before atlas packaging. The shared registry writer
preserves other weapon treatments when either generator is rerun.

## Verification

Tests check scoped model changes, retained gameplay fields, repeatable camo data,
material pointer/sampler layout, lighting-state selection and SM2 fallback.
Knife tests also verify triangle topology/attributes, UV barycentric expansion,
root/animation compatibility, visible holding definitions and transparent paths.
Windows CI compiles the real weapon stages in the native HLSL suite without
requiring the proprietary SDK. SDK linking and map startup/pool checks remain
local; final client appearance should be checked under the intended map lighting,
Fullbright, shadow options, ADS, firing and reload animations.

Reference material: [CoD4 shader pipeline](https://xoxor4d.github.io/tutorials/hlsl-intro/)
and [weapon-technique selection](https://github.com/xoxor4d/cod4-shader-reversed-weapon).
The shader implementation is original ApX code; installed stock assets retain
their existing rights. See [licensing](LICENSING.md).
