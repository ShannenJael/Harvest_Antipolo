param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("antipolo", "sanjuan")]
    [string]$Target,

    [Parameter(Mandatory = $true)]
    [string[]]$Paths
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
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$remoteRoot = if ($cfg.RemotePath -match "^(.+)/[^/]+$") { $Matches[1] } else { throw "Could not derive remote root from RemotePath '$($cfg.RemotePath)'." }
$backupDir = "$remoteRoot/backups/file_upload_${Target}_$timestamp"

$normalized = New-Object System.Collections.Generic.List[string]

foreach ($path in $Paths) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw "Empty path provided."
    }

    $clean = $path.Replace('\', '/').TrimStart('./')
    $localPath = Join-Path $repoRoot $clean

    if (-not (Test-Path $localPath)) {
        throw "Local path not found: $clean"
    }

    $item = Get-Item $localPath
    if ($item.PSIsContainer) {
        throw "Directories are not allowed here. Use deploy.ps1 for full-site deploys. Offending path: $clean"
    }

    if ($item.Length -eq 0) {
        throw "Refusing to upload empty file: $clean"
    }

    $normalized.Add($clean)
}

$uniquePaths = $normalized | Sort-Object -Unique

Write-Host "Target:     $Target"
Write-Host "Remote:     $remote"
Write-Host "RemotePath: $($cfg.RemotePath)"
Write-Host "BackupDir:  $backupDir"
Write-Host "Files:"
$uniquePaths | ForEach-Object { Write-Host "  - $_" }

$backupCmd = @(
    "mkdir -p '$backupDir'"
)

foreach ($path in $uniquePaths) {
    $remoteFile = "$($cfg.RemotePath)/$path"
    $backupCmd += "if [ -f '$remoteFile' ]; then mkdir -p '$backupDir/$(Split-Path $path -Parent)'; cp '$remoteFile' '$backupDir/$path'; fi"
}

ssh -i $cfg.KeyPath $remote ($backupCmd -join " && ")

Push-Location $repoRoot
try {
    foreach ($path in $uniquePaths) {
        $remoteDir = Split-Path $path -Parent
        if (-not [string]::IsNullOrWhiteSpace($remoteDir)) {
            ssh -i $cfg.KeyPath $remote "mkdir -p '$($cfg.RemotePath)/$remoteDir'" | Out-Null
        }

        scp -i $cfg.KeyPath $path "$remote`:$($cfg.RemotePath)/$path"
    }
} finally {
    Pop-Location
}

$verifyCmd = New-Object System.Collections.Generic.List[string]

foreach ($path in $uniquePaths) {
    $remoteFile = "$($cfg.RemotePath)/$path"
    $verifyCmd.Add("test -s '$remoteFile'")

    $ext = [IO.Path]::GetExtension($path).ToLowerInvariant()
    if ($ext -in @(".html", ".php", ".css", ".js", ".json", ".txt", ".xml", ".svg")) {
        $verifyCmd.Add("wc -c < '$remoteFile'")
    }
}

ssh -i $cfg.KeyPath $remote ($verifyCmd -join " && ") | Out-Null

Write-Host ""
Write-Host "Upload completed safely."
Write-Host "Remote backups stored at: $backupDir"
