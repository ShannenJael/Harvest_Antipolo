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

$indexPath = Join-Path $repoRoot "index.html"
if (-not (Test-Path $indexPath)) {
    throw "Local index.html not found."
}

$indexText = Get-Content $indexPath -Raw
$expected = $cfg.ExpectedText
$antiExpected = if ($Target -eq "antipolo") { "Harvest Baptist Church San Juan" } else { "Harvest Baptist Church Antipolo" }

if ($indexText -notmatch [regex]::Escape($expected)) {
    throw "Safety check failed: local index.html does not contain '$expected'. Aborting."
}
if ($indexText -match [regex]::Escape($antiExpected)) {
    throw "Safety check failed: local index.html contains '$antiExpected'. Aborting."
}

if (-not (Test-Path $cfg.KeyPath)) {
    throw "SSH key not found: $($cfg.KeyPath)"
}

$remote = "$($cfg.User)@$($cfg.Host)"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupName = "public_html_pre_${Target}_deploy_${timestamp}.tgz"
$backupPath = "/home/$($cfg.User)/backups/$backupName"

Write-Host "Target: $Target"
Write-Host "Remote: $remote"
Write-Host "Path:   $($cfg.RemotePath)"
Write-Host "Backup: $backupPath"

$backupCmd = @"
mkdir -p /home/$($cfg.User)/backups &&
tar -czf '$backupPath' -C '$($cfg.RemotePath)' index.html manifest.json sw.js css js images pages php data .gitignore .htaccess-redirect Dockerfile make_pages.py new_movers_202601120128.xlsx 'HBC Logo colored.png' 'HBC Logo white.png' 'Harvest Cover Photo.png' 2>/dev/null || true
"@

ssh -i $cfg.KeyPath $remote $backupCmd

$uploadItems = @(
    "index.html",
    "manifest.json",
    "sw.js",
    "css",
    "js",
    "images",
    "pages",
    "php",
    "data",
    ".gitignore",
    ".htaccess-redirect",
    "Dockerfile",
    "make_pages.py",
    "new_movers_202601120128.xlsx",
    "HBC Logo colored.png",
    "HBC Logo white.png",
    "Harvest Cover Photo.png"
)

Push-Location $repoRoot
try {
    scp -i $cfg.KeyPath -r @uploadItems "$remote`:$($cfg.RemotePath)/"
} finally {
    Pop-Location
}

$permCmd = @"
find '$($cfg.RemotePath)/css' '$($cfg.RemotePath)/js' '$($cfg.RemotePath)/images' '$($cfg.RemotePath)/pages' '$($cfg.RemotePath)/php' '$($cfg.RemotePath)/data' -type d -exec chmod 755 {} + &&
find '$($cfg.RemotePath)/css' '$($cfg.RemotePath)/js' '$($cfg.RemotePath)/images' '$($cfg.RemotePath)/pages' '$($cfg.RemotePath)/php' '$($cfg.RemotePath)/data' -type f -exec chmod 644 {} + &&
chmod 644 '$($cfg.RemotePath)/index.html' '$($cfg.RemotePath)/manifest.json' '$($cfg.RemotePath)/sw.js' '$($cfg.RemotePath)/.gitignore' '$($cfg.RemotePath)/.htaccess-redirect' '$($cfg.RemotePath)/Dockerfile' '$($cfg.RemotePath)/make_pages.py' '$($cfg.RemotePath)/new_movers_202601120128.xlsx' '$($cfg.RemotePath)/HBC Logo colored.png' '$($cfg.RemotePath)/HBC Logo white.png' '$($cfg.RemotePath)/Harvest Cover Photo.png'
"@

ssh -i $cfg.KeyPath $remote $permCmd

$verifyCmd = "head -n 30 '$($cfg.RemotePath)/index.html'"
$verifyOut = ssh -i $cfg.KeyPath $remote $verifyCmd | Out-String

if ($verifyOut -notmatch [regex]::Escape($expected)) {
    throw "Post-deploy verification failed: remote index.html missing '$expected'."
}
if ($verifyOut -match [regex]::Escape($antiExpected)) {
    throw "Post-deploy verification failed: remote index.html still contains '$antiExpected'."
}

Write-Host ""
Write-Host "Deploy completed safely for '$Target'."
Write-Host "Backup stored at: $backupPath"
