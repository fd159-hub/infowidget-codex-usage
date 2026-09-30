param(
    [string]$TargetPath = "D:\Documents\Rainmeter\Skins\InfoWidget"
)

$ErrorActionPreference = "Stop"

$sourcePath = $PSScriptRoot

if (-not (Test-Path -LiteralPath $TargetPath)) {
    New-Item -ItemType Directory -Force -Path $TargetPath | Out-Null
}

$backupPath = Join-Path (Split-Path -Parent $TargetPath) ("InfoWidget.backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
if (Test-Path -LiteralPath $TargetPath) {
    Copy-Item -LiteralPath $TargetPath -Destination $backupPath -Recurse -Force
}

Copy-Item -LiteralPath (Join-Path $sourcePath "CodexUsage.ini") -Destination $TargetPath -Force

$targetResources = Join-Path $TargetPath "@Resources"
$targetScripts = Join-Path $targetResources "Scripts"
New-Item -ItemType Directory -Force -Path $targetScripts | Out-Null

Copy-Item -LiteralPath (Join-Path $sourcePath "@Resources\Scripts\Get-CodexUsage.ps1") -Destination $targetScripts -Force

$targetJson = Join-Path $targetResources "codex-usage.json"
if (-not (Test-Path -LiteralPath $targetJson)) {
    Copy-Item -LiteralPath (Join-Path $sourcePath "@Resources\codex-usage.example.json") -Destination $targetJson -Force
}

Write-Host "Installed InfoWidget Codex Usage to:"
Write-Host "  $TargetPath"
Write-Host ""
Write-Host "Backup:"
Write-Host "  $backupPath"
Write-Host ""
Write-Host "Rainmeter skin:"
Write-Host "  InfoWidget\CodexUsage.ini"
