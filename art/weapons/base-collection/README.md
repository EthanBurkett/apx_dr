# Base weapon shader collection

`collection.png` shows native D3D9 renders of the actual eight base primary
meshes. The seven new effects each have an independent procedural pixel shader.
The M9's original RIFTHEART treatment is retained.

Custom surfaces use the actual HLSL. Protected lenses/attachments use a simple
stock-material studio approximation in this renderer; the game retains their
original materials. These are GPU previews, not in-game screenshots.

See [the shader guide](../../../docs/WEAPON-SHADERS.md) for generation, previews,
technique selection, budgets, original-definition snapshots and verification.
