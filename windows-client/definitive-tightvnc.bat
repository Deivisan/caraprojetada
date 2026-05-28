@echo off
setlocal enabledelayedexpansion
title TightVNC Server - Instalador
cd /d "%~dp0"

:: Verificar se eh Admin
>nul 2>&1 net session
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  ===============================================
    echo   [!] Este script precisa ser ADMINISTRADOR
    echo   Reiniciando com privilegios elevados...
    echo  ===============================================
    echo.
    powershell start cmd -Verb RunAs -Args '/c "%~f0"'
    exit /b
)

:: Extrair o script PowerShell embutido e executar
echo.
echo  ===============================================
echo    TightVNC Server - Instalando...
echo  ===============================================
echo.

findstr /b "::PS:" "%~f0" > "%TEMP%\tvinstall_raw.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo [FALHA] Erro ao extrair script interno.
    pause
    exit /b 1
)
powershell -NoProfile -Command "(Get-Content '%TEMP%\tvinstall_raw.ps1') -replace '^::PS:', '' | Set-Content '%TEMP%\tvinstall.ps1'"
del "%TEMP%\tvinstall_raw.ps1" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\tvinstall.ps1"
set EXIT_CODE=%ERRORLEVEL%
echo.
echo ===============================================
if %EXIT_CODE% EQU 0 (
    echo   INSTALACAO CONCLUIDA - TightVNC pronto!
) else (
    echo   FALHA - Codigo: %EXIT_CODE%
)
echo ===============================================
del "%TEMP%\tvinstall.ps1" >nul 2>&1
echo.
pause
goto :eof

:: ============================================================
::  POWERSHELL SCRIPT EMBUTIDO
::  (linhas comecando com ::PS: serao extraidas e executadas)
:: ============================================================
::PS: param([string]$Senha = "123456")
::PS: 
::PS: $ErrorActionPreference = "Stop"
::PS: 
::PS: # Cores
::PS: function Write-Title($t) { Write-Host "`n[$t]`n" -ForegroundColor Yellow }
::PS: function Write-OK($t)    { Write-Host "  [OK] $t" -ForegroundColor Green }
::PS: function Write-Warn($t)  { Write-Host "  [!] $t" -ForegroundColor Yellow }
::PS: function Write-Fail($t)  { Write-Host "  [X] $t" -ForegroundColor Red }
::PS: function Write-Info($t)  { Write-Host "  -> $t" -ForegroundColor DarkGray }
::PS: 
::PS: $arch = if ([Environment]::Is64BitOperatingSystem) { "64bit" } else { "32bit" }
::PS: $ver = "2.8.87"
::PS: $tempDir = "$env:TEMP\tvinstall"
::PS: $msiFile = "$tempDir\tightvnc.msi"
::PS: $logFile = "$tempDir\install.log"
::PS: 
::PS: if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }
::PS: 
::PS: # ============================================================
::PS: # PASSO 1 - Limpeza profunda
::PS: # ============================================================
::PS: Write-Title "PASSO 1/6 - Limpando instalacao anterior"
::PS: 
::PS: # Matar processos primeiro (antes de mexer no servico)
::PS: foreach ($proc in @("tvnserver", "tvnservice", "tvnserver-control")) {
::PS:     Get-Process $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
::PS: }
::PS: Start-Sleep 1
::PS: 
::PS: # Parar e remover servico
::PS: $svc = Get-Service tvnserver -ErrorAction SilentlyContinue
::PS: if ($svc) {
::PS:     Write-Info "Parando e removendo servico existente..."
::PS:     Stop-Service tvnserver -Force -ErrorAction SilentlyContinue | Out-Null
::PS:     Start-Sleep 2
::PS:     sc.exe delete tvnserver *>$null
::PS:     Start-Sleep 2
::PS:     Write-OK "Servico removido"
::PS: }
::PS: 
::PS: # Limpar registros
::PS: $regPaths = @(
::PS:     "HKCU:\Software\TightVNC",
::PS:     "HKLM:\SOFTWARE\TightVNC",
::PS:     "HKLM:\SYSTEM\CurrentControlSet\Services\tvnserver"
::PS: )
::PS: foreach ($r in $regPaths) {
::PS:     if (Test-Path $r) { Remove-Item $r -Recurse -Force -ErrorAction SilentlyContinue }
::PS: }
::PS: Write-OK "Registros limpos"
::PS: 
::PS: # Limpar firewall
::PS: netsh advfirewall firewall delete rule name="TightVNC Server" *>$null
::PS: Write-OK "Firewall limpo"
::PS: 
::PS: # ============================================================
::PS: # PASSO 2 - Download
::PS: # ============================================================
::PS: Write-Title "PASSO 2/6 - Baixando TightVNC Server $ver"
::PS: 
::PS: [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
::PS: $downloaded = $false
::PS: 
::PS: # Lista de URLs para tentar
::PS: $urls = @(
::PS:     "https://www.tightvnc.com/download/$ver/tightvnc-$ver-gpl-setup-$arch.msi",
::PS:     "https://github.com/chenall/tightvnc/releases/download/v$ver/tightvnc-$ver-gpl-setup-$arch.msi",
::PS:     "https://sourceforge.net/projects/vnc-tight/files/$ver/tightvnc-$ver-gpl-setup-$arch.msi/download"
::PS: )
::PS: 
::PS: foreach ($url in $urls) {
::PS:     Write-Info "Tentando: $url"
::PS:     try {
::PS:         $wc = New-Object System.Net.WebClient
::PS:         $wc.DownloadFile($url, $msiFile)
::PS:         $wc.Dispose()
::PS:         if ((Test-Path $msiFile) -and ((Get-Item $msiFile).Length -gt 1MB)) {
::PS:             $downloaded = $true
::PS:             Write-OK "Download concluido ($((Get-Item $msiFile).Length/1KB -as [int]) KB)"
::PS:             break
::PS:         }
::PS:     } catch {
::PS:         Write-Info "Falhou: $($_.Exception.Message)"
::PS:     }
::PS: }
::PS: 
::PS: if (-not $downloaded) {
::PS:     Write-Fail "Download falhou apos todas as tentativas."
::PS:     Write-Fail "Verifique sua conexao com a internet."
::PS:     exit 2
::PS: }
::PS: 
::PS: # ============================================================
::PS: # PASSO 3 - Instalacao
::PS: # ============================================================
::PS: Write-Title "PASSO 3/6 - Instalando TightVNC Server"
::PS: 
::PS: # Montar argumentos do MSI
::PS: $msiArgs = "/i `"$msiFile`" /quiet /norestart /log `"$logFile`""
::PS: $msiArgs += " ADDLOCAL=Server"
::PS: $msiArgs += " SERVER_REGISTER_AS_SERVICE=1"
::PS: $msiArgs += " SERVER_ADD_FIREWALL_EXCEPTION=1"
::PS: $msiArgs += " SERVER_ALLOW_SAS=1"
::PS: $msiArgs += " SET_USEVNCAUTHENTICATION=1"
::PS: $msiArgs += " VALUE_OF_USEVNCAUTHENTICATION=1"
::PS: $msiArgs += " SET_PASSWORD=1"
::PS: $msiArgs += " VALUE_OF_PASSWORD=$Senha"
::PS: $msiArgs += " SET_USECONTROLAUTHENTICATION=1"
::PS: $msiArgs += " VALUE_OF_USECONTROLAUTHENTICATION=1"
::PS: $msiArgs += " SET_CONTROLPASSWORD=1"
::PS: $msiArgs += " VALUE_OF_CONTROLPASSWORD=$Senha"
::PS: 
::PS: Write-Info "Executando: msiexec $msiArgs"
::PS: $proc = Start-Process msiexec.exe -Wait -PassThru -ArgumentList $msiArgs
::PS: 
::PS: if ($proc.ExitCode -eq 0) {
::PS:     Write-OK "Instalacao concluida (codigo $($proc.ExitCode))"
::PS: } else {
::PS:     Write-Warn "MSI retornou codigo $($proc.ExitCode), continuando..."
::PS: }
::PS: Start-Sleep 3
::PS: 
::PS: # ============================================================
::PS: # PASSO 4 - Forcar configuracao
::PS: # ============================================================
::PS: Write-Title "PASSO 4/6 - Aplicando configuracao"
::PS: 
::PS: # Localizar executavel
::PS: $tvnPaths = @(
::PS:     "$env:ProgramFiles\TightVNC\tvnserver.exe",
::PS:     "${env:ProgramFiles(x86)}\TightVNC\tvnserver.exe"
::PS: )
::PS: $tvnExe = $tvnPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
::PS: 
::PS: if (-not $tvnExe) {
::PS:     Write-Fail "tvnserver.exe NAO ENCONTRADO!"
::PS:     Write-Info "Procurando em todo o sistema..."
::PS:     $tvnExe = Get-ChildItem -Path "$env:SystemDrive\" -Filter "tvnserver.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
::PS: }
::PS: 
::PS: if (-not $tvnExe) {
::PS:     Write-Fail "TightVNC nao foi instalado corretamente."
::PS:     exit 3
::PS: }
::PS: Write-Info "Executavel: $tvnExe"
::PS: 
::PS: # Verificar se o servico foi criado pelo MSI
::PS: $svc = Get-Service tvnserver -ErrorAction SilentlyContinue
::PS: if (-not $svc) {
::PS:     Write-Info "Servico nao encontrado. Registrando manualmente..."
::PS:     $regSvc = Start-Process -FilePath $tvnExe -ArgumentList "-install" -Wait -PassThru -NoNewWindow
::PS:     Start-Sleep 2
::PS:     $svc = Get-Service tvnserver -ErrorAction SilentlyContinue
::PS:     if ($svc) { Write-OK "Servico registrado manualmente" }
::PS:     else { Write-Warn "Falha ao registrar servico manualmente" }
::PS: } else {
::PS:     Write-OK "Servico ja foi registrado pelo MSI"
::PS: }
::PS: 
::PS: # Garantir start=auto
::PS: if ($svc) {
::PS:     Write-Info "Configurando inicializacao automatica..."
::PS:     sc.exe config tvnserver start=auto *>$null
::PS:     if ($?) { Write-OK "Start type: Automatic" }
::PS:     else { Write-Warn "Falha ao configurar start=auto" }
::PS: }
::PS: 
::PS: # Escrever senha no registro
::PS: Write-Info "Gravando senha no registro..."
::PS: $passwordBytes = @(0x49,0x40,0x15,0xf9,0xa3,0x5e,0x8b,0x22)
::PS: 
::PS: $regPaths = @{
::PS:     "HKCU:\Software\TightVNC\Server" = $true
::PS:     "HKLM:\SOFTWARE\TightVNC\Server" = $true
::PS: }
::PS: 
::PS: foreach ($regPath in $regPaths.Keys) {
::PS:     try {
::PS:         if (-not (Test-Path $regPath)) {
::PS:             New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null
::PS:         }
::PS:         Set-ItemProperty -Path $regPath -Name "Password" -Type Binary -Value $passwordBytes -ErrorAction Stop
::PS:     } catch {
::PS:         Write-Warn "Nao foi possivel escrever em $regPath"
::PS:     }
::PS: }
::PS: Write-OK "Senha configurada no registro"
::PS: 
::PS: # Firewall
::PS: Write-Info "Configurando Firewall..."
::PS: $fw = netsh advfirewall firewall delete rule name="TightVNC Server" *>$null
::PS: $fw = netsh advfirewall firewall add rule name="TightVNC Server" dir=in action=allow protocol=TCP localport=5900,5800 profile=any
::PS: if ($LASTEXITCODE -eq 0) { Write-OK "Firewall: portas 5900,5800 liberadas" }
::PS: else { Write-Warn "Falha ao configurar firewall" }
::PS: 
::PS: # ============================================================
::PS: # PASSO 5 - Iniciar servico
::PS: # ============================================================
::PS: Write-Title "PASSO 5/6 - Iniciando servico"
::PS: 
::PS: $svc = Get-Service tvnserver -ErrorAction SilentlyContinue
::PS: if ($svc) {
::PS:     Write-Info "Iniciando servico..."
::PS:     Start-Service tvnserver -ErrorAction SilentlyContinue
::PS:     Start-Sleep 3
::PS:     $svc.Refresh()
::PS:     if ($svc.Status -eq "Running") {
::PS:         Write-OK "Servico rodando!"
::PS:     } else {
::PS:         Write-Warn "Servico nao iniciou automaticamente. Status: $($svc.Status)"
::PS:         Write-Info "Tentando sc start..."
::PS:         sc.exe start tvnserver *>$null
::PS:         Start-Sleep 3
::PS:         $svc.Refresh()
::PS:         if ($svc.Status -eq "Running") {
::PS:             Write-OK "Servico iniciado via sc.exe"
::PS:         } else {
::PS:             Write-Warn "Servico ainda parado. Tentando modo aplicacao..."
::PS:             Start-Process -FilePath $tvnExe -ArgumentList "-service" -WindowStyle Hidden
::PS:             Start-Sleep 3
::PS:         }
::PS:     }
::PS: } else {
::PS:     Write-Warn "Servico nao existe. Iniciando em modo aplicacao..."
::PS:     Start-Process -FilePath $tvnExe -ArgumentList "-service" -WindowStyle Hidden
::PS:     Start-Sleep 3
::PS: }
::PS: 
::PS: # ============================================================
::PS: # PASSO 6 - Verificacao final
::PS: # ============================================================
::PS: Write-Title "PASSO 6/6 - Verificacao final"
::PS: 
::PS: $allOk = $true
::PS: 
::PS: # 6.1 - Servico
::PS: $svc = Get-Service tvnserver -ErrorAction SilentlyContinue
::PS: if ($svc) {
::PS:     Write-OK "Servico: $($svc.Status) | Inicializacao: $($svc.StartType)"
::PS:     if ($svc.Status -ne "Running") { $allOk = $false }
::PS: } else {
::PS:     Write-Warn "Servico: NAO INSTALADO (modo aplicacao pode estar rodando)"
::PS:     # Verificar se o processo tvnserver esta rodando
::PS:     $proc = Get-Process tvnserver -ErrorAction SilentlyContinue
::PS:     if ($proc) { Write-OK "Processo tvnserver.exe rodando (PID: $($proc.Id))" }
::PS:     else { Write-Warn "Nenhum processo tvnserver encontrado" }
::PS: }
::PS: 
::PS: # 6.2 - Porta
::PS: Start-Sleep 2
::PS: $port = netstat -ano | Select-String ":5900\s" | Select-String "LISTENING"
::PS: if ($port) {
::PS:     Write-OK "Porta 5900: ABERTA e ouvindo conexoes"
::PS: } else {
::PS:     Write-Warn "Porta 5900: FECHADA"
::PS:     $allOk = $false
::PS: }
::PS: 
::PS: # 6.3 - Senha
::PS: $regPass = Get-ItemProperty "HKLM:\SOFTWARE\TightVNC\Server" -Name Password -ErrorAction SilentlyContinue
::PS: if ($regPass) {
::PS:     Write-OK "Senha: OK (HKLM)"
::PS: } else {
::PS:     $regPass2 = Get-ItemProperty "HKCU:\Software\TightVNC\Server" -Name Password -ErrorAction SilentlyContinue
::PS:     if ($regPass2) { Write-OK "Senha: OK (HKCU)" }
::PS:     else { Write-Warn "Senha: NAO ENCONTRADA NO REGISTRO"; $allOk = $false }
::PS: }
::PS: 
::PS: # 6.4 - Firewall
::PS: $fwRule = netsh advfirewall firewall show rule name="TightVNC Server" 2>$null
::PS: if ($fwRule -match "TightVNC Server") {
::PS:     Write-OK "Firewall: regra ativa"
::PS: } else {
::PS:     Write-Warn "Firewall: sem regra especifica"
::PS: }
::PS: 
::PS: # 6.5 - Teste de conexao TCP (opcional)
::PS: try {
::PS:     $socket = New-Object System.Net.Sockets.TcpClient
::PS:     $conn = $socket.BeginConnect("127.0.0.1", 5900, $null, $null)
::PS:     $wait = $conn.AsyncWaitHandle.WaitOne(2000, $false)
::PS:     if ($wait -and $socket.Connected) {
::PS:         Write-OK "Teste TCP: conexao local na porta 5900 OK"
::PS:         $socket.Close()
::PS:     } else {
::PS:         Write-Warn "Teste TCP: sem resposta na porta 5900"
::PS:     }
::PS: } catch {
::PS:     Write-Warn "Teste TCP: erro ($($_.Exception.Message))"
::PS: }
::PS: 
::PS: # Limpeza
::PS: if (Test-Path $tempDir) {
::PS:     Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
::PS:     Write-Info "Temporarios removidos"
::PS: }
::PS: 
::PS: Write-Title "RESULTADO FINAL"
::PS: if ($allOk) {
::PS:     Write-OK "TightVNC Server instalado e rodando!"
::PS:     Write-OK "Porta 5900 aberta - aguardando conexoes VNC"
::PS:     exit 0
::PS: } else {
::PS:     Write-Warn "Instalacao concluida com alguns avisos."
::PS:     Write-Warn "Verifique as mensagens acima."
::PS:     exit 1
::PS: }
