# CaraProjetada - Provisionamento Automático Windows 11
# Execução: PowerShell como Administrador

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CaraProjetada Windows Client - Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Variáveis
$ProjectorHost = "projetores.intranet.ufrb.edu.br"
$VNCPort = 5900

# 1. Habilitar PowerShell Scripts
Write-Host "`n[1/5] Habilitando scripts PowerShell..." -ForegroundColor Yellow
Set-ExecutionPolicy Bypass -Scope CurrentUser -Force

# 2. Instalar UltraVNC
Write-Host "`n[2/5] Instalando UltraVNC..." -ForegroundColor Yellow

# Checar se já existe
if (Test-Path "C:\Program Files\UltraVNC") {
    Write-Host "UltraVNC já instalado. Pulando..." -ForegroundColor Green
} else {
    $uvncUrl = "https://github.com/ultravnc/UltraVNC/releases/download/1.4.3.0/UltraVNC_1430_X64_Setup.exe"
    $installer = "$env:TEMP\UltraVNC_Setup.exe"
    
    try {
        Invoke-WebRequest -Uri $uvncUrl -OutFile $installer
        Start-Process -FilePath $installer -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /MERGETASKS=installservice" -Wait
        Remove-Item $installer -Force
        Write-Host "UltraVNC instalado com sucesso!" -ForegroundColor Green
    } catch {
        Write-Host "Erro ao baixar/instalar: $_" -ForegroundColor Red
    }
}

# 3. Configurar Firewall
Write-Host "`n[3/5] Configurando firewall..." -ForegroundColor Yellow
netsh advfirewall firewall add rule name="UltraVNC Server" dir=in action=allow protocol=TCP localport=$VNCPort 2>$null
netsh advfirewall firewall add rule name="CaraProjetada Client" dir=in action=allow protocol=TCP localport=8000 2>$null

# 4. Configurar serviço UltraVNC
Write-Host "`n[4/5] Configurando serviço UltraVNC..." -ForegroundColor Yellow

# Senha padrão temporária
$DefaultPass = "123456"
$vncIni = "C:\Program Files\UltraVNC\ultravnc.ini"

if (Test-Path $vncIni) {
    # Usar o utilitário winvnc para gerar senha criptografada
    & "C:\Program Files\UltraVNC\winvnc.exe" -storepassword $DefaultPass 2>$null
}

# Iniciar serviço
Restart-Service -Name "UltraVNC Server" -Force -ErrorAction SilentlyContinue

# 5. Instalar cliente Python (opcional)
Write-Host "`n[5/5] Instalando cliente..." -ForegroundColor Yellow

# Criar diretório
$installDir = "C:\Program Files\CaraProjetada"
New-Item -ItemType Directory -Path $installDir -Force | Out-Null

# Nota: O cliente Python faria download aqui
# Por enquanto, apenas placeholder
Write-Host "Cliente Python pode ser instalado manualmente em $installDir" -ForegroundColor Yellow

# Finalizar
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Setup concluído!" -ForegroundColor Green
Write-Host "VNC Port: $VNCPort" -ForegroundColor Cyan
Write-Host "Password: $DefaultPass" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Green