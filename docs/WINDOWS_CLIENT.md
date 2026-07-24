# Cliente Windows - CaraProjetada PC Agent

## Visão Geral

Cliente desktop para Windows 11 que:
1. **Instala e configura automaticamente o UltraVNC Server**
2. **Registra o PC na rede como disponível para projeção**
3. **Fornece senha dinâmica por sessão de usuário**
4. **Gerencia firewall e inicialização automática**

## Arquitetura do Cliente

```
caraprojetada-client/
├── main.py                  # Entry point (Python/PySide6)
├── vnc_manager.py           # Gerenciamento do UltraVNC
├── api_client.py            # Comunicação com projetor
├── config_manager.py        # Configurações e registry
├── service_wrapper.py       # Instalação como serviço Windows
├── ui/
│   ├── main_window.py       # Janela principal
│   ├── tray_icon.py         # Ícone na bandeja
│   └── settings_dialog.py   # Diálogo de configurações
├── assets/
│   ├── icon.ico
│   └── logo.png
├── ultravnc/
│   ├── UltraVNC_Server.msi  # Embedded installer
│   └── ultravnc.ini         # Config template
└── build/
    └── caraprojetada-client.exe
```

## Fluxo de Configuração VNC

### 1. Instalação Automática do UltraVNC

```powershell
# Silent install via MSI
msiexec /i UltraVNC_Server.msi /quiet /norestart ADDLOCAL="Server,Viewer"

# Configurações pós-instalação
- Porta: 5900 (padrão)
- Senha: dinâmica (via API)
- MSLogon: habilitado para autenticação AD
- LoopbackOnly: desativado (aceita conexões externas)
```

### 2. Configuração do Firewall

```powershell
netsh advfirewall firewall add rule name="UltraVNC Server" dir=in action=allow protocol=TCP localport=5900
```

### 3. Registro de Serviços

O cliente registra periodicamente no projetor:
- Hostname do PC
- IP atual
- Status online/offline
- Abas disponíveis (via WebSocket)

## API de Integração

### Registro do Cliente

```http
POST http://projetores.intranet.ufrb.edu.br/api/v1/register
Content-Type: application/json
Authorization: Bearer <token>

{
  "hostname": "DEIVI-NOTE",
  "ip": "172.17.28.100",
  "mac": "00:1A:2B:3C:4D:5E",
  "os": "Windows 11 25H2",
  "available": true,
  "capabilities": ["vnc", "audio", "multi-tab"]
}
```

### Heartbeat (a cada 30s)

```http
POST http://projetores.intranet.ufrb.edu.br/api/v1/heartbeat
{
  "hostname": "DEIVI-NOTE",
  "timestamp": "2026-05-28T12:00:00Z",
  "vnc_port": 5900,
  "vnc_password": "generated-session-password"
}
```

### Receber Senha VNC

```http
GET http://projetores.intranet.ufrb.edu.br/api/v1/vnc/password?session_id=abc123
Response: 
{
  "password": "temp-pass-123456",
  "expires_in": 3600,
  "session_user": "deivison.santana"
}
```

## Senha VNC Dinâmica

### Estratégia

1. **Geração de senha única por sessão AD**
   - Flask gera senha aleatória (8 chars)
   - Armazena em memória (Redis ou dict simples)
   - Cliente Windows atualiza senha via `ultravnc.exe /kill && ultravnc.exe /register`

2. **Arquivo de configuração UltraVNC**
   ```ini
   [ultravnc]
   passwd=DECODED-PASSWORD-HERE
   passwd23=
   loopbackOnly=0
   AcceptSocketConn=1
   ```

## Service Worker

### Instalação como Serviço Windows

```python
# Via NSSM (Non-Sucking Service Manager)
nssm install CaraProjetadaClient "C:\Program Files\CaraProjetada\caraprojetada-client.exe"
nssm set CaraProjetadaClient Start SERVICE_AUTO_START
```

### Startup no Login do Usuário

```yaml
Registry:
  HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run
  "CaraProjetada Client" = "C:\Program Files\CaraProjetada\caraprojetada-client.exe" --minimized
```

## Comunicação WebSocket

### Eventos em Tempo Real

```javascript
// Cliente Windows conecta via WebSocket
ws://projetores.intranet.ufrb.edu.br/ws

// Mensagens recebidas
{
  "event": "connect_request",
  "user": "deivison.santana",
  "projector_id": "sala-a",
  "session_id": "abc123"
}

// Mensagens enviadas
{
  "event": "vnc_ready",
  "hostname": "DEIVI-NOTE", 
  "port": 5900,
  "password": "xyz789"
}
```

## Estrutura de Dados (Session)

```python
class VNCSession:
    session_id: str        # UUID único
    user: str              # Usuário AD
    pc_hostname: str       # DEIVI-NOTE
    pc_ip: str             # 172.17.28.100
    vnc_password: str      # Senha temporária
    created_at: datetime   # Quando criada
    expires_at: datetime   # TTL (1h padrão)
    active_tab: str        # URL da aba selecionada
    status: str          # pending/connecting/connected/disconnected
```

## Build e Distribuição

### PyInstaller Build

```bash
pyinstaller --onefile --windowed \
  --icon=assets/icon.ico \
  --add-data "ultravnc;ultravnc" \
  --hidden-import "websockets" \
  main.py
```

### Instalação Silenciosa

```powershell
# Install script
Start-Process -FilePath "caraprojetada-client-setup.exe" -ArgumentList "/S" -Wait
```

## Testes de Integração

### QA Checklist

- [ ] UltraVNC Server instala corretamente (Win11)
- [ ] Senha VNC é atualizada dinamicamente
- [ ] Firewall libera porta 5900
- [ ] Heartbeat chega ao projetor a cada 30s
- [ ] WebSocket conecta e mantém conexão
- [ ] Extensão consegue detectar abas
- [ ] Seleção de aba abre no projetor
- [ ] Logout limpa senha VNC