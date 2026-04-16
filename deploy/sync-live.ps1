param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("antipolo", "sanjuan")]
    [string]$Target
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$targetsFile = Join-Path $PSScriptRoot "targets.local.ps1"

if (-not (Test-Path $targetsFile)) {
    throw "Missing deploy/targets.local.ps1. Copy deploy/targets.example.ps1 and fill it first."
}

. $targetsFile

if (-not $DeployTargets.ContainsKey($Target)) {
    throw "Target '$Target' is not configured in deploy/targets.local.ps1."
}

$cfg = $DeployTargets[$Target]

foreach ($required in @("Host", "User", "RemotePath", "KeyPath", "ExpectedText")) {
    if (-not $cfg.ContainsKey($required) -or [string]::IsNullOrWhiteSpace($cfg[$required])) {
        throw "Target '$Target' is missing required field '$required'."
    }
}

if (-not (Test-Path $cfg.KeyPath)) {
    throw "SSH key not found: $($cfg.KeyPath)"
}

$remote = "$($cfg.User)@$($cfg.Host)"
$snapshotRoot = Join-Path $repoRoot ".live-snapshots\$Target"
$itemsToPull = @(
    "index.html",
    "manifest.json",
    "sw.js",
    "style.css",
    "info-box-override.css",
    ".htaccess",
    ".htaccess-redirect",
    "css",
    "js",
    "images",
    "pages",
    "php",
    "data"
)

if (Test-Path $snapshotRoot) {
    Remove-Item -LiteralPath $snapshotRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $snapshotRoot | Out-Null

Push-Location $snapshotRoot
try {
    foreach ($item in $itemsToPull) {
        Write-Host "Pulling $item"
        scp -i $cfg.KeyPath -r "$remote`:$($cfg.RemotePath)/$item" .
    }
} finally {
    Pop-Location
}

$snapshotIndex = Join-Path $snapshotRoot "index.html"
if (-not (Test-Path $snapshotIndex)) {
    throw "Sync failed: snapshot index.html was not downloaded."
}

$indexText = Get-Content $snapshotIndex -Raw
if ($indexText -notmatch [regex]::Escape($cfg.ExpectedText)) {
    throw "Sync safety check failed: snapshot index.html does not contain '$($cfg.ExpectedText)'."
}

Write-Host ""
Write-Host "Live snapshot saved to: $snapshotRoot"
