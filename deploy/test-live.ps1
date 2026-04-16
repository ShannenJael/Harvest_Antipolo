param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("antipolo", "sanjuan")]
    [string]$Target,

    [string]$PlaywrightImageTag = "v1.52.0-noble"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$snapshotRoot = Join-Path $repoRoot ".live-snapshots\$Target"
$syncScript = Join-Path $PSScriptRoot "sync-live.ps1"

if (-not (Test-Path $syncScript)) {
    throw "Missing sync script: $syncScript"
}

& $syncScript -Target $Target

$env:SITE_ROOT = $snapshotRoot
$env:PLAYWRIGHT_IMAGE_TAG = $PlaywrightImageTag

try {
    Push-Location $repoRoot
    try {
        docker compose -f docker-compose.playwright.yml up --build --abort-on-container-exit playwright
    } finally {
        Pop-Location
    }
} finally {
    Remove-Item Env:SITE_ROOT -ErrorAction SilentlyContinue
    Remove-Item Env:PLAYWRIGHT_IMAGE_TAG -ErrorAction SilentlyContinue
}
