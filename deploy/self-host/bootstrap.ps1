# ==============================================================================
# LearningApp Turnkey Self-Hosting Bootstrap Script (PowerShell)
# ==============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  LearningApp Turnkey Self-Hosting Infrastructure Setup  " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)

Set-Location $ScriptDir

# 1. Environment file check
if (-not (Test-Path ".env")) {
    Write-Host "[SETUP] Creating .env from .env.example..." -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
    Write-Host "[WARNING] Generated default .env. For production, edit deploy/self-host/.env with secure credentials." -ForegroundColor Yellow
}

# 2. Re-compile consolidated migration schema bundle
Write-Host "[MIGRATIONS] Compiling database schema bundle from migrations..." -ForegroundColor Yellow
Push-Location $RootDir
try {
    dart run tool/self_host_bootstrap.dart --generate-bundle deploy/self-host/init-scripts/01-full-schema.sql
} finally {
    Pop-Location
}

# 3. Check for docker compose
if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
    Write-Error "[ERROR] Docker is not installed or not in PATH."
    exit 1
}

Write-Host "[DOCKER] Starting LearningApp services via Docker Compose..." -ForegroundColor Green
docker compose up -d

Write-Host "[HEALTH] Waiting for PostgreSQL database to become healthy..." -ForegroundColor Yellow
$maxAttempts = 30
$attempt = 0
while ($attempt -lt $maxAttempts) {
    $status = docker inspect -f '{{.State.Health.Status}}' learningapp-db 2>$null
    if ($status -eq "healthy") {
        break
    }
    Start-Sleep -Seconds 2
    $attempt++
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "LearningApp Self-Hosting Stack is Ready!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "API Gateway (Kong):   http://localhost:8000"
Write-Host "REST API (PostgREST): http://localhost:8000/rest/v1"
Write-Host "Auth (GoTrue):        http://localhost:8000/auth/v1"
Write-Host "Storage API:          http://localhost:8000/storage/v1"
Write-Host ""
Write-Host "To connect your Flutter client to this self-hosted instance, run:" -ForegroundColor Cyan
Write-Host "  flutter run -d chrome --dart-define=SUPABASE_URL=http://localhost:8000 --dart-define=SUPABASE_ANON_KEY=<ANON_KEY>"
Write-Host "==========================================================" -ForegroundColor Green
