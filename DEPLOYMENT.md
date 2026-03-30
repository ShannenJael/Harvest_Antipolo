# Deployment Safety

Use the guarded deploy script so Antipolo and San Juan cannot be mixed.

## 1) Configure separate SSH keys

Create one key per church:

- `id_ed25519_antipolo`
- `id_ed25519_sanjuan`

## 2) Create local target config

Copy:

```powershell
Copy-Item deploy/targets.example.ps1 deploy/targets.local.ps1
```

Then set each target's:

- `Host`
- `User`
- `RemotePath`
- `KeyPath`
- `ExpectedText`

`deploy/targets.local.ps1` is ignored by git.

## 3) Deploy with explicit target

```powershell
powershell -ExecutionPolicy Bypass -File deploy/deploy.ps1 -Target antipolo
```

Or:

```powershell
powershell -ExecutionPolicy Bypass -File deploy/deploy.ps1 -Target sanjuan
```

## 4) Safest option for small edits

For text changes or one-page fixes, do not edit files in place on the live server.

Upload only the file you changed:

```powershell
powershell -ExecutionPolicy Bypass -File deploy/upload-file.ps1 -Target antipolo -Paths pages/visitors-card.html
```

You can also upload multiple files safely:

```powershell
powershell -ExecutionPolicy Bypass -File deploy/upload-file.ps1 -Target antipolo -Paths index.html,pages/about.html
```

This script:

- backs up the current remote file first
- refuses to upload empty local files
- uploads only the selected files
- verifies the uploaded files are non-empty on the server

Use `deploy.ps1` only when you intend to publish the full site.

## Safety checks included

- Fails if local `index.html` does not match target church text.
- Fails if local `index.html` contains the other church text.
- Backs up remote files before upload.
- Fixes file/directory permissions after upload.
- Verifies remote `index.html` after upload.
