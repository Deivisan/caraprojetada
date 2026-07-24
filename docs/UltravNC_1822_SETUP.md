# UltraVNC 1.8.22 - Setup no Windows 11 via QEMU

## Status Atual
- ✅ VM Windows 11 rodando
- ✅ QEMU VNC (console): `remote-viewer vnc://localhost:5900`
- ⏳ UltraVNC 1.8.22 instalado via winget (precisa configurar)

## Configuração UltraVNC 1.8.22

### 1. Conectar na VM (QEMU console)
```bash
remote-viewer vnc://localhost:5900 &
```

### 2. Dentro do Windows 11 - PowerShell como ADMIN

Execute cada comando:

```powershell
# Verificar instalação
Get-Package -Name "*VNC*"

# Localizar caminho de instalação
Get-Package -Name "*VNC*" | Select-Object -ExpandProperty Location
# Provavelmente: C:\Program Files\UltraVNC
```

### 3. Configurar Serviço VNC

```powershell
# Navegar para pasta do UltraVNC
cd "C:\Program Files\UltraVNC"

# Configurar senha (arquivo .vnc cadastrado)
.\winvnc.exe -storepassword "123456"

# Registrar como serviço
.\winvnc.exe -install

# Ou se já tiver serviço, reiniciar
Restart-Service -Name "UltraVNC*" -Force

# Verificar status
Get-Service -Name "*VNC*" | Select-Object Name, Status
```

### 4. Abrir Firewall

```powershell
# Abrir porta 5900
netsh advfirewall firewall add rule name="UltraVNC" dir=in action=allow protocol=TCP localport=5900

# Verificar regra
netsh advfirewall firewall show rule name="UltraVNC"
```

### 5. Configurar para aceitar conexões externas

Editar `ultravnc.ini`:
```ini
[ultravnc]
AcceptSocketConn=1
LoopbackOnly=0
PortNumber=5900
```

### 6. Verificar IP do Windows

```powershell
# Executar:
ipconfig
# Procure IPv4 no adaptador Ethernet (provavelmente 10.0.2.x)
```

### 7. Redirecionar porta VNC (se rede é NAT)

Como a VM usa rede `user` (NAT), vamos usar redirecionamento:

```bash
# No Arch Linux, redirecionar porta:
sudo virsh qemu-monitor-command win11-ufrb --hmp --cmd "hostfwd_add tcp:0.0.0.0:5901-:5900"
```

Ou mudar para bridge:
```bash
# Parar VM
sudo virsh destroy win11-ufrb

# Editar XML
sudo virsh edit win11-ufrb

# Mudar <interface type='user'> para <interface type='bridge'>
# fonte: <source bridge='virbr0'/> ou 'bridge0'
```

## Teste

### No Windows:
```powershell
netstat -an | findstr 5900
```

### No Arch Linux (depois do redirecionamento):
```bash
# Se redirecionou para 5901:
python3 -c "
import socket
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.settimeout(2)
result = sock.connect_ex(('localhost', 5901))
sock.close()
print('VNC OK' if result == 0 else 'VNC FAIL')
"

# Ou usar xtightvncviewer:
xtightvncviewer localhost:5901 -autopass
```

## Configuração Automática via Script

Criar `C:\temp\setup_uvnc.ps1`:

```powershell
# Executar como Administrador
$ErrorActionPreference = "Stop"

Write-Host "[UVNC] Configurando..." -ForegroundColor Cyan

# Caminho padrão
$path = "C:\Program Files\UltraVNC"
cd $path

# Senha
.\winvnc.exe -storepassword "123456"

# Serviço
.\winvnc.exe -install
Restart-Service -Name "UltraVNC*" -Force

# Firewall
netsh advfirewall firewall add rule name="UltraVNC" dir=in action=allow protocol=TCP localport=5900

# Config INI (aceitar conexões)
(Get-Content ultravnc.ini) -replace 'AcceptSocketConn=0', 'AcceptSocketConn=1' | Set-Content ultravnc.ini

Write-Host "[OK] Pronto!" -ForegroundColor Green
```