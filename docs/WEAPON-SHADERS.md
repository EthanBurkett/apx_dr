# Native weapon shaders

The base-weapon shader route starts with **Beretta M9 / RIFTHEART**. Selecting the
normal Beretta equips the treatment automatically; no extra weapon variant or
progression ID is created. Other base guns and the default knife can be added
through this pipeline in later passes.

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

## Verification

Tests check scoped model changes, retained gameplay fields, repeatable camo data,
material pointer/sampler layout, lighting-state selection and SM2 fallback.
Windows CI compiles the real weapon stages in the native HLSL suite without
requiring the proprietary SDK. SDK linking and map startup/pool checks remain
local; final client appearance should be checked under the intended map lighting,
Fullbright, shadow options, ADS, firing and reload animations.

Reference material: [CoD4 shader pipeline](https://xoxor4d.github.io/tutorials/hlsl-intro/)
and [weapon-technique selection](https://github.com/xoxor4d/cod4-shader-reversed-weapon).
The shader implementation is original ApX code; installed stock assets retain
their existing rights. See [licensing](LICENSING.md).
