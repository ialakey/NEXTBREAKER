# NEXTBREAKER

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
| `F3` | Infinite dash | refills `PlayerDashCharges` |
| `F4` | Move speed | `moveSpeedMult` |
| `F5` | Loot magnet | `pickupRange = 300` |
| `F6` | Infinite jumps | `extraJumps = 99` |
| `F7` | Luck / gold / XP | `luck`, `goldGainMult`, `xpGainMult`, `rewardDropBonus` |
| `F8` | Fire rate | `fireRateMult` |
| `Home` | Pierce | `projectilePierces = 99` |
| `End` | Lifesteal | `lifestealFraction = 1.0` |

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
| `F11` | kill every enemy on the map |
| `F12` | full heal |

Toggles and actions only do something during a run. Outside one the overlay reports
"not in a run" and nothing breaks.

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

**Re-run this after every Steam update**: the game gets patched, MelonLoader regenerates the
wrappers, and the defect comes back.

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
