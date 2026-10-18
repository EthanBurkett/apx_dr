# ApX presentation audit

The original Death Run scripts retain their compatibility namespace and copyright
notices. ApX owns the player-facing presentation; original contributors remain
credited by name. Map-authored signage, notices and creator credits are retained.

## End of map

One native menu, `apx_intermission`, provides three tabs and timed phases:

1. **Match report:** eight seconds, with each match leader beside the independent
   map record. Valid new records receive a small NEW label.
2. **Next map:** the configured `dr_mapvote_time`, with up to six unique random
   candidates, live counts, numbered shortcuts and a clear-vote action. The
   current map is excluded. One connected player owns one ballot; changing it
   replaces it, disconnecting removes it, and late/out-of-range requests fail.
3. **Credits:** eight seconds, with ApX, Foundation and Community attribution
   pages. The same credit content appears in the offline About screen.

No votes advances to the next map in the complete configured rotation. Positive
ties use candidate order, which is visible to everyone. A single-map rotation
skips voting safely. Disabling `dr_draw_best_players` skips the report phase,
while record calculation and saving still happen. Disabling `dr_mapvote` uses
the same complete sequential rotation. The falling-teddy playback, preload and
manifest registration are removed.

Unfinished runs use a legacy numeric sentinel internally. It cannot be shown as
a result or persisted as a valid record. Finish records retain fractional seconds,
and the first valid finish can replace an empty record. The record format remains
compatible with `dr_info_<map>`; this does not introduce restart-proof storage.

`_intermission.gsc` publishes a small fixed report and changed ballot counts.
It does not refresh the equipment catalog, poll player input or publish every
installed map to clients. Report batches are spaced, and phase initialization
runs independently for each client. Joining during a phase receives that phase.

![Map ballot coordinate proof](../art/ui/menus/map-ballot.png)

![Credits coordinate proof](../art/ui/menus/credits.png)

These images use real menu coordinates and assets with labeled sample data.
They are layout proofs, not screenshots of the CoD4 client.

## Installed map rotation

```powershell
python tools/sync_map_rotation.py
# Optional alternative installation:
python tools/sync_map_rotation.py --usermaps D:\CoD4\usermaps
```

The current inventory contains 626 folders: 480 included Deathrun maps and 146
excluded regular multiplayer/survival, incomplete or unrecognized entries. A
playable matching `.ff` is required. Arena metadata declaring Deathrun or the
established `mp_dr_`, `mp_deathrun_`, `mp_drrun_` prefixes identify candidates.
This is an installation/metadata inventory, not certification that every map's
script, triggers or asset pools work with this mod. Review individual failures
before enabling a map on a public server.

The generated config stores all 480 maps in 13 `apx_rotation_<n>` dvars. Each
command is below 1024 bytes. `_vote_maps.gsc` reads every page, deduplicates it
and uses the same collection for voting and end-of-match progression.
`sv_mapRotation` contains the first page for engine startup/fallback; manual
engine `map_rotate` uses that fallback page. Normal ApX match transitions use
the full collection. To return to an ordinary hand-edited `sv_mapRotation`, set
`apx_rotation_page_count 0`. The inventory report records every exclusion and
does not copy usermap files into Git.

Install the generated `config/server/rotation.cfg` alongside the built mod and
restart the server so every page loads. Regenerate after installing/removing maps.

## Smaller legacy surfaces

| Surface | ApX handling |
| --- | --- |
| First blood / last alive | Compact slate/gold notices; no red glow or typewriter pulse |
| Round transitions | Same notice family, preserving round outcome/rules |
| Elimination/player cards | Compact centered strip, saved sprays or actual ApX rank badges; no sliding giant logos or pulse effects |
| Free-run choice | Small bottom prompt/timer, hidden in menus; existing Activator decision preserved |
| Finish time | Compact result message, valid fractional time |
| Server adverts / MOTD / author | ApX copy and identity; attribution lives in Credits and source notices |
| Spectator hints | Suppressed during the native end-map menu |
| Extra lives / ability feedback / unlocks | Compact, menu-aware gold/slate feedback; no green pulse or sliding unlock panel |
| Loadout / settings / progression / VIP / admin | Existing ApX menu system and server-side access checks retained |
| Abilities / perks / gore / sprays / XP / admin permissions | Existing configured gameplay behavior retained |
| Community/map attribution | Original author names and full content/legal notices retained |

## Local test Jumpers

`config/deathrun/testing.cfg` currently sets `g_bots 2` for this local testing
installation. Set it to `0` before running a public server. Administration >
Testing / bots can set the managed count to two or zero; the server requires
admin permission `n`. The controller caps its target at eight and only removes
players it created. Other bots and human players are never removal targets.

These are test clients, not AI that navigates maps or operates traps. They join
Jumpers, count toward practice readiness and expire after 20 seconds outside
practice so rounds can progress. They respawn with the normal round flow and
may be selected as Activator. Isolated test runners force `g_bots 0` before
startup, then explicitly enable the controller when testing it.

## Editing and verification

Edit `ui/credits.json` for attribution and `tools/menu_intermission.py` for
layout, then run `python tools/generate_menus.py`. `tools/preview_menus.py`
produces report, ballot, credits and offline About coordinate proofs.

```powershell
python tools/check.py --suite full
.\tools\test-progression.ps1 -Suite Presentation
```

The presentation suite uses an isolated native server and bot. It checks the
unfinished-time sentinel, fractional records, paged rotation, ballot replacement,
clear/expired/invalid ballots, and opening all three phases. Interactive mouse,
keyboard focus and widescreen presentation still need a real client check.
