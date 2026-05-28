# Configuração UltraVNC no Windows 11 - Guia Rápido

## Opção 1: Configuração Manual (Recomendado)

### Passo 1: Conectar na VM
```bash
# No terminal Arch Linux:
remote-viewer vnc://localhost:5900
```

### Passo 2: Dentro do Windows 11

1. **Pressione Windows + R** → digite `cmd`
2. **Execute como Administrador**:
   ```powershell
   # Habilitar scripts PowerShell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   ```

3. **Instalar UltraVNC**:
   - Baixar: https://www.uvnc.com/
   - Ou executar:
   ```powershell
   # Download automático
   Invoke-WebRequest -Uri "https://github.com/ultravnc/UltraVNC/releases/download/1.4.3.0/UltraVNC_1430_X64_Setup.exe" -OutFile "$env:TEMP\uvnc.exe"
   
   # Instalar silencioso (como serviço)
   Start-Process -FilePath "$env:TEMP\uvnc.exe" -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /MERGETASKS=installservice"
   ```

4. **Configurar senha VNC**:
   ```powershell
   # Senha padrão para teste (será substituída pela API)
   "123456" | "C:\Program Files\UltraVNC\winvnc.exe" -storepassword
   ```

5. **Configurar Firewall**:
   ```powershell
   netsh advfirewall firewall add rule name="UltraVNC Server" dir=in action=allow protocol=TCP localport=5900
   ```

6. **Iniciar serviço**:
   ```powershell
   # Reiniciar serviço
   Restart-Service -Name "UltraVNC Server" -Force
   
   # Verificar status
   Get-Service -Name "UltraVNC*"
   ```

## Opção 2: Script Automático

Execute dentro do Windows (PowerShell como Admin):
```powershell
# Copiar script abaixo e executar:
# C:\temp\caraprojetada_setup.ps1
```

## Verificação

### No Windows:
```powershell
# Verificar porta
netstat -an | findstr 5900
```

### No Linux (Projetor):
```bash
# Testar conexão VNC
xtightvncviewer <IP_WINDOWS>:5900 -autopass

# Ou via remmina
remmina vnc://<IP_WINDOWS>:5900
```

## Script de Setup Único

Criar arquivo `C:\temp\setup.ps1`:
```powershell
$ErrorActionPreference = "Stop"

Write-Host "CaraProjetada Setup..." -ForegroundColor Green

# Download UltraVNC
$uvncUrl = "https://github.com/ultravnc/UltraVNC/releases/download/1.4.3.0/UltraVNC_1430_X64_Setup.exe"
$installer = "$env:TEMP\uvnc.exe"
Invoke-WebRequest -Uri $uvncUrl -OutFile $installer

# Instalar
Start-Process -FilePath $installer -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /MERGETASKS=installservice" -Wait

# Senha
"123456" | "C:\Program Files\UltraVNC\winvnc.exe" -storepassword

# Firewall
netsh advfirewall firewall add rule name="UltraVNC Server" dir=in action=allow protocol=TCP localport=5900

# Serviço
Restart-Service -Name "UltraVNC Server" -Force

Write-Host "Setup concluído!" -ForegroundColor Green
```

---

## 🔧 Teste de Conectividade

Após instalar, verifique:
```bash
# Do projetor (RK3229) ou do host:
timeout 5 vinagre vnc://172.17.x.x:5900

# Ou via nc:
nc -zv 172.17.x.x 5900
```

Substitua `172.17.x.x` pelo IP do Windows 11 na rede.