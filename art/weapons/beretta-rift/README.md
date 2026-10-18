# RIFTHEART / Beretta M9

The camo's RGBA fields are generated deterministically by
tools/generate_weapon_shaders.py. Channels store two turbulence bands, circuit
traces and cellular fracture edges; they are data, not a finished diffuse skin.

showcase.png and showcase.gif were rendered on the actual stock M9 world mesh
using the native D3D9 HLSL stages and a controlled studio lighting environment.
They are GPU previews, not screenshots captured inside CoD4.

The in-game material reads engine time continuously. The GIF is a short looping
preview. Hands, sights and gameplay definitions are preserved.

See docs/WEAPON-SHADERS.md for generation, native previewing and pipeline details.
