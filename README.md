# Playwright Docker DevBox

A Docker-based development environment for **Playwright** testing with integrated VS Code, Node.js 22, and a browser GUI for headed tests. Run tests locally or in CI/CD pipelines with support for parallel execution and remote test triggering.

## Overview

This project provides a complete containerized setup for:
- Writing and running **Playwright** tests (headless and headed modes)
- **Parallel test execution** - Run multiple concurrent `docker exec` jobs against a single container
- **Remote test triggering** - Execute tests from CI/CD pipelines (GitHub Actions, GitLab, etc.)
- Interactive code development with **VS Code** in the browser
- Visual test debugging with **noVNC** browser GUI
- Recording test scenarios with **Playwright Codegen**
- Viewing Playwright reports and traces with individual logging

## Features

✅ **Ubuntu/Linux Container** - Lightweight, portable Linux environment  
✅ **Playwright 2.0+** with all browsers (Chromium, Firefox, WebKit)  
✅ **Code Server 4.125.0** - Full VS Code experience in the browser  
✅ **Node.js 22** - Latest LTS runtime  
✅ **Parallel Test Execution** - Run 10+ concurrent `docker exec` jobs without conflicts  
✅ **CI/CD Integration** - GitHub Actions and GitLab CI/CD ready  
✅ **noVNC** - Remote desktop for headed Playwright tests  
✅ **Playwright Inspector** - Debug tests interactively  
✅ **Pre-installed Tools**: Git, sudo, and all OS dependencies  

## Prerequisites

- Docker installed on your system
- Port availability:
  - `8443` - Code Server UI
  - `9323` - Playwright reports/traces viewer
  - `6080` - noVNC (browser GUI)

## Quick Start

Follow these 5 steps to get started:

1. **Build** the Docker image
2. **Run** the container with port mappings
3. **Run Tests** using Playwright CLI
4. **View Results** with Playwright reports and traces
5. **Record Tests** using Playwright Codegen (optional)

See the **Usage** section below for detailed commands.

## Usage

### 1. Build the Image

```bash
docker build -t code-server-node .
```

### 2. Run the Container

```bash
docker run -d -p 8443:8443 -p 9323:9323 -p 6080:6080 --security-opt seccomp=unconfined -e PASSWORD=yourpassword code-server-node
```

**Port Reference:**
- `8443` = code-server (VS Code UI)
- `9323` = Playwright HTML report / trace viewer
- `6080` = noVNC (browser GUI for headed tests) — starts automatically

### 3. Run Tests

**Headless (no display needed):**
```bash
npx playwright test
```

**Headless with trace recording:**
```bash
npx playwright test --trace on
```

### 4. View Results

**View HTML report:**
```bash
npx playwright show-report --host 0.0.0.0 --port 9323
```

**View trace for the most recent test result:**
```bash
npx playwright show-trace --host 0.0.0.0 --port 9323 $(ls -t test-results/*/trace.zip 2>/dev/null | head -1)
```

### 5. Recording Tests with Codegen

> **Note:** Open [http://localhost:6080/vnc.html](http://localhost:6080/vnc.html) in your Windows browser → click Connect

**Record and display in Inspector:**
```bash
npx playwright codegen https://example.com
```

**Record directly to a test file:**
```bash
npx playwright codegen --output tests/recorded.spec.js https://example.com
```

## Port Mappings

| Port | Service | Purpose |
|------|---------|---------|
| `8443` | Code Server | VS Code web UI |
| `9323` | Playwright | HTML reports & trace viewer |
| `6080` | noVNC | Headed browser tests GUI |

## Remote Test Triggering

Run Playwright tests remotely from CI/CD pipelines, scheduled jobs.

### 1. Docker Exec (Running Container)

Execute tests in a running container:
```bash
docker exec <container_id> npx playwright test
```

Get container ID:
```bash
docker ps | grep code-server-node
```

### 2. GitHub Actions CI/CD

**File: `.github/workflows/playwright-tests.yml`**
```yaml
name: Playwright Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Playwright Tests in Container
        run: |
          CONTAINER_ID=$(docker ps -q -f ancestor=code-server-node)
          docker exec $CONTAINER_ID npx playwright test
```

### 3. GitLab CI/CD

**File: `.gitlab-ci.yml`**
```yaml
playwright_tests:
  image: docker:latest
  services:
    - docker:dind
  script:
    - CONTAINER_ID=$(docker ps -q -f ancestor=code-server-node)
    - docker exec $CONTAINER_ID npx playwright test
```

### 4. Parallel Docker Exec Jobs

Run multiple `docker exec` commands in parallel to the same container without conflicts. Each execution runs independently with isolated processes.

**Benefits:**
- ✅ Concurrent execution - all threads run simultaneously
- ✅ No conflicts - each process has isolated workers
- ✅ Scalable - container handles multiple concurrent `docker exec` calls
- ✅ Full logging support - capture individual thread outputs

**Basic Example (5 parallel jobs):**
```bash
CONTAINER_ID=$(docker ps -q -f ancestor=code-server-node)
for i in {1..5}; do
    docker exec $CONTAINER_ID npx playwright test --workers=1 &
done
wait
```

**With Individual Logging (10 parallel threads):**
```powershell
# PowerShell
$ContainerId = "YOUR_CONTAINER_ID"
$LogDir = ".\logs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

$jobs = @()
for ($i = 1; $i -le 10; $i++) {
    $logFile = "$LogDir\thread_$i.log"
    $job = Start-Job -ScriptBlock {
        param($cid, $num, $log)
        docker exec $cid npx playwright test --workers=1 *>&1 | Out-File -FilePath $log -Append
    } -ArgumentList $ContainerId, $i, $logFile
    $jobs += $job
    Write-Host "[Thread $i] Started" -ForegroundColor Green
}

Write-Host "Waiting for all jobs to complete..." -ForegroundColor Cyan
$jobs | Wait-Job

Write-Host "All jobs completed!" -ForegroundColor Green
Get-ChildItem $LogDir -File | ForEach-Object {
    Write-Host "`n[$($_.Name)]" -ForegroundColor Yellow
    Get-Content $_.FullName | Select-Object -Last 5
}
```

**Performance Notes:**
- Each `docker exec` is thread-safe and isolated
- All threads share container resources (CPU/memory limits apply)
- Total execution time ≈ longest individual thread (all run in parallel)
- Use `--workers=N` to control parallelism within each exec call

## Environment Variables

- `PASSWORD`: Set the VS Code login password (default: prompt on first login)
- `PLAYWRIGHT_BROWSERS_PATH`: Pre-configured at `/opt/ms-playwright`
- `DISPLAY`: Set to `:1` for X11 display server

## Dockerfile Details

- **Base Image**: `linuxserver/code-server:4.125.0` (Ubuntu/Linux based)
- **OS**: Ubuntu Linux (containerized)
- **Node.js**: Version 22 (via NodeSource repository)
- **Playwright**: Global installation with all browsers and OS dependencies
- **GUI**: Xvfb + Openbox + x11vnc + noVNC stack for headed tests
- **Auto-startup**: VNC services start automatically on container boot

## Playwright Inspector Configuration

The Dockerfile includes Openbox window manager configuration that automatically positions the Playwright Inspector:
- **Position**: Right side of the screen (1300x, 0y)
- **Size**: 620x1080px
- **Accessible via**: noVNC browser GUI at port 6080

## Troubleshooting

### Container Won't Start

Check Docker logs:
```bash
docker logs <container_id>
```

### Port Already in Use

Remap ports in the `docker run` command:
```bash
docker run -d -p 8444:8443 -p 9324:9323 -p 6081:6080 ...
```

### Tests Timeout or Fail

- Check noVNC connection for headed tests
- Verify all Playwright browsers are installed: `npx playwright install --with-deps`

## Resources

- [Playwright Documentation](https://playwright.dev)
- [Code Server Documentation](https://coder.com/docs/code-server)
- [Playwright Inspector Guide](https://playwright.dev/docs/inspector)

## License

This project is provided as-is for development and testing purposes.

---

**Last Updated**: 2026-06-22
