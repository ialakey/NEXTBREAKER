<#
    fix-coremodule.ps1 — чинит UnityEngine.CoreModule.dll, сгенерированный MelonLoader.

    Зачем: Il2CppInterop на этой игре выдаёт CoreModule с битыми записями типов,
    и .NET отказывается её грузить:

        BadImageFormatException: Duplicate type with name '<>O'
        ... -> [ERROR] No Support Module Loaded!

    Без модуля поддержки MelonLoader не даёт модам игровой цикл, то есть
    трейнер не работает вообще.

    Лечение: перечитать сборку через Mono.Cecil и записать заново. Cecil
    строит метаданные из своей объектной модели, битые записи в неё не
    попадают, и на выходе получается корректная сборка.

    Когда запускать: после любого обновления игры в Steam — MelonLoader
    перегенерирует сборки, и дефект вернётся.

    Использование:
        .\fix-coremodule.ps1            # починить
        .\fix-coremodule.ps1 -Check     # только проверить, не трогая файлы
#>

param([switch] $Check)

$ErrorActionPreference = 'Stop'

$GameDir = Split-Path $PSScriptRoot -Parent
$Il2Dir  = Join-Path $GameDir 'MelonLoader\Il2CppAssemblies'
$Target  = Join-Path $Il2Dir 'UnityEngine.CoreModule.dll'
$Cecil   = Join-Path $PSScriptRoot 'Mono.Cecil.dll'

if (-not (Test-Path $Target)) {
    throw "Не найден $Target. Запусти игру один раз, чтобы MelonLoader сгенерировал сборки."
}
if (-not (Test-Path $Cecil)) {
    throw "Не найден $Cecil"
}

Add-Type -Path $Cecil

$before = (Get-Item $Target).Length
Write-Host ""
Write-Host "CoreModule: $Target" -ForegroundColor Cyan
Write-Host ("  размер: {0:N0} байт" -f $before) -ForegroundColor DarkGray

$marker = Join-Path $Il2Dir 'UnityEngine.CoreModule.dll.orig'
$stamp  = Join-Path $Il2Dir 'UnityEngine.CoreModule.fixed.sha256'

function Get-Sha256 {
    param([string] $Path)
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
}

# Состояние определяем по хешу, а не по времени файла: после нашей починки
# цель всегда новее .orig, и по таймстемпам починенный файл неотличим от
# свежесгенерированного. Если хеш цели совпадает с записанным — работа сделана.
$targetHash = Get-Sha256 $Target
$alreadyFixed = $false
if ((Test-Path $stamp) -and (Test-Path $marker)) {
    if ((Get-Content $stamp -Raw).Trim() -eq $targetHash) { $alreadyFixed = $true }
}

if ($alreadyFixed) {
    Write-Host "  статус: уже починено" -ForegroundColor Green
} else {
    Write-Host "  статус: сборка свежая, починка нужна" -ForegroundColor Yellow
}

if ($Check) { Write-Host ""; return }
if ($alreadyFixed) { Write-Host ""; return }

# цель сейчас — оригинал от MelonLoader, сохраняем его как .orig
Copy-Item $Target $marker -Force
Write-Host "  бэкап:  UnityEngine.CoreModule.dll.orig" -ForegroundColor DarkGray

$rp = New-Object Mono.Cecil.ReaderParameters
$res = New-Object Mono.Cecil.DefaultAssemblyResolver
$res.AddSearchDirectory($Il2Dir)
$rp.AssemblyResolver = $res
$rp.ReadingMode = [Mono.Cecil.ReadingMode]::Immediate

$tmp = Join-Path $env:TEMP ('CoreModule.fixed.{0}.dll' -f [guid]::NewGuid().ToString('N'))

$asm = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($marker, $rp)
try {
    $asm.Write($tmp)
} finally {
    $asm.Dispose()
}

Copy-Item $tmp $Target -Force
Remove-Item $tmp -Force -ErrorAction SilentlyContinue

Set-Content -Path $stamp -Value (Get-Sha256 $Target) -Encoding ascii

$after = (Get-Item $Target).Length
Write-Host ("  готово: {0:N0} байт" -f $after) -ForegroundColor Green
Write-Host ""
Write-Host "Запускай игру. В MelonLoader\Latest.log должно быть 'Support Module Loaded'." -ForegroundColor Cyan
Write-Host ""
