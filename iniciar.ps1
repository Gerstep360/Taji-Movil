param(
    [string]$Device
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$configPath = Join-Path $PSScriptRoot "assets\config\app_config.json"
if (-not (Test-Path $configPath)) {
    throw "Falta assets/config/app_config.json. Esta configuración se empaqueta también en release."
}

$config = Get-Content -Raw $configPath | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($config.apiBaseUrl)) {
    throw "apiBaseUrl no está definido en assets/config/app_config.json."
}

$apiUri = $null
$isValidUrl = [Uri]::TryCreate($config.apiBaseUrl, [UriKind]::Absolute, [ref]$apiUri)
if (-not $isValidUrl -or
    $apiUri.Scheme -notin @("http", "https") -or
    -not $apiUri.AbsolutePath.TrimEnd("/").EndsWith("/api/v1")) {
    throw "apiBaseUrl debe ser una URL HTTP(S) absoluta que termine en /api/v1."
}

$flutterArgs = @("run")
if (-not [string]::IsNullOrWhiteSpace($Device)) {
    $flutterArgs += @("-d", $Device)
}

Write-Host "Taji móvil usará: $($config.apiBaseUrl)" -ForegroundColor Cyan
Write-Host "La configuración está empaquetada y será la misma en release." -ForegroundColor DarkCyan
& flutter @flutterArgs
