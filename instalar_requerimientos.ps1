# ==============================================================================
# Script de Instalación de Requerimientos - Móvil Taji (Flutter)
# ==============================================================================

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   TAJI MOVIL - Instalación de Flutter y Pub      " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Verificar presencia del SDK de Flutter
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    throw "Flutter SDK no está instalado o no se encuentra en el PATH del sistema."
}

Write-Host "[1/3] SDK de Flutter detectado correctamente." -ForegroundColor Green

# 2. Descargar e instalar paquetes Dart/Flutter (pub get)
Write-Host "[2/3] Instalando dependencias con 'flutter pub get'..." -ForegroundColor Yellow
& flutter pub get

if ($LASTEXITCODE -eq 0) {
    Write-Host "      Dependencias de pub obtenidas exitosamente." -ForegroundColor Green
} else {
    throw "Ocurrió un error al ejecutar 'flutter pub get'."
}

# 3. Verificar o crear configuración inicial de app_config.json
$configDir = Join-Path $PSScriptRoot "assets\config"
$configPath = Join-Path $configDir "app_config.json"

if (-not (Test-Path $configPath)) {
    Write-Host "[3/3] Generando archivo de configuración inicial assets/config/app_config.json..." -ForegroundColor Yellow
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    $defaultConfig = @{
        apiBaseUrl = "http://10.0.2.2:8000/api/v1"
        connectTimeoutMs = 12000
        receiveTimeoutMs = 12000
    } | ConvertTo-Json
    [System.IO.File]::WriteAllText($configPath, $defaultConfig, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "      Archivo assets/config/app_config.json creado." -ForegroundColor Green
} else {
    Write-Host "[3/3] Archivo assets/config/app_config.json ya existe." -ForegroundColor Green
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "   Instalación completada con éxito." -ForegroundColor Green
Write-Host "   Puedes iniciar la aplicación móvil ejecutando:" -ForegroundColor Cyan
Write-Host "   .\iniciar.ps1" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Cyan
