# CaraProjetada - Configuração UltraVNC 1.8.22 (winget)
# Executar como Administrador no Windows 11

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CaraProjetada - UltraVNC 1.8.22 Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    # Verificar se UltraVNC está instalado via winget
    $vncInstalled = Get-Package -Name "*VNC*" -ErrorAction SilentlyContinue
    if (-not $vncInstalled) {
        Write-Host "[INSTALL] Instalando UltraVNC via winget..." -ForegroundColor Yellow
        winget install -e --id UltraVNC.UltraVNC --accept-package-agreements --accept-source-agreements
        Start-Sleep -Seconds 10
    } else {
        Write-Host "[OK] UltraVNC já instalado: $($vncInstalled.Version)" -ForegroundColor Green
    }

    # Localizar instalação (winget instala em %ProgramFiles%\UltraVNC)
    $vncPath = "${env:ProgramFiles}\UltraVNC"
    if (-not (Test-Path $vncPath)) {
        $vncPath = "${env:ProgramFiles(x86)}\UltraVNC"
    }

    Write-Host "[PATH] UltraVNC em: $vncPath" -ForegroundColor Yellow

    # Configurar senha VNC (método 1.8.22)
    Write-Host "[CONFIG] Configurando senha..." -ForegroundColor Yellow
    $vncExe = Join-Path $vncPath "winvnc.exe"
    
    if (Test-Path $vncExe) {
        # UltraVNC 1.8.22 aceita -storepassword ou via INI
        & $vncExe -storepassword "123456" 2>$null
        Write-Host "[OK] Senha configurada" -ForegroundColor Green
    }

    # Abrir firewall para porta 5900
    Write-Host "[FIREWALL] Configurando regra..." -ForegroundColor Yellow
    netsh advfirewall firewall add rule name="UltraVNC Server" dir=in action=allow protocol=TCP localport=5900 2>$null

    # Iniciar/Verificar serviço
    Write-Host "[SERVICE] Iniciando UltraVNC..." -ForegroundColor Yellow
    $service = Get-Service -Name "*VNC*" | Where-Object {$_.Status -eq "Running" -or $_.Name -like "*Ultra*"}
    
    if ($service) {
        Write-Host "[OK] Serviço VNC: $($service.Name) - $($service.Status)" -ForegroundColor Green
    } else {
        # Tentar iniciar serviço UltraVNC
        try {
            Start-Service -Name "UltraVNC Server" -ErrorAction Stop
            Write-Host "[OK] Serviço iniciado" -ForegroundColor Green
        } catch {
            Write-Host "[WARN] Serviço pode não existir, iniciar manualmente" -ForegroundColor Yellow
            & "$vncPath\winvnc.exe" -service 2>$null
        }
    }

    # Verificar porta escutando
    Write-Host "[CHECK] Verificando porta 5900..." -ForegroundColor Yellow
    $listening = Get-NetTCPConnection -LocalPort 5900 -ErrorAction SilentlyContinue
    if ($listening) {
        Write-Host "[OK] Porta 5900 escutando" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Porta 5900 não detectada - pode precisar reiniciar serviço" -ForegroundColor Yellow
    }

} catch {
    Write-Host "[ERROR] $_" -ForegroundColor Red
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "Setup concluído. Teste: nc -zv IP_WINDOWS 5900" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green