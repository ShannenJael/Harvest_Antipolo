# Copy this file to deploy/targets.local.ps1 and fill values.
# Keep targets.local.ps1 out of git (already ignored).

$DeployTargets = @{
    antipolo = @{
        Host         = "129.121.81.231"
        User         = "rzixjmmy"
        RemotePath   = "/home/rzixjmmy/public_html"
        KeyPath      = "C:/Users/your-user/.ssh/id_ed25519_antipolo"
        ExpectedText = "Harvest Baptist Church Antipolo"
    }
    sanjuan = @{
        Host         = "YOUR_SANJUAN_HOST"
        User         = "YOUR_SANJUAN_USER"
        RemotePath   = "/home/YOUR_SANJUAN_USER/public_html"
        KeyPath      = "C:/Users/your-user/.ssh/id_ed25519_sanjuan"
        ExpectedText = "Harvest Baptist Church San Juan"
    }
}
