param(
    [string]$ApiBaseUrl,
    [string]$MachineIp,
    [int]$ApiPort = 8000,
    [string]$Device
)

$ErrorActionPreference = "Stop"

function Get-TajiLanIPv4 {
    param([string]$PreferredAddress)

    if (-not [string]::IsNullOrWhiteSpace($PreferredAddress)) {
        $parsedAddress = $null
        if (-not [System.Net.IPAddress]::TryParse($PreferredAddress, [ref]$parsedAddress)) {
            throw "La dirección '$PreferredAddress' no es una IP válida."
        }
        return $PreferredAddress
    }

    $candidate = Get-NetIPConfiguration |
        Where-Object {
            $_.NetAdapter.Status -eq "Up" -and
            $null -ne $_.IPv4Address -and
            $null -ne $_.IPv4DefaultGateway -and
            $_.IPv4Address.IPAddress -notlike "169.254.*"
        } |
        Sort-Object { $_.NetAdapter.InterfaceMetric } |
        Select-Object -First 1

    if ($null -eq $candidate) {
        throw "No se encontró una IPv4 LAN activa. Usa -MachineIp."
    }
    return $candidate.IPv4Address.IPAddress
}

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $lanIp = Get-TajiLanIPv4 -PreferredAddress $MachineIp
    $ApiBaseUrl = "http://${lanIp}:$ApiPort/api/v1"
}
$ApiBaseUrl = $ApiBaseUrl.TrimEnd("/")
$configPath = Join-Path $PSScriptRoot "assets\config\app_config.json"
$config = @{
    apiBaseUrl = $ApiBaseUrl
    connectTimeoutMs = 12000
    receiveTimeoutMs = 12000
} | ConvertTo-Json
[System.IO.File]::WriteAllText($configPath, $config, (New-Object System.Text.UTF8Encoding($false)))

$flutterArgs = @("run")
if (-not [string]::IsNullOrWhiteSpace($Device)) {
    $flutterArgs += @("-d", $Device)
}

Write-Host "Taji móvil usará: $ApiBaseUrl" -ForegroundColor Cyan
Write-Host "La configuración quedó guardada en assets/config/app_config.json y se incluirá en release." -ForegroundColor DarkCyan
Set-Location $PSScriptRoot
& flutter @flutterArgs