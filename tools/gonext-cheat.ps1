<#
    gonext-cheat.ps1 - открывает предметы/оружие/пассивки в Go Next! Demo
    и пополняет банк ресурсов.

    Прогресс игра хранит в Unity PlayerPrefs, то есть в реестре:
        HKCU\Software\Go Next demo\Go Next demo
    Имя значения = <ключ>_h<djb2-xor хеш ключа>.

    Никаких файлов игры скрипт не трогает, в процесс игры не лезет.
    Всё, что он делает, - правит ключи реестра, и перед каждой правкой
    сам делает .reg-бэкап.

    ВАЖНО: запускать при ЗАКРЫТОЙ игре. Unity перезаписывает PlayerPrefs
    при выходе и затрёт правки, сделанные на лету.

    Использование:
        .\gonext-cheat.ps1 -Dump       # показать текущий прогресс
        .\gonext-cheat.ps1 -Apply      # открыть всё
        .\gonext-cheat.ps1 -Restore    # откатить последний бэкап
#>

[CmdletBinding(DefaultParameterSetName = 'Dump')]
param(
    [Parameter(ParameterSetName = 'Dump')]    [switch] $Dump,
    [Parameter(ParameterSetName = 'Apply')]   [switch] $Apply,
    [Parameter(ParameterSetName = 'Restore')] [switch] $Restore,

    # Сколько класть в каждую ячейку банка ресурсов.
    [Parameter(ParameterSetName = 'Apply')]   [int] $Resources = 9999,

    # По умолчанию скрипт выключает отправку очков в глобальный лидерборд
    # (у игры есть ranked-режим и общая таблица). Снять флаг - оставить как есть.
    [Parameter(ParameterSetName = 'Apply')]   [switch] $KeepLeaderboardUpload
)

$ErrorActionPreference = 'Stop'

$PrefsPath   = 'HKCU:\Software\Go Next demo\Go Next demo'
$PrefsReg    = 'HKEY_CURRENT_USER\Software\Go Next demo\Go Next demo'
$BackupDir   = Join-Path $PSScriptRoot 'cheat-backups'

# --- каталоги, вытащенные из global-metadata.dat -----------------------------

$Items = @(
    'bait','bananapeelhalo','bananaphone','bicpensprings','bigredbutton','blockparty',
    'bogosoul','bootlegexcalibur','bouncersbadge','brandnewwhitesneakers','brittle',
    'caffeinatedcat','cargoshorts','clankerdetector','collector','corsair','critinception',
    'crossnecklace','ctrlz','curse','cursedyoyo','dayonedlcthedash','deathbed','demolisher',
    'diplomaofbrainrot','discovery','doomsdayyapper','doubleitandgiveittothenext',
    'eattherich','edgeofthemirror','energydrink','evadewindow','existentialmirror','exomech',
    'extrahand','fightorflight','forbiddencandy','freshmeatdetector','fullmetaljacket',
    'gambling','ghostingenergy','ghostpepper','glitchedcartridge','gluttony','goblinglue',
    'grannysglasses','handwarmer','hexshades','hoarding','holynova','ignition','knockoffsword',
    'lazybullets','loafofbread','luckypenny','magnetism','maincharactersyndrome',
    'manifestingdamage','mentalhealthday','mimictrap','momsspaghetti','moodring',
    'necromancerspunchcard','overforge','phoenix','pickledlightning','pigeontrauma',
    'pocketblackhole','pocketlint','porcupinepanic','preworkoutexpired','rage',
    'reaperspunchcard','refrigerator','refundreceipt','restingbitchface','rustyspoon',
    'schrodingersbox','selfreflection','sentientcalculator','shockwave','slotmachine','smite',
    'snowball','soulsommelier','speedingticket','spikeprotein','squeakyhammer','staticsweater',
    'stickynote','stinkysock','stockholmsyndrome','taxreturn','tenthousandbees','totemfastpass',
    'turret','vampirefloss','wanderersboots','wizardsdiscountwand','yeetenergy','zombiemissile'
)

$Weapons = @(
    '9mm','arrowrain','aura','blackhole','burningforge','chainsaw','claws','combocounter',
    'coronabirus','diceroll','donation','dragonegg','drill','electrostaticgenerator',
    'explosivetaunt','fireball','firecracker','goblincatapult','gravitycannon','guidedmissile',
    'headsortails','implosion','judgmentarrow','meteor','mjolnir','mushroom','mysterioustrap',
    'olympusfist','plague','playingcard','pyromaniac','radioactivedust','shotgun','shuriken',
    'snowball','solarsystem','spiritualspear','tornado','voidrain','waterdrop','webshot',
    'wheeloffortune','whip','zeuslightning'
)

$Passives = @(
    'accelerant','acceleration','adrenaline','bloodcrit','chainbounce','coldprofessional',
    'compression','criticalmomentum','crowdbreaker','crushingblow','crushingpresence','deadeye',
    'dominance','escalation','executioncrit','executioner','fatalchain','finalround','firstround',
    'flurry','focusedfury','growingthreat','hyperactive','infiniterebound','instantdelivery',
    'luckybreak','machimpact','markedfordeath','massiveimpact','merchantsluck','merciless',
    'overflowingprecision','overflowingspeed','overkill','payback','perfectricochet','pinball',
    'predator','pressure','railgun','rebound','reboundvolley','ricochetexplosion','shatterpoint',
    'sizeoverflow','sonicboom','speedsplit','storedforce','supercrit','swarmintelligence',
    'terminalvelocity','titanslayer','tongue','trickshot','unhinged','velocitycrit'
)

# --- PlayerPrefs ------------------------------------------------------------

# Unity: имя значения в реестре = "<key>_h<hash>", hash = djb2 с XOR (seed 5381)
# по UTF-8 байтам. Проверено на 10 существующих ключах этой игры.
function Get-PrefHash {
    param([string] $Key)
    # 0xFFFFFFFF в PowerShell парсится как int32 -1, поэтому маска только как long
    [long] $mask = 4294967295
    [long] $h = 5381
    foreach ($b in [System.Text.Encoding]::UTF8.GetBytes($Key)) {
        $h = ((($h * 33) -band $mask) -bxor $b) -band $mask
    }
    return [uint32] $h
}

function Get-PrefValueName {
    param([string] $Key)
    return '{0}_h{1}' -f $Key, (Get-PrefHash $Key)
}

function Get-PrefString {
    param([string] $Key)
    $name = Get-PrefValueName $Key
    $item = Get-Item $PrefsPath
    if ($item.GetValueNames() -notcontains $name) { return $null }
    $bytes = $item.GetValue($name)
    if ($bytes -isnot [byte[]]) { return [string] $bytes }
    return [System.Text.Encoding]::UTF8.GetString($bytes).TrimEnd([char]0)
}

function Set-PrefString {
    param([string] $Key, [string] $Value)
    # PlayerPrefs.SetString -> REG_BINARY: UTF-8 + завершающий 0x00
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value) + [byte] 0
    Set-ItemProperty -Path $PrefsPath -Name (Get-PrefValueName $Key) -Value $bytes -Type Binary
}

function Set-PrefInt {
    param([string] $Key, [int] $Value)
    Set-ItemProperty -Path $PrefsPath -Name (Get-PrefValueName $Key) -Value $Value -Type DWord
}

# --- бэкап / восстановление -------------------------------------------------

function Backup-Prefs {
    if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir | Out-Null }
    $file = Join-Path $BackupDir ('prefs-{0}.reg' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    reg export $PrefsReg $file /y | Out-Null
    if (-not $?) { throw "не удалось сделать бэкап реестра" }
    Write-Host "  бэкап:   $file" -ForegroundColor DarkGray
    return $file
}

function Assert-GameClosed {
    $proc = Get-Process -Name 'Go Next demo' -ErrorAction SilentlyContinue
    if ($proc) {
        throw "Игра запущена. Закрой её полностью - иначе Unity затрёт правки при выходе."
    }
}

function Assert-PrefsExist {
    if (-not (Test-Path $PrefsPath)) {
        throw "Не найден $PrefsPath - запусти игру хотя бы раз, чтобы она создала настройки."
    }
}

# --- режимы -----------------------------------------------------------------

function Invoke-Dump {
    Assert-PrefsExist
    Write-Host ""
    Write-Host "Текущий прогресс" -ForegroundColor Cyan
    Write-Host ""
    foreach ($key in 'unlocks.items', 'unlocks.weapons', 'passives.unlocked') {
        $raw = Get-PrefString $key
        if ($null -eq $raw) {
            Write-Host ("  {0,-20} (ключа нет)" -f $key) -ForegroundColor DarkGray
            continue
        }
        if ([string]::IsNullOrEmpty($raw)) {
            Write-Host ("  {0,-20} пусто" -f $key) -ForegroundColor DarkGray
            continue
        }
        $parts = $raw -split '\|'
        Write-Host ("  {0,-20} {1} шт." -f $key, $parts.Count) -ForegroundColor Green
        Write-Host ("      {0}" -f ($parts -join ', ')) -ForegroundColor DarkGray
    }
    foreach ($key in 'bank.resources', 'loadout.last.v1', 'maps.visited', 'unlocks.version') {
        $raw = Get-PrefString $key
        if ($null -ne $raw) { Write-Host ("  {0,-20} {1}" -f $key, $raw) }
    }
    Write-Host ""
}

function Invoke-Apply {
    Assert-PrefsExist
    Assert-GameClosed

    Write-Host ""
    Write-Host "Открываю всё" -ForegroundColor Cyan
    Backup-Prefs | Out-Null

    Set-PrefString 'unlocks.items'     ($Items    -join '|')
    Write-Host ("  предметы:  {0}" -f $Items.Count) -ForegroundColor Green
    Set-PrefString 'unlocks.weapons'   ($Weapons  -join '|')
    Write-Host ("  оружие:    {0}" -f $Weapons.Count) -ForegroundColor Green
    Set-PrefString 'passives.unlocked' ($Passives -join '|')
    Write-Host ("  пассивки:  {0}" -f $Passives.Count) -ForegroundColor Green

    # банк ресурсов - CSV, длину массива не меняем, только значения
    $bank = Get-PrefString 'bank.resources'
    if (-not [string]::IsNullOrEmpty($bank)) {
        $count = ($bank -split ',').Count
        Set-PrefString 'bank.resources' (((1..$count) | ForEach-Object { $Resources }) -join ',')
        Write-Host ("  ресурсы:   {0} ячеек по {1}" -f $count, $Resources) -ForegroundColor Green
    }

    if (-not $KeepLeaderboardUpload) {
        # У игры есть ranked-режим и общая таблица Steam. Отключаем отправку очков,
        # чтобы прокачанные забеги не лезли в общий лидерборд.
        Set-PrefInt 'set_uploadScore' 0
        Set-PrefInt 'set.uploadScore' 0
        Write-Host "  лидерборд: отправка очков выключена" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Готово. Запускай игру и проверь экран Unlocks." -ForegroundColor Cyan
    Write-Host "Если что-то не так - .\gonext-cheat.ps1 -Restore" -ForegroundColor DarkGray
    Write-Host ""
}

function Invoke-Restore {
    if (-not (Test-Path $BackupDir)) { throw "Бэкапов нет ($BackupDir)" }
    $latest = Get-ChildItem $BackupDir -Filter '*.reg' | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $latest) { throw "Бэкапов нет ($BackupDir)" }
    Assert-GameClosed

    # выносим текущий ключ целиком, потом заливаем бэкап - иначе добавленные
    # скриптом значения останутся висеть
    if (Test-Path $PrefsPath) { Remove-Item -Path $PrefsPath -Recurse -Force }
    reg import $latest.FullName | Out-Null
    if (-not $?) { throw "не удалось импортировать $($latest.FullName)" }
    Write-Host ""
    Write-Host ("Восстановлено из {0}" -f $latest.Name) -ForegroundColor Cyan
    Write-Host ""
}

switch ($PSCmdlet.ParameterSetName) {
    'Apply'   { Invoke-Apply }
    'Restore' { Invoke-Restore }
    default   { Invoke-Dump }
}
