param([string] $GameDir = 'D:\SteamLibrary\steamapps\common\Go Next! Demo')
$ErrorActionPreference = 'Stop'
if (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Go Next*' }) {
    throw 'Close Go Next before installing.'
}
if (-not (Test-Path -LiteralPath (Join-Path $GameDir 'MelonLoader\net6\MelonLoader.dll'))) {
    throw 'MelonLoader is not installed in the selected game directory.'
}
$files = @{
    'GoNextTrainer.dll' = 'Mods\GoNextTrainer.dll'
    'GoNextCoreRepair.dll' = 'Plugins\GoNextCoreRepair.dll'
}
foreach ($name in $files.Keys) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $name))) { throw "Missing package file: $name" }
}
$backupDir = Join-Path $GameDir ('cheat-backups\NEXTBREAKER-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
foreach ($name in $files.Keys) {
    $source = Join-Path $PSScriptRoot $name
    $target = Join-Path $GameDir $files[$name]
    if (Test-Path -LiteralPath $target) { Copy-Item -LiteralPath $target -Destination (Join-Path $backupDir $name) }
    New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Force
    if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $target).Hash) { throw "Verification failed: $target" }
}
$settings = Join-Path $GameDir 'UserData\GoNextTrainer.steps.cfg'
if (-not (Test-Path -LiteralPath $settings)) {
    New-Item -ItemType Directory -Path (Split-Path $settings) -Force | Out-Null
    Set-Content -LiteralPath $settings -Value "KillStep=50000`nTimeStepSeconds=300`nAutoItems=true" -Encoding ascii
}
Write-Host 'NEXTBREAKER 1.8.0 installed. Start the game: CoreModule will be repaired before mods load.'
