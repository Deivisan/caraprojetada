# CaraProjetada - Instalação UltraVNC
# Executar como Administrador

param(
    [string]$Password = "123456",
    [switch]$SkipDownload
)

$ErrorActionPreference = "Stop"

Write-Host "[CaraProjetada] Instalando UltraVNC Server..." -ForegroundColor Green

# Download do UltraVNC (se necessário)
$uvncUrl = "https://github.com/ultravnc/UltraVNC/releases/download/1.4.3.0/UltraVNC_1430_X64_Setup.exe"
$installerPath = "$env:TEMP\UltraVNC_Setup.exe"

if (-not $SkipDownload) {
    Write-Host "[DOWNLOAD] Baixando UltraVNC..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $uvncUrl -OutFile $installerPath
}

# Instalação silenciosa
Write-Host "[INSTALL] Executando instalação..." -ForegroundColor Yellow
& $installerPath /VERYSILENT /SUPPRESSMSGBOXES /MERGETASKS="installservice" | Out-Null

# Configura o serviço
Write-Host "[CONFIG] Configurando senha VNC..." -ForegroundColor Yellow

# UltraVNC usa encriptação específica - precisamos gerar o hash
# O utilitário winvnc.exe tem opção para isso

$uvncDir = "C:\Program Files\UltraVNC"
Set-Location $uvncDir

# Gera senha criptografada
Start-Process -FilePath ".\winvnc.exe" -ArgumentList "-storepassword $Password" -Wait

# Atualiza config.ini para aceitar conexões
$configContent = Get-Content ".\ultravnc.ini"
$configContent = $configContent -replace "AcceptSocketConn=0", "AcceptSocketConn=1"
$configContent = $configContent -replace "LoopbackOnly=1", "LoopbackOnly=0"
$configContent | Set-Content ".\ultravnc.ini"

# Inicia o serviço
Write-Host "[SERVICE] Iniciando UltraVNC..." -ForegroundColor Yellow
Start-Service -Name "UltraVNC Server" -ErrorAction SilentlyContinue

# Abre firewall
Write-Host "[FIREWALL] Configurando regra..." -ForegroundColor Yellow
netsh advfirewall firewall add rule name="UltraVNC Server" dir=in action=allow protocol=TCP localport=5900 | Out-Null

Write-Host "[OK] UltraVNC instalado e configurado!" -ForegroundColor Green
Write-Host "[PASSWORD] VNC Password: $Password" -ForegroundColor Cyan

# Retorna senha para o cliente Python
Write-Output $Password