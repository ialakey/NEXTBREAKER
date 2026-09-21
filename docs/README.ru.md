# NEXTBREAKER

**Ломай забег.** Бессмертие, мега-урон, бесконечность всего — трейнер и редактор сейвов для
**Go Next! Demo** (Steam app `5066300`), игра на Unity 6000.4 / IL2CPP.

[English documentation →](../README.md)

Трейнер дёргает родные методы игры — `PlayerHealth.GodMode`, `PlayerStats`, `PlayerGold.Add`,
`PlayerLevel.AddXp`, `EnemyRobot.TakeDamage`, — а не патчит память вслепую. Поэтому он переживает
перезапуски и не конфликтует с системой предметов.

> **Только одиночная игра.** У игры есть онлайн-кооп на Mirror, и прогресс вместе с состоянием
> врагов синхронизируется между игроками (`CoopGoldSync`, `CoopSoulSync`, `CoopEnemySync`). Мод
> определяет активную сетевую сессию и принудительно гасит все тумблеры. См. [Защита кооператива](#защита-кооператива).

---

## Состав

| Путь | Что это |
|---|---|
| `src/GoNextTrainer/` | Мод для MelonLoader (C#, `net6.0`) |
| `tools/gonext-cheat.ps1` | Редактор сейва — открывает все предметы, оружие и пассивки |
| `tools/fix-coremodule.ps1` | Чинит битую `UnityEngine.CoreModule.dll`, которую генерирует MelonLoader |

---

## Требования

- Установленная **Go Next! Demo** в Steam
- **MelonLoader 0.7.3** (x64)
- **.NET 6 runtime** — на нём MelonLoader запускает игру
- **.NET SDK 8** — только если собираешь мод сам

---

## Установка

1. Распакуй [MelonLoader 0.7.3 x64](https://github.com/LavaGang/MelonLoader/releases) в папку игры —
   рядом с `Go Next demo.exe` должны появиться `version.dll` и папка `MelonLoader\`.
2. Запусти игру один раз и закрой. Первый старт долгий, несколько минут: MelonLoader разбирает
   `GameAssembly.dll` и генерирует управляемые обёртки.
3. **Почини CoreModule** — на этой игре сгенерированная сборка битая, без этого шага загрузчик
   работать не будет:
   ```powershell
   .\tools\fix-coremodule.ps1
   ```
4. Собери мод (см. [Сборка](#сборка)) или положи готовый `GoNextTrainer.dll` в `Mods\`.
5. Запускай игру. В `MelonLoader\Latest.log` должна появиться строка `Support Module Loaded`.

---

## Горячие клавиши

`Insert` — показать или скрыть оверлей.

### Тумблеры

| Клавиша | Чит | Что выставляет |
|---|---|---|
| `F1` | Бессмертие | `PlayerHealth.GodMode`, `incomingDamageMult = 0` |
| `F2` | Мега-урон | `damageMult`, `critChance = 1` |
| `F3` | Бесконечный даш | пополняет `PlayerDashCharges` |
| `F4` | Скорость | `moveSpeedMult` |
| `F5` | Магнит лута | `pickupRange = 300` |
| `F6` | Бесконечные прыжки | `extraJumps = 99` |
| `F7` | Удача / золото / опыт | `luck`, `goldGainMult`, `xpGainMult`, `rewardDropBonus` |
| `F8` | Скорострельность | `fireRateMult` |
| `Home` | Пробитие насквозь | `projectilePierces = 99` |
| `End` | Вампиризм | `lifestealFraction = 1.0` |

### Регулировка

| Клавиша | Эффект |
|---|---|
| `PgUp` / `PgDn` | множитель урона × / ÷ 2 |
| `Ctrl` + `PgUp` / `PgDn` | скорость ± 0.5 |

### Разовые действия

| Клавиша | Эффект |
|---|---|
| `F9` | +10000 золота |
| `F10` | +1 уровень |
| `F11` | убить всех врагов на карте |
| `F12` | полное лечение |

Тумблеры и действия работают только в забеге. Вне его оверлей скажет «не в забеге» и ничего
не сломает.

---

## Редактор сейва

Прогресс лежит в Unity `PlayerPrefs`, то есть в реестре Windows под
`HKCU\Software\Go Next demo\Go Next demo`. Больше редактор ничего не трогает.

```powershell
.\tools\gonext-cheat.ps1 -Dump      # показать текущий прогресс
.\tools\gonext-cheat.ps1 -Apply     # открыть всё
.\tools\gonext-cheat.ps1 -Restore   # откатить
```

**Игра должна быть закрыта.** Unity держит `PlayerPrefs` в памяти и перезаписывает их при выходе,
так что правки на лету затрутся. Скрипт сам откажется работать, если процесс жив.

Каждый `-Apply` сначала кладёт `.reg`-бэкап с меткой времени в `cheat-backups\`.

Что открывается: **101 предмет, 44 оружия, 56 пассивок** и полный банк ресурсов. Списки ID вытащены
из `global-metadata.dat` самой игры.

Персонажей открывать не нужно — все четверо (`mustafa`, `frogette`, `agentbald`, `freakypanda`)
доступны сразу. В демо у них вообще нет системы блокировки: нет ни `UnlockCharacter`, ни
`IsCharacterUnlocked`, ни `ShowCharacterLocked`, хотя у предметов и оружия есть всё три.

По умолчанию `-Apply` заодно ставит `set_uploadScore = 0`, чтобы прокачанные забеги не попадали
в глобальную таблицу Steam. Флаг `-KeepLeaderboardUpload` оставляет настройку как есть.

---

## Защита кооператива

Мод каждый кадр проверяет `NetworkClient.active` / `NetworkServer.active`. В сетевой сессии все
тумблеры принудительно выключаются, в оверлее появляется красная плашка.

Чтобы снять защиту — в `src/GoNextTrainer/Trainer.cs` заставь `NetworkActive()` возвращать `false`
и пересобери.

---

## Если что-то не работает

### `No Support Module Loaded` / трейнер молчит

Il2CppInterop генерирует для этой игры битую `UnityEngine.CoreModule.dll`, и рантайм её отвергает:

```
BadImageFormatException: Duplicate type with name '<>O'
[ERROR] No Support Module Loaded!
```

Без модуля поддержки MelonLoader не даёт модам игровой цикл, поэтому трейнер не подаёт признаков
жизни. Из 128 сгенерированных сборок задета ровно одна.

```powershell
.\tools\fix-coremodule.ps1          # починить
.\tools\fix-coremodule.ps1 -Check   # только проверить, ничего не меняя
```

Скрипт читает сборку через Mono.Cecil и записывает заново. Cecil строит метаданные из своей
объектной модели, поэтому битые записи отсеиваются. Оригинал сохраняется как
`UnityEngine.CoreModule.dll.orig`, состояние отслеживается по хешу — повторный запуск ничего
не делает.

Рядом с `tools/fix-coremodule.ps1` должен лежать `Mono.Cecil.dll` — возьми его с
[NuGet](https://www.nuget.org/packages/Mono.Cecil) (`lib/net40/Mono.Cecil.dll`).

**Запускай это после каждого обновления в Steam**: игра патчится, MelonLoader перегенерирует
обёртки, и дефект возвращается.

### Правки сейва не применились

Запусти `-Dump`. Если в списках есть количества — в реестре всё на месте, значит игра не приняла
формат. Если пусто — игра была запущена во время `-Apply`: закрой её и повтори.

---

## Сборка

```powershell
dotnet build src/GoNextTrainer -c Release -p:GameDir="D:\SteamLibrary\steamapps\common\Go Next! Demo"
copy src\GoNextTrainer\bin\Release\net6.0\GoNextTrainer.dll "<игра>\Mods\"
```

`GameDir` по умолчанию указывает на путь автора — переопредели его, как показано. Проект ссылается
на сборки, которые MelonLoader сгенерировал в `MelonLoader\Il2CppAssemblies`, поэтому игру нужно
запустить хотя бы раз.

Мод целится в `net6.0`, потому что именно на этом рантайме MelonLoader запускает игру.

### Как добавить ещё читов

В `PlayerStats` около 140 полей, трейнер использует примерно десяток. Всё остальное доступно так же —
добавь строку в `OnLateUpdate()`:

```csharp
if (_myToggle.On) st.fieldName = value;
```

Полезное из незадействованного: `projectileBounces`, `extraProjectiles`, `cooldownMult`,
`thornsDamage`, `weaponRangeMult`, `chestPriceMult`, `playerSizeMult`, `echoShotChance`,
`chainHitJumps`.

Полный список — в `MelonLoader\Il2CppAssemblies\Il2CppGame.dll`: там лежит 931 класс игры,
а **не** в `Assembly-CSharp.dll`, где всего 19 заглушек.

---

## Детали реализации

Особенности именно этой сборки, которые пришлось обойти:

1. **Код игры в `Il2CppGame.dll`.** В `Assembly-CSharp.dll` только 19 типов-пустышек.

2. **`GUILayout` вырезан при стриппинге.** Любой вызов падает с
   `NotSupportedException: Method unstripping failed`. Оверлей нарисован только через
   `GUI.Box` / `GUI.Label` с явными координатами — эти методы в билде сохранились.

3. **Ввод идёт через WinAPI `GetAsyncKeyState`.** Игра использует новую Input System, где
   легаси-`Input.GetKeyDown` может кидать исключение. WinAPI от этого выбора не зависит.

4. **Значения дожимаются каждый кадр** в `OnLateUpdate`, а не пишутся однократно: система предметов
   пересчитывает статы в своём `Update`, и разовая запись не удержалась бы.

5. **`PlayerHealth.GodMode` статический**, рядом со статическим `ResetGodMode` — инстанс не нужен.

---

## Удаление

```powershell
$g = 'D:\SteamLibrary\steamapps\common\Go Next! Demo'
Remove-Item "$g\version.dll"
Remove-Item "$g\MelonLoader","$g\Mods","$g\UserData" -Recurse
```

Файлы самой игры не менялись, поэтому проверка целостности в Steam ничего не откатит. Правки сейва
живут в реестре — убираются через `tools\gonext-cheat.ps1 -Restore`.
