<#
    fix-coremodule.ps1 — чинит UnityEngine.CoreModule.dll, сгенерированный MelonLoader.

    Ошибка, которую лечит скрипт:

        BadImageFormatException: Duplicate type with name '<>O'
        ... -> [ERROR] No Support Module Loaded!

    Использование:
        .\tools\fix-coremodule.ps1
        .\tools\fix-coremodule.ps1 -Check
        .\tools\fix-coremodule.ps1 -GameDir "D:\SteamLibrary\steamapps\common\Go Next! Demo"

    Если -GameDir не указан, скрипт ищет игру в Steam libraries автоматически.
    Mono.Cecil берётся рядом со скриптом, из локального NuGet cache или скачивается
    с NuGet в локальный cache NEXTBREAKER.
#>

param(
    [switch] $Check,
    [string] $GameDir
)

$ErrorActionPreference = 'Stop'
$GameName = 'Go Next! Demo'
$CoreModuleRelative = 'MelonLoader\Il2CppAssemblies\UnityEngine.CoreModule.dll'

function Test-GameDir {
    param([string] $Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    return Test-Path (Join-Path $Path $CoreModuleRelative)
}

function Resolve-GameDir {
    param([string] $Requested)

    if (-not [string]::IsNullOrWhiteSpace($Requested)) {
        $resolved = [System.IO.Path]::GetFullPath($Requested)
        if (-not (Test-GameDir $resolved)) {
            throw "В '$resolved' не найден $CoreModuleRelative. Убедись, что MelonLoader установлен и игра хотя бы один раз запускалась."
        }
        return $resolved
    }

    $candidates = New-Object System.Collections.Generic.List[string]

    # Старое поведение оставляем как fallback: repo может лежать прямо в папке игры.
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $candidates.Add($repoRoot)

    # Текущая директория тоже иногда является папкой игры.
    $candidates.Add((Get-Location).Path)

    # Стандартный Steam root.
    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    $steamRoot = $null
    if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
        $steamRoot = Join-Path $programFilesX86 'Steam'
    }

    $steamLibraries = New-Object System.Collections.Generic.List[string]
    if ($steamRoot -and (Test-Path $steamRoot)) {
        $steamLibraries.Add($steamRoot)

        $libraryVdf = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (Test-Path $libraryVdf) {
            $raw = Get-Content $libraryVdf -Raw
            foreach ($match in [regex]::Matches($raw, '"path"\s+"([^"]+)"')) {
                $library = $match.Groups[1].Value -replace '\\\\', '\'
                if (-not [string]::IsNullOrWhiteSpace($library)) {
                    $steamLibraries.Add($library)
                }
            }
        }
    }

    # Частые кастомные Steam libraries.
    foreach ($drive in 'C','D','E','F') {
        $steamLibraries.Add(("$drive" + ':\SteamLibrary'))
    }

    foreach ($library in ($steamLibraries | Select-Object -Unique)) {
        $candidates.Add((Join-Path $library ("steamapps\common\$GameName")))
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-GameDir $candidate) {
            return [System.IO.Path]::GetFullPath($candidate)
        }
    }

    throw @"
Не удалось автоматически найти папку игры.

Передай путь явно:
  .\tools\fix-coremodule.ps1 -GameDir "D:\SteamLibrary\steamapps\common\Go Next! Demo"

Нужен каталог, внутри которого существует:
  $CoreModuleRelative
"@
}

function Resolve-Cecil {
    $nextToScript = Join-Path $PSScriptRoot 'Mono.Cecil.dll'
    if (Test-Path $nextToScript) { return $nextToScript }

    $nugetRoot = Join-Path $env:USERPROFILE '.nuget\packages\mono.cecil'
    if (Test-Path $nugetRoot) {
        $versions = Get-ChildItem $nugetRoot -Directory | Sort-Object Name -Descending
        foreach ($version in $versions) {
            foreach ($tfm in 'net40','netstandard2.0') {
                $candidate = Join-Path $version.FullName ("lib\$tfm\Mono.Cecil.dll")
                if (Test-Path $candidate) { return $candidate }
            }
        }
    }

    $version = '0.11.6'
    $cacheRoot = Join-Path $env:LOCALAPPDATA "NEXTBREAKER\deps\Mono.Cecil\$version"
    $cached = Join-Path $cacheRoot 'lib\net40\Mono.Cecil.dll'
    if (Test-Path $cached) { return $cached }

    if (-not (Test-Path $cacheRoot)) {
        New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
    }

    $zip = Join-Path $env:TEMP ("Mono.Cecil.$version." + [guid]::NewGuid().ToString('N') + '.zip')
    try {
        Write-Host "Mono.Cecil не найден локально, скачиваю $version с NuGet..." -ForegroundColor Yellow
        Invoke-WebRequest -UseBasicParsing -Uri "https://www.nuget.org/api/v2/package/Mono.Cecil/$version" -OutFile $zip
        Expand-Archive -Path $zip -DestinationPath $cacheRoot -Force
    }
    catch {
        throw "Не удалось получить Mono.Cecil автоматически: $($_.Exception.Message). Скачай пакет Mono.Cecil $version вручную и положи lib\net40\Mono.Cecil.dll рядом с fix-coremodule.ps1."
    }
    finally {
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path $cached)) {
        throw "Mono.Cecil скачан, но $cached не найден."
    }

    return $cached
}

$GameDir = Resolve-GameDir $GameDir
$Il2Dir  = Join-Path $GameDir 'MelonLoader\Il2CppAssemblies'
$Target  = Join-Path $Il2Dir 'UnityEngine.CoreModule.dll'

Write-Host ""
Write-Host "GameDir:    $GameDir" -ForegroundColor DarkGray
Write-Host "CoreModule: $Target" -ForegroundColor Cyan

$before = (Get-Item $Target).Length
Write-Host ("  размер: {0:N0} байт" -f $before) -ForegroundColor DarkGray

$marker = Join-Path $Il2Dir 'UnityEngine.CoreModule.dll.orig'
$stamp  = Join-Path $Il2Dir 'UnityEngine.CoreModule.fixed.sha256'

function Get-Sha256 {
    param([string] $Path)
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
}

$targetHash = Get-Sha256 $Target
$alreadyFixed = $false
if ((Test-Path $stamp) -and (Test-Path $marker)) {
    if ((Get-Content $stamp -Raw).Trim() -eq $targetHash) {
        $alreadyFixed = $true
    }
}

if ($alreadyFixed) {
    Write-Host "  статус: уже починено" -ForegroundColor Green
} else {
    Write-Host "  статус: сборка свежая, починка нужна" -ForegroundColor Yellow
}

if ($Check) {
    Write-Host ""
    return
}

if ($alreadyFixed) {
    Write-Host ""
    return
}

$process = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Go Next*' } | Select-Object -First 1
if ($process) {
    throw "Игра сейчас запущена (PID $($process.Id)). Закрой её и повтори запуск скрипта."
}

$Cecil = Resolve-Cecil
Write-Host "  Cecil:   $Cecil" -ForegroundColor DarkGray
Add-Type -Path $Cecil

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
}
finally {
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
