# Playwright In Docker

This repo now includes a Docker-based Playwright smoke test setup so browser tests can run without installing Node or browsers on the shared host.

## Run the local test stack

From `hbcantipolo-site/`:

```powershell
docker compose -f docker-compose.playwright.yml up --build --abort-on-container-exit playwright
```

This starts:

- `web`: an `nginx` container serving either the repo or a pulled live snapshot
- `playwright`: the official Playwright container that installs test dependencies and runs the suite

## Choose the Playwright image version

The Docker image tag is configurable so you can move off an older pinned image without editing the compose file each time.

PowerShell example:

```powershell
$env:PLAYWRIGHT_IMAGE_TAG="v1.55.0-noble"
docker compose -f docker-compose.playwright.yml up --build --abort-on-container-exit playwright
```

If you want to switch back, close the terminal or clear the variable:

```powershell
Remove-Item Env:PLAYWRIGHT_IMAGE_TAG
```

## View the site locally

```powershell
docker compose -f docker-compose.playwright.yml up --build web
```

Then open `http://127.0.0.1:8081`.

## Pull the live site, then test it

If you want Docker to test the current live server files instead of the repo working copy, first create `deploy/targets.local.ps1`, then run:

```powershell
powershell -ExecutionPolicy Bypass -File deploy/test-live.ps1 -Target antipolo
```

This flow:

- downloads a fresh snapshot from the SSH host into `.live-snapshots/antipolo`
- points the `web` container at that snapshot
- runs the Playwright suite against the pulled live files

If you only want the snapshot without running tests:

```powershell
powershell -ExecutionPolicy Bypass -File deploy/sync-live.ps1 -Target antipolo
```

To preview that snapshot in Docker after syncing:

```powershell
$env:SITE_ROOT = ".live-snapshots/antipolo"
docker compose -f docker-compose.playwright.yml up web
```

## Run against another base URL

The tests use `PLAYWRIGHT_BASE_URL`. For example, to target production instead of the local container:

```powershell
docker run --rm ^
  -e PLAYWRIGHT_BASE_URL=https://hbcantipolo.com ^
  -v ${PWD}:/work -w /work ^
  mcr.microsoft.com/playwright:v1.52.0-noble ^
  bash -lc "npm install && npx playwright test"
```

## What is included

- `package.json`: Playwright and helper dependencies
- `playwright.config.js`: base config and reporting
- `tests/smoke.spec.js`: starter smoke coverage for the homepage and visit page
- `docker-compose.playwright.yml`: repeatable local container workflow
