# NEXTBREAKER

## Version 1.8.0: automatic available items

After changing kills or time with the bracket controls, the trainer asks the game
for `Leaderboard.MinItemsFor(kills, totalRunTime)` and fills missing item copies via
`ItemInventory.Grant`. It grants up to four copies per frame and shows progress in
the overlay. Only unlocked, enabled, demo-available, non-banished items with positive
drop weight and room under their copy limit are eligible. Inventory effects are applied
by the game; no new unlocks are granted.

Existing copies count toward the target. Reducing kills/time does not remove items.
The queue stops outside a live solo run, on run change, in co-op, on failure or if the
eligible pool is exhausted. Automatic targets are capped at 1,000 total copies to bound
work. Ctrl+Backspace asks you to wait while a queue is active, then press it again.

Automatic items default to on, including with an existing settings file. Add
`AutoItems=false` to `UserData/GoNextTrainer.steps.cfg` to disable; settings reload
on the next bracket press. No leaderboard upload is triggered by granting items.
Other consistency checks (including level and kill rate) can still reject the run.
Version 1.8.0 builds against the installed game; in-game granting still needs validation.

## Version 1.7.0: 999B attack damage

Press **B** to toggle 999,000,000,000 damage passed into enemy hit processing.
This uses the `double` damage argument on `EnemyRobot.TakeDamage` overloads instead
of overflowing the game's integer base-damage field. The game's later hit modifiers
can still affect the final displayed damage. It does not damage the player.
The mode is mutually exclusive with F2 mega damage and is disabled in co-op and by
the end-run command. Enemy hits from other trainer actions also use this value while enabled.

### Leaderboard results missing

Enabled upload preferences do not guarantee acceptance. The game validates run duration,
kills, level and collected items. Check `Player.log` under the game's LocalLow folder
for `[Leaderboard] run NOT submitted` and `[Ranked] run not rated`; those lines explain
why a run was rejected. Editing timer or kill counts does not update the rest of the
run history and can fail these checks. This trainer does not bypass leaderboard validation.

## Version 1.6.0: automatic CoreModule repair and custom steps

Install `GoNextCoreRepair.dll` into **Plugins/** and `GoNextTrainer.dll` into **Mods/**
with the game closed. The packaged `Install-NEXTBREAKER.ps1` installs both DLLs,
backs up previous versions and verifies the copied files.

The repair plugin uses MelonLoader 0.7.3's `OnPreModsLoaded` callback, after assembly
generation and before mod loading. It rewrites the generated CoreModule with the
loader's bundled Mono.Cecil, preserves `.orig`, and records the repaired SHA-256.
Regeneration changes the hash and triggers repair again. Matching files are left alone.
This addresses the known duplicate-type generation bug; unrelated loader errors still
need diagnosis. The plugin references no Unity/game assemblies during early loading.

Step sizes are read from `UserData/GoNextTrainer.steps.cfg` on each bracket key press:

```ini
KillStep=50000
TimeStepSeconds=300
```

Set any positive whole-number kill step up to 2,147,483,647 and any positive time
step up to 86,400 seconds (decimal point allowed). Invalid settings retain the last
valid value. `[` / `]` subtract/add the kill step; `Ctrl` + `[` / `]` adjusts time.
Hold **Shift** for a step of **1 kill**, or **Ctrl + Shift** for **1 second**.
Time and kills stay nonnegative. These settings provide precise manual control;
they do not guarantee leaderboard acceptance or protection from bans.

Build the repair plugin with:

```powershell
dotnet build src/GoNextCoreRepair -c Release -p:GameDir="D:\SteamLibrary\steamapps\common\Go Next! Demo"
```

The repair was tested on a copy of the malformed assembly: initial repair, CLR
loading, no-op repeat, backup preservation and repair after simulated regeneration.
Full in-game loading still needs verification after installation.

**Break the run.** God mode, mega damage, infinite everything — an in-game trainer and save
unlocker for **Go Next! Demo** (Steam app `5066300`), a Unity 6000.4 / IL2CPP game.

[Русская документация →](docs/README.ru.md)

The trainer calls the game's own methods — `PlayerHealth.GodMode`, `PlayerStats`, `PlayerGold.Add`,
`PlayerLevel.AddXp`, `EnemyRobot.TakeDamage` — rather than blind-patching memory, so it survives
restarts and does not fight the item system.

> **Single-player only.** The game ships online co-op on Mirror, and progress plus enemy state are
> synchronised between players (`CoopGoldSync`, `CoopSoulSync`, `CoopEnemySync`). The trainer detects
> an active network session and force-disables every toggle. See [Co-op safety](#co-op-safety).

---

## Contents

| Path | What it is |
|---|---|
| `src/GoNextTrainer/` | The MelonLoader mod (C#, `net6.0`) |
| `tools/gonext-cheat.ps1` | Save editor — unlocks all items, weapons and passives |
| `tools/fix-coremodule.ps1` | Repairs the malformed `UnityEngine.CoreModule.dll` MelonLoader generates |

---

## Requirements

- **Go Next! Demo** installed via Steam
- **MelonLoader 0.7.3** (x64)
- **.NET 6 runtime** — MelonLoader runs the game on it
- **.NET SDK 8** — only if you want to rebuild the mod

---

## Install

1. Extract [MelonLoader 0.7.3 x64](https://github.com/LavaGang/MelonLoader/releases) into the game
   folder (you should end up with `version.dll` and a `MelonLoader\` folder next to `Go Next demo.exe`).
2. Launch the game once and close it. The first start takes a few minutes — MelonLoader disassembles
   `GameAssembly.dll` and generates managed wrappers.
3. **Run the CoreModule repair** — on this game the generated assembly is broken and the loader will
   refuse to work without this step:
   ```powershell
   .\tools\fix-coremodule.ps1
   ```
4. Build the mod (see [Building](#building)) or drop a prebuilt `GoNextTrainer.dll` into `Mods\`.
5. Launch the game. `MelonLoader\Latest.log` should contain `Support Module Loaded`.

---

## Hotkeys

Press `Insert` to show or hide the overlay.

### Toggles

| Key | Cheat | What it sets |
|---|---|---|
| `F1` | Invincibility | `PlayerHealth.GodMode`, `incomingDamageMult = 0` |
| `F2` | Mega damage | `damageMult`, `critChance = 1` |
| `B` | 999B attack damage | sets positive enemy hit amounts to 999,000,000,000 |
| `F3` | Infinite dash | refills `PlayerDashCharges` |
| `F4` | Move speed | `moveSpeedMult` |
| `F5` | Loot magnet | `pickupRange = 300` |
| `F6` | Infinite jumps | `extraJumps = 99` |
| `F7` | Luck / gold / XP | `luck`, `goldGainMult`, `xpGainMult`, `rewardDropBonus` |
| `F8` | Fire rate | `fireRateMult` |
| `Home` | Pierce | `projectilePierces = 99` |
| `End` | Lifesteal | `lifestealFraction = 1.0` |
| `Del` | Auto-kill enemies | calls `EnemyRobot.TakeDamage` for you every 0.25s |

### Adjusters

| Key | Effect |
|---|---|
| `PgUp` / `PgDn` | damage multiplier × / ÷ 2 |
| `Ctrl` + `PgUp` / `PgDn` | move speed ± 0.5 |

### One-shot actions

| Key | Effect |
|---|---|
| `F9` | +10000 gold |
| `F10` | +1 level |
| `F11` | kill every enemy and prop on the map (once) |
| `F12` | full heal |
| `]` | add the configured kill step (default 50,000) |
| `[` | subtract the configured kill step (minimum 0) |
| `Ctrl` + `]` | advance the map timer by the configured step (default 5 minutes) |
| `Ctrl` + `[` | rewind the map timer by the configured step (minimum 0) |
| `Shift` + `[` / `]` | subtract/add 1 kill |
| `Ctrl` + `Shift` + `[` / `]` | subtract/add 1 second |
| `Ctrl` + `Backspace` | disable trainer toggles and end the run through lethal damage |

Toggles and actions only do something during a run. Outside one the overlay reports
"not in a run" and nothing breaks.

### Timer and end-run controls (v1.5.0)

`Ctrl` + `[` / `]` changes `GameTimer.Elapsed` by 300 seconds per press during a
live solo run by default; the step is configurable. Holding the key does not repeat. These combinations do not also change
the kill counter. The timer on the current map is adjusted; banked time from earlier
maps is left intact. Advancing time can trigger the game's difficulty thresholds;
rewinding does not undo enemies or events that already happened.

`Ctrl` + `Backspace` ends the current solo run through the game's damage/death flow.
It switches off trainer toggles, GodMode, the current shield and invulnerability,
clears pending revival, sets health to 1 and applies lethal damage with block bypass.
If the game still prevents death, the overlay reports that instead of claiming success.
Both controls are inactive outside a live run and in co-op.

### Kill counter

Use the `]` (increase) and `[` (decrease) keys during a solo run. Each press changes
`RunSession.Kills` once; holding a key does not repeat the change. The overlay displays
the resulting count briefly. Values are limited to 0–2,147,483,647 to prevent overflow.
These actions change the run counter directly without killing enemies or granting their
gold or XP. They do not change the separate auto-kill tally and are disabled in co-op.

To update, close the game, rebuild Release, and replace `Mods/GoNextTrainer.dll`.
Version 1.8.0 has been build-checked against the local game assemblies; the new controls
still need an in-game check.

### Auto-kill (`Del`)

`F11`, but it presses itself: while the toggle is on the mod walks `EnemyRegistry.All` four times
a second and finishes off everything alive. Enemies die almost as they spawn, and gold, souls and
XP drop as they would from a normal kill — the damage goes through the game's own
`EnemyRobot.TakeDamage` rather than `Die()`.

Two things it does differently from one-shot `F11`:

- **It leaves props alone.** Crates and anything else flagged `IsProp` are skipped, otherwise the
  whole level would burst the moment it loads, fireworks included. `F11` still clears them.
- **It runs on a timer, not every frame.** Walking the registry through IL2CPP interop 200 times a
  second is pure overhead, and a quarter of a second reads as instant in game.

The overlay shows a running kill count, reset every time you switch the toggle on. In a network
session auto-kill is disabled along with every other cheat.

---

## Save editor

Progression is stored in Unity `PlayerPrefs`, i.e. the Windows registry under
`HKCU\Software\Go Next demo\Go Next demo`. The editor touches nothing else.

```powershell
.\tools\gonext-cheat.ps1 -Dump      # show current progress
.\tools\gonext-cheat.ps1 -Apply     # unlock everything
.\tools\gonext-cheat.ps1 -Restore   # roll back
```

**The game must be closed.** Unity keeps `PlayerPrefs` in memory and rewrites them on exit, so edits
made while it runs get overwritten. The script refuses to run if the process is alive.

Every `-Apply` writes a timestamped `.reg` backup into `cheat-backups\` first.

What it unlocks: **101 items, 44 weapons, 56 passives**, plus a full resource bank. The ID lists were
extracted from the game's `global-metadata.dat`.

Characters need no unlocking — all four (`mustafa`, `frogette`, `agentbald`, `freakypanda`) are
available from the start. The demo has no character lock system at all: there is no
`UnlockCharacter`, no `IsCharacterUnlocked` and no `ShowCharacterLocked`, while items and weapons
have all three.

By default `-Apply` also sets `set_uploadScore = 0` so cheated runs stay off the global Steam
leaderboard. Pass `-KeepLeaderboardUpload` to leave it alone.

---

## Co-op safety

The mod checks `NetworkClient.active` / `NetworkServer.active` every frame. In a network session all
toggles are forced off and the overlay shows a red banner.

To remove that guard, make `NetworkActive()` in `src/GoNextTrainer/Trainer.cs` return `false` and
rebuild.

---

## Troubleshooting

### `No Support Module Loaded` / the trainer does nothing

Il2CppInterop generates a malformed `UnityEngine.CoreModule.dll` for this game. The runtime rejects it:

```
BadImageFormatException: Duplicate type with name '<>O'
[ERROR] No Support Module Loaded!
```

Without the support module MelonLoader never gives mods an update loop, so the trainer is silent.
Exactly one of the 128 generated assemblies is affected.

```powershell
.\tools\fix-coremodule.ps1          # repair
.\tools\fix-coremodule.ps1 -Check   # inspect only, change nothing
```

The script reads the assembly with Mono.Cecil and writes it back out. Cecil rebuilds metadata from
its object model, so the malformed entries are dropped. The original is kept as
`UnityEngine.CoreModule.dll.orig`, and state is tracked by hash, so re-running is a no-op.

`tools/fix-coremodule.ps1` needs `Mono.Cecil.dll` next to it — grab it from
[NuGet](https://www.nuget.org/packages/Mono.Cecil) (`lib/net40/Mono.Cecil.dll`).

Without `GoNextCoreRepair.dll`, re-run the script after Steam updates that regenerate
the wrappers. With the repair plugin installed, this known defect is repaired automatically.

### Save edits did not apply

Run `-Dump`. If the lists show counts, the registry is fine and the game rejected the format. If they
show empty, the game was running during `-Apply` — close it and retry.

---

## Building

```powershell
dotnet build src/GoNextTrainer -c Release -p:GameDir="D:\SteamLibrary\steamapps\common\Go Next! Demo"
copy src\GoNextTrainer\bin\Release\net6.0\GoNextTrainer.dll "<game>\Mods\"
```

`GameDir` defaults to the author's path; override it as shown. The project references the assemblies
MelonLoader generated under `MelonLoader\Il2CppAssemblies`, so the game must have been launched once.

The mod targets `net6.0` because that is the runtime MelonLoader starts the game on.

### Adding more cheats

`PlayerStats` exposes roughly 140 fields and the trainer uses about a dozen. Everything else is
reachable the same way — add a line to `OnLateUpdate()`:

```csharp
if (_myToggle.On) st.fieldName = value;
```

Useful unused fields: `projectileBounces`, `extraProjectiles`, `cooldownMult`, `thornsDamage`,
`weaponRangeMult`, `chestPriceMult`, `playerSizeMult`, `echoShotChance`, `chainHitJumps`.

The full list lives in `MelonLoader\Il2CppAssemblies\Il2CppGame.dll` — that is where the game's 931
classes are, **not** in `Assembly-CSharp.dll`, which holds only 19 stubs.

---

## Implementation notes

Quirks of this particular build that the mod works around:

1. **Game code is in `Il2CppGame.dll`.** `Assembly-CSharp.dll` contains 19 placeholder types.

2. **`GUILayout` is stripped.** Any call throws `NotSupportedException: Method unstripping failed`.
   The overlay is drawn only with `GUI.Box` / `GUI.Label` at explicit rects, which survived stripping.

3. **Input goes through WinAPI `GetAsyncKeyState`.** The game uses the new Input System, where legacy
   `Input.GetKeyDown` can throw. WinAPI is independent of that choice.

4. **Values are re-applied every frame** in `OnLateUpdate`, not written once — the item system
   recalculates stats in its own `Update` and a single write would not stick.

5. **`PlayerHealth.GodMode` is static**, next to a static `ResetGodMode`, so it needs no instance.

---

## Uninstall

```powershell
$g = 'D:\SteamLibrary\steamapps\common\Go Next! Demo'
Remove-Item "$g\version.dll"
Remove-Item "$g\MelonLoader","$g\Mods","$g\UserData" -Recurse
```

No game file is ever modified, so a Steam integrity check has nothing to restore. Save edits live in
the registry; remove them with `tools\gonext-cheat.ps1 -Restore`.
