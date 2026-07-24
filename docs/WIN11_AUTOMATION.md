# Automação do Windows 11 - Estratégias

## Método 1: Conexão VNC Direta (Recomendado)

```bash
# Conectar via VNC
remote-viewer vnc://localhost:5900
```

Dentro do Windows:
1. Pressione `Windows + R` → digite `powershell`
2. Execute como Administrador
3. Execute o script:

```powershell
# Script inline - copie e cole no PowerShell:
$ErrorActionPreference = "Stop"

Write-Host "[CaraProjetada] Setup iniciado..." -ForegroundColor Cyan

# 1. Habilitar scripts
Set-ExecutionPolicy Bypass -Scope CurrentUser -Force

# 2. Download UltraVNC (64-bit latest)
$Url = "https://github.com/ultravnc/UltraVNC/releases/download/1.4.3.0/UltraVNC_1430_X64_Setup.exe"
$Out = "$env:TEMP\uvnc.exe"
Write-Host "[DOWNLOAD] Baixando UltraVNC..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $Url -OutFile $Out

# 3. Instalar silencioso
Write-Host "[INSTALL] Instalando..." -ForegroundColor Yellow
Start-Process -FilePath $Out -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /MERGETASKS=installservice" -Wait

# 4. Configurar senha VNC
Write-Host "[CONFIG] Configurando senha..." -ForegroundColor Yellow
& "C:\Program Files\UltraVNC\winvnc.exe" -storepassword "123456" 2>$null

# 5. Firewall
netsh advfirewall firewall add rule name="UltraVNC Server" dir=in action=allow protocol=TCP localport=5900 2>$null

# 6. Iniciar serviço
Restart-Service -Name "UltraVNC Server" -Force

Write-Host "[OK] Setup concluído!" -ForegroundColor Green
```

## Método 2: SPICE + Clipboard

Se a VM tiver Spice configurado:
```bash
# Usando spice-client
spicy --uri qemu:///system --uuid 05767510-3845-48bd-a262-ea3d1752cdd7
```

## Método 3: ISO de Provisionamento

```bash
# ISO já criado em /tmp/caraprojetada-setup.iso
# Precisa reiniciar VM com ISO conectado no boot
```

## Método 4: QEMU Guest Agent (Futuro)

Instalar o `qemu-ga-x86_64.msi` na VM permite:
- Executar comandos via `virsh qemu-agent-command`
- Acesso a filesystem via `guest-file-open`
- Sincronização de hora via `guest-set-time`

## Verificação Pós-Instalação

No Windows (cmd):
```cmd
netstat -an | findstr 5900
Get-Service -Name "UltraVNC*"
```

No Linux (do projetor):
```bash
# Testar conexão VNC
nc -zv 172.17.28.xxx 5900
xtightvncviewer 172.17.28.xxx:5900 -autopass
```

Onde `172.17.28.xxx` é o IP atribuído pelo DHCP ao Windows 11.