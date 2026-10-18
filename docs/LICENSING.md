# Rights and provenance

Original ApX work uses the [permission-required notice](../LICENSE.md).
It is source available, not licensed for general reuse. Request written permission
from the repository owner, naming the files and intended use. Do not assume that
notice covers third-party files or that ApX can grant someone else's rights.

Public GitHub repositories remain subject to platform terms, including public
viewing/forking features. See GitHub's
[licensing guidance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository).
This does not turn permission-required code into open source.

## Rights inventory

| Material | Location / evidence | Publication treatment |
| --- | --- | --- |
| Original ApX contributions | Scripts/tooling/docs/art identified by contribution history and notices | Root notice; verify ownership |
| BraXi Death Run 1.2.1 | src/DeathRun_ReadMe.txt and preserved notices | Retain attribution; no blanket relicensing or assumed redistribution grant |
| Community models/weapons/sounds | ui/content_catalog.json, docs/CONTENT_CREDITS.md, src/content_credits.txt | Authors/pages/hashes retained; individual permission/license evidence still needs review |
| Game/SDK-derived assets | Engine dependencies and templates | Rights remain with owners; owning the game does not establish redistribution permission |
| Modified CoD4x server | server/LICENSE.md, patch, build.json, source ZIP | AGPL-3.0 terms; supply matching source and notices |
| Optional Blender importer | tools/licenses/cod-asset-importer.txt, downloaded v3.5 archive | GPL terms; retain required notices/source availability |
| iwi2dds converter | tools/iwi2dds.exe | Provenance/license unresolved; verify permission or replace before publication |
| ApX brand logo | art/brand/README.md | Generated-art provenance retained; root notice applies to original contribution |

The server revision and binary/patch/source hashes are in server/build.json.
Do not ship a binary with stale corresponding source. The root notice does not
restrict rights granted under the AGPL/GPL.

## Public upload gate

Local Git/LFS preparation does not certify redistribution rights. Before a public
repository or release:

1. Review third-party packs; record applicable license or permission, author,
   source URL, scope and evidence.
2. Separate original changes from inherited material when granting permission.
3. Remove or replace material without adequate rights in a curated publication
   tree. Deleting it in a later commit does not erase Git or LFS history.
4. Preserve upstream notices, attribution and matching server source.
5. Confirm hosting storage/transfer capacity for the full collection.

Review **before the first public push**: asset history is itself distribution.
Credits and download pages are provenance, not licenses. No public upload is
performed by this repository's tools.

See [releasing](RELEASING.md) for artifact/configuration boundaries.
