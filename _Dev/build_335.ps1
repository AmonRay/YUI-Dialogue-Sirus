# Builds a ready-to-install copy of the addon for WoW 3.3.5a.
#
# The 3.3.5a client only lists an addon when the folder name matches the .toc
# name: Interface\AddOns\DialogueUI\DialogueUI.toc. A git clone named
# "YUI-Dialogue" or "YUI-Dialogue-Sirus" is ignored by the game.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File _Dev\build_335.ps1
#   powershell -ExecutionPolicy Bypass -File _Dev\build_335.ps1 -AddOnsDir "D:\World of Warcraft 3.3.5a\Interface\AddOns"

param(
    [string]$AddOnsDir = ""
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$addonName = "DialogueUI"

if ($AddOnsDir -eq "") {
    $AddOnsDir = Join-Path $repo "_Build"
}
$target = Join-Path $AddOnsDir $addonName

$exclude = @(".git", ".github", ".idea", ".vscode", "_Dev", "_Build", ".gitattributes", ".gitignore")

if (Test-Path $target) {
    Remove-Item $target -Recurse -Force
}
New-Item -ItemType Directory -Path $target -Force | Out-Null

Get-ChildItem -Path $repo -Force | Where-Object { $exclude -notcontains $_.Name } | ForEach-Object {
    Copy-Item $_.FullName -Destination $target -Recurse -Force
}

$toc = Join-Path $target "$addonName.toc"
if (-not (Test-Path $toc)) {
    throw "$addonName.toc not found in $target"
}

Write-Host "Built: $target"
Write-Host "Copy this folder to <WoW 3.3.5a>\Interface\AddOns\ (the folder must be named $addonName)."
