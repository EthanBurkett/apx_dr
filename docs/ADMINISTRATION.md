# Progression testing commands

Use the server console or authenticated RCON. These extend the existing BraXi
`admin` and `adm` dvar commands; they are not ordinary client console cheats.
Run `rcon status` to find client numbers. `admin` selects a client number;
`adm` selects an exact name or unique partial name, ignoring colors and case.
Ambiguous names and invalid client numbers are rejected.

Examples from the in-game console, for the player named `hype`:

```text
\rcon set adm "xp:hype:994000"
\rcon set adm "setrank:hype:70"
\rcon set adm "setprestige:hype:9"
\rcon set adm "reset:hype"
```

The equivalent server-console command for client 0 is `set admin "setrank:0:70"`.
Use your existing RCON authentication. Do not put passwords in client archives.

| Command payload | Behavior |
| --- | --- |
| `xp:<target>[:amount]` | Add rank XP, default 4,000; explicit amount 1–994,000. Current-cycle XP stops at 994,000. |
| `setrank:<target>:<level>` | Set displayed level 1–70. Levels 1–69 start at their minimum XP; level 70 fills its final bar for a prestige test. |
| `setprestige:<target>:<prestige>` | Set prestige 0–10 while retaining current level and XP. |
| `reset:<target>` | Full progression reset: level 1, XP 0, prestige 0, lifetime counters, challenge progress, earned abilities and selected equipment reset. |

Commands work on connected players while alive, dead or spectating, including
free runs and non-pure local servers. They bypass gameplay reward scaling and
the per-reward limit. XP/rank/prestige changes preserve lifetime statistics and
do not add testing XP to match or lifetime score. Values must be whole numbers;
missing, negative, fractional, oversized and malformed arguments are rejected.
Extra arguments are rejected, including extras on `reset`.

For the normal prestige flow, set prestige 9 and rank 70, then use the real
**Progression > Enter prestige** menu. Confirming should produce prestige 10,
level 1 and 0 XP. `setprestige` itself is a setter, so it does not run that reset.

Full reset restores fresh tier-one challenge availability, refreshes challenge
caches, clears current personal match counters/lives, and removes the equipped
earned perk. Selected equipment is normalized for the new level. Camera options,
admin authentication and moderation warnings retain their existing settings.
Shared server map records are separate from the player's progression profile.

`braxi/_admin_progression.gsc` owns validation, target selection and mutation.
`_admin_commands.gsc` delegates these four commands before the legacy switch.
Every successful change synchronizes native rank, profile stats, prestige-menu
dvars, selected equipment and integrity mirrors. Pending prestige confirmation
is invalidated. Alive players receive normal promotion/XP feedback, and the
scoreboard picks up the new values on its next update. Changes are logged.

The dvar consumer runs in trusted server context. Any player-context call to
the same handler requires an authenticated admin with permission `p`.
The existing admin menu does not expose these new commands to ordinary clients.

Source tests cover all levels/prestiges, validation, permission rejection,
dead/spectating and free-run behavior, name ambiguity, lifetime retention and
the full reset. `tools/test-progression.ps1` also runs the exact server-dvar
consumer against an isolated real CoD4x bot. It never resets human profiles.
