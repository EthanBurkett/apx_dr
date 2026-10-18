# ApX levels, prestiges and scoreboard

## Progression rules

Displayed levels are 1–70; internal rank IDs are 0–69. Prestiges are 0–5,
where 0 means not prestiged. Level N begins at `200 * (N-1) * N` XP and its
XP bar spans `400 * N` XP. This preserves the original early-level curve.
Level 70 begins at 966,000 XP; completing its bar takes 994,000 XP.

Prestige requires a complete level-70 bar and prestige below 5. The server
issues a 30-second confirmation and consumes it before changing state. Repeated,
stale or forged confirmation responses cannot apply a reset without eligibility.
After prestige, rank/XP become 0/0 and prestige increments once. Lifetime counters,
completed challenges and ability flags are retained. Level-gated customization
is validated again; earned abilities remain unlocked. At prestige 5, players
can reach level 70 and keep playing without exceeding the XP cap.

Community primaries, melee and operators use prestige plus level requirements.
Earlier tiers remain unlocked after prestiging. Every prestige has ten
rank milestones, at levels 7, 14, 21, 28, 35, 42, 49, 56, 63 and 70; the in-game reward browser reads the same tables as equipment
validation. See [CONTENT.md](CONTENT.md) for the complete catalog and credits.

Old profiles retain their XP and lifetime statistics. Saved test prestiges above 5 normalize to the new cap on load. Integrity mirrors are checked before the expanded
rank table normalizes the profile, then refreshed. The original stat IDs remain:

| Stat | Meaning |
| --- | --- |
| 2301 | Current-cycle rank XP |
| 2326 | Prestige 0–5 |
| 2350 | Internal rank 0–69 |
| 251, 252 | Menu rank mirrors |
| 2351, 2352 | Current level minimum/maximum XP |
| 3200–3207 | Existing earned ability flags, retained |

`_prestige.gsc` owns eligibility, confirmations and profile synchronization.
`_rank_progression.gsc` owns XP and rank transitions. `_rank_players.gsc` loads
the saved prestige instead of forcing it to zero. All rank changes call native
`setRank(rank, prestige)` and keep the existing profile/menu mirrors consistent.

## Tables and artwork

`rankTable.csv` contains 70 contiguous ranks and `maxrank,69`.
`rankIconTable.csv` contains each level badge for all 6 prestige columns, plus
both caps. `apx_prestiges.csv` maps 1–5 to prestige materials, with a nonempty
white sentinel for hidden prestige 0. Explicit integer/string lookup keys avoid
ambiguous script conversions. APXRANK localization supplies every level label.

The 70 level shields and 5 active ApX prestige emblems are custom vector geometry.
`art/progression/` contains SVGs, PNG previews and a contact sheet. Engine assets
are 512x512 lossless BGRA IWI textures with full mip chains and 2D materials.
Artwork renders at 1024x1024 before downsampling. The no-picmip flag keeps client
world-texture quality settings from reducing UI resolution. Lossless pixels avoid
DXT block/color artifacts around fine gold lines and numbers. The 75 active mip chains
total about 100 MiB uncompressed; the IWD compresses them for transfer. The generator
uses the existing stock rank material layout. Regenerate with Python and Pillow:

```powershell
python .\tools\generate_progression.py
.\tools\build.ps1
```

Register new gameplay tables in `manifests/04-tables.csv`; icon materials are
listed in generated `12-progression.csv`. Textures are packaged in `apx_dr.iwd`.
The native client has one rank-icon column, so it retains the level badge;
the custom scoreboard and menus independently look up the prestige emblem.

## Tab scoreboard

`ui_mp/scriptmenus/scoreboard.menu` overrides the stock SDK menu path, and the
engine still owns the normal +scores/-scores press/release lifecycle. No key
bindings are overwritten. The UI uses a fixed 640x480 virtual layout, 14 rows,
separate icon columns and keyboard Left/Right pagination. It has no mouse buttons.
The gameplay tint is 12%; individual rows receive a restrained additional tint.
Numeric columns share the same baseline and are right aligned.
The header reads `apx_sb_map`, sent from the server's current `mapname`, rather
than the client's potentially stale `ui_mapname` map-selection setting.

`_scoreboard_panel.gsc` sorts jumpers, activators and spectators, then score and
entity number for stable ties. It primes the data after connection, updates once
per second while open, sends changed rows only, clamps pages when players leave,
clears stale rows and truncates long/color-coded names. Updates stop on close,
disconnect or round end.

The native cgame scoreboard also draws outside the menu. Its row height/overall
height are configured at connection to put its contents below the viewport,
preventing its opening/closing fade from appearing beneath the transparent menu.
The main menu restores the normal dimensions when leaving the server.

All macro rectangles specify their six fields, including alignments. The SDK
otherwise consumes following tokens as missing alignment integers when a macro
expands on one source line. Linker “Menu load error” diagnostics now fail builds.

## Verification

The source suite covers all 70 XP thresholds, all 10 prestige transitions,
confirmation/cap guards, retained lifetime stats, every badge/table and stable
scoreboard ordering/pagination. The isolated CoD4x fixture creates only a test
bot and exercises real native stats/setRank, all 10 prestige resets, ability/
challenge retention, duplicate responses and the scoreboard sender, including
64-row pagination and stale-row cleanup. It never alters human profiles or dist.

```powershell
python -m unittest discover -s tests -v
.\tools\test-progression.ps1
```

Successful runtime marker: `APX_PROGRESSION_RUNTIME_PASS`.
Human screenshots confirmed the Tab replacement and exposed menu-parser and
baseline issues, which were corrected. Final visual verification of the latest
transparency, alignment, native-board suppression and keyboard paging remains
separate from server-side runtime assertions.
