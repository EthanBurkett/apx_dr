# Troubleshooting

## Tiny image/material files

LFS payloads are missing. Run `git lfs pull`, `git lfs fsck` and
`python tools/repo_audit.py --assets`. Source-only CI leaves pointers deliberately.
Source ZIP downloads may contain pointers too.

## Linker stream assertion in db_stream_save.cpp

The SDK content stream can overflow before writing a fastfile. Use the maintained
builder and its verified private large-content linker. Do not overwrite the stock
linker or accept a partial fastfile. Logs/recovery data live in build.
Client pools remain separate.

## Exceeded weapon, material, image or FX assets

The custom server expands its own pools; official-client weapon/material limits
remain fixed. Restore `ui/content_profile.json` and use the supported client
overrides through `launch.ps1`. Run map-specific `-AssetUsage -ClientBudget`
checks. A different map can push a fitting profile over a shared pool.

## Create2DTexture / ran out of memory

Pool counts do not add GPU/address-space memory. Apply the runtime texture policy
after imports, keep turntable atlases compact and reduce active content if needed.
Test in the official client. Full originals belong in art/source-images for
authoring, not runtime IWDs.

## Server command overflow

The reliable server-to-client command queue overflowed; this is not an asset pool.
Avoid broadcasting every catalog row/dvar on join. Browser synchronization sends
visible-page state and caches metadata. Run `-Suite Traffic` and reproduce with
real clients; bots do not model the same queue.

## Server-only stat 2400 / duplicated search or page input

Stats are server-owned. Menus send validated responses through GSC instead of
client-side stat writes. Edit controls need one input owner; duplicated native
fields can duplicate characters. Check the generator and generated menu together,
then verify both fields in the official client.

## Native test driver never starts

Check port availability, map installation and fs_game path length (63 maximum).
The harness applies its custom gametype after public config to avoid overwriting
the latched value. Use the ApX binary and inspect the fixture qconsole log before
increasing duration.

## Locked output / interrupted SDK restoration

Close the process holding the package before replacing it. Do not kill unrelated
game processes. Inspect build/logs and build/tmp. Preserve recovery files until
original SDK files are restored; `-Force` only invalidates cache.

## Missing original authoring texture

Hydrate `art/source-images/` and verify against `ui/texture_optimization.json`.
Rendering requires full source textures, not mip-trimmed runtime data. Older
workspaces can use build/content-original-images as a compatibility fallback.

## Preview missing / unexpectedly expensive in materials

Finish the pipeline: package stills/turntables, package shared still atlases,
apply profile, generate menus, build. Individual previews are an intermediate
step and must not replace final shared mapping. Still view is default.
Offline proofs do not validate native shaders, hover/focus or gameplay.
