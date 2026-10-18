# PHASEWIRE

The original installed CoD4 knife mesh, rendered with ApX's native HLSL wireframe.
The PNG and GIF are actual D3D9 GPU previews with an isolated studio camera, not
in-game screenshots. The GIF demonstrates continuous color changes and irregular
blade growth; its short demonstration loop resets at the end.

The shader uses per-triangle barycentric UV coordinates instead of a camo texture.
Triangle interiors are genuinely transparent. The source geometry and imported
BO2 grip animations retain their existing rights and provenance. The shader and
authoring tools are original ApX code. See [the implementation guide](../../../docs/WEAPON-SHADERS.md).
