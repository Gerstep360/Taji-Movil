# ==============================================================================
# Script de Instalación de Requerimientos - Móvil Taji (Flutter)
# ==============================================================================

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   TAJI MOVIL - Instalación de Flutter y Pub      " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    throw "Flutter SDK no está instalado o no se encuentra en el PATH del sistema."
}

Write-Host "[1/3] SDK de Flutter detectado correctamente." -ForegroundColor Green
Write-Host "[2/3] Instalando dependencias con 'flutter pub get'..." -ForegroundColor Yellow
& flutter pub get

if ($LASTEXITCODE -ne 0) {
    throw "Ocurrió un error al ejecutar 'flutter pub get'."
}
Write-Host "      Dependencias de pub obtenidas exitosamente." -ForegroundColor Green

$configPath = Join-Path $PSScriptRoot "assets\config\app_config.json"
if (-not (Test-Path $configPath)) {
    throw "Falta assets/config/app_config.json. Configura ahí la URL del Backend."
}

$config = Get-Content -Raw $configPath | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($config.apiBaseUrl)) {
    throw "apiBaseUrl no está definido en assets/config/app_config.json."
}
Write-Host "[3/3] API empaquetada: $($config.apiBaseUrl)" -ForegroundColor Green

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Instalación completada con éxito." -ForegroundColor Green
Write-Host "   Puedes iniciar la aplicación móvil ejecutando:" -ForegroundColor Cyan
Write-Host "   .\iniciar.ps1" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Cyan
