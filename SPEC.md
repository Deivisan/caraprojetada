# CaraProjetada — Especificação Técnica

## 1. Dispositivo Alvo

| Item | Valor |
|------|-------|
| **SoC** | Rockchip RK3229 (RK3228 compatível) |
| **CPU** | 4× ARM Cortex-A7 @ 1.5 GHz, 28nm |
| **ISA** | ARMv7 32-bit (armhf) com NEON/VFPv4 |
| **GPU** | Mali-400 MP2 |
| **RAM** | 1 GB DDR3 (2 GB em alguns modelos) |
| **eMMC** | 8 GB (7.3 GB utilizáveis) |
| **Rede** | 10/100 Ethernet + Wi-Fi 802.11 b/g/n (Espressif ESP8089) |
| **USB** | 3× USB 2.0 + 1× USB OTG |
| **Vídeo** | HDMI 2.0 até 4K@60fps, CVBS |
| **Áudio** | DAC integrado, SPDIF, AV composto |
| **Armazenamento externo** | Micro SD até 128 GB |

## 2. Stack de Software

### Sistema Operacional
- **OS**: Armbian 21.08.8 (Debian Bullseye)
- **Kernel**: 4.4.194-rk322x (legacy branch)
- **Init**: systemd
- **Display**: Xorg + LightDM + openbox
- **Shell**: bash 5.x

### Dependências Core
```bash
# Web server + auth
python3 python3-flask python3-flask-socketio python3-ldap3

# Display
xserver-xorg-core openbox lightdm x11-utils

# Kiosk
chromium

# Streaming (opcional)
vlc vlc-bin

# Manutenção
x11-xserver-utils
```

### Serviços Ativos
| Serviço | Porta | Status | Descrição |
|---------|-------|--------|-----------|
| `projetor` | 80 | ✅ Ativo | Flask: WebRTC + AD auth + Socket.IO |
| `sshd` | 22 | ✅ Ativo | Acesso remoto |
| `lightdm` | — | ✅ Ativo | Gerenciador de display |
| `stream-cam` | 8554 | ✅ Ativo | Streaming RTSP (câmera) |
| `NetworkManager` | — | ✅ Ativo | Gerenciamento de rede |

## 3. API REST

### `GET /`
- **Descrição**: Página inicial
- **Resposta**: Redirect para `/login` ou `/dashboard`

### `GET /login`
- **Descrição**: Tela de login institucional
- **Resposta**: HTML com formulário de login

### `POST /login`
- **Parâmetros**: `username` (string), `password` (string)
- **Autenticação**: LDAP bind contra Active Directory (mock em dev)
- **Resposta sucesso**: Redirect para `/dashboard`
- **Resposta erro**: HTML com mensagem de erro

### `GET /dashboard`
- **Descrição**: Painel do professor com salas disponíveis
- **Resposta**: HTML com grid de salas e interface WebRTC (getDisplayMedia)

### `GET /display`
- **Descrição**: Tela do projetor (chromium kiosk no HDMI)
- **Resposta**: HTML com player WebRTC e status do projetor
- **Conteúdo**: Identidade UFRB, relógio, status livre/ocupado, vídeo remoto via WebRTC
- **Atualização**: Eventos socket.io em tempo real

### `GET /api/v1/status`
- **Descrição**: Retorna status JSON do projetor
- **Resposta**: JSON com modo, sessão ativa, sala

## 4. LDAP / Active Directory

### Configuração
| Parâmetro | Valor |
|-----------|-------|
| Server | `ldap://10.198.1.2` |
| Domain | `intranet.ufrb.edu.br` |
| Porta | 389 (LDAP padrão) |
| User Principal | `username@intranet.ufrb.edu.br` |
| Autenticação | SIMPLE bind |

### Fluxo
```python
user_principal = f"{username}@{AD_DOMAIN}"
server = Server(AD_SERVER, get_info=ALL)
conn = Connection(server, user=user_principal,
                  password=password, authentication='SIMPLE')
return conn.bind()
```

## 5. WebRTC (Screen Capture via Navegador)

### Modelo: Transmissão via Navegador
- O professor acessa o dashboard pelo navegador
- O navegador captura a tela via `getDisplayMedia()` (Screen Capture API)
- A sinalização WebRTC é feita via Socket.IO
- O projetor (chromium kiosk em `/display`) recebe e exibe o vídeo

### Fluxo de Sinalização
```text
Dashboard (Presenter)              Display (Projetor)
       │                                │
       │──── socket.io: join(sala) ────→│
       │←── socket.io: join(tvbox) ────│
       │←────── offer (SDP) ───────────│
       │────── answer (SDP) ──────────→│
       │←── ice-candidate (candidates) →│
       │── ice-candidate (candidates) →│
       │                                │
       │    📡 mídia via RTCDataChannel │
       │         (peer-to-peer)         │
       │                                │
```

### Eventos Socket.IO
| Evento | Dados | Quem emite | Descrição |
|--------|-------|------------|-----------|
| `join` | `{sala, tipo}` | ambos | Entrar na sala de sinalização |
| `offer` | `{type, sdp, sala}` | Display | SDP offer do receptor |
| `answer` | `{type, sdp, sala}` | Dashboard | SDP answer do apresentador |
| `ice-candidate` | `{candidate, sala}` | ambos | ICE candidate para NAT traversal |
| `session-start` | `{sala, username, fullname}` | Dashboard | Marcar sala como ocupada |
| `session-end` | `{sala}` | Dashboard | Liberar sala |
| `session-active` | `{sala, user, since}` | Servidor | Notificar display que sessão iniciou |
| `session-ended` | `{sala}` | Servidor | Notificar display que sessão encerrou |
| `professor-desconectou` | `{sala}` | Servidor | Fallback se socket do presenter cai |
| `heartbeat` | `{sala}` | Display | Keep-alive (a cada ~15s) |

### Configuração ICE
```python
STUN_SERVERS = '["stun:stun.l.google.com:19302","stun:stun1.l.google.com:19302"]'
```

### Qualidade de Vídeo
- Resolução: ideal 1920×1080, max 1920×1080
- Frame rate: ideal 15fps, max 30fps
- Áudio: desabilitado

## 6. Sistema de Watchdog

### Cron Jobs
```
* * * * * /home/carapreta/totem_guardian.sh
* * * * * sleep 30 && /home/carapreta/totem_watchdog.sh
*/30 * * * * /home/carapreta/totem_watchdog.sh
```

### totem_guardian.sh (1 minuto)
1. Verifica IP da wlan0 → dhclient se necessário
2. Verifica Xorg → restart lightdm
3. Verifica openbox → reinstala/inicia
4. Força resolução 1440×900 (modeline personalizada)
5. Verifica Chromium kiosk apontando para `/display`
6. Desliga screensaver

### totem_watchdog.sh (30 minutos)
1. Verifica rede
2. Verifica lightdm
3. Verifica openbox
4. Verifica Chromium
5. Verifica resolução

## 7. Streaming RTSP (opcional)

### Especificação
| Parâmetro | Valor |
|-----------|-------|
| Dispositivo | `/dev/video0` |
| Resolução | 640×360 |
| FPS | 10 |
| Codec | H.264 (ultrafast) |
| Bitrate | 512 kbps |
| Áudio | Nenhum |
| URL | `rtsp://<ip>:8554/stream` |

## 8. Rede

### Configuração Atual
```
Interface: wlan0 (Wi-Fi)
IP: 172.17.28.179/16
Gateway: 172.17.0.1
DNS: DHCP
Hostname: carapreta-box
```

### Fallback
- Ethernet (eth0) disponível mas não configurada como primária
- O watchdog tenta `dhclient wlan0` se perder IP

## 9. Armazenamento

### Partições
```
Device          Size  Used  Mount
mmcblk2p1      7.1G  4.7G  /
zram0 (swap)   481M    0B  [SWAP]
zram1 (log)     50M   48M  /var/log
```

### Boot
```
/boot/
├── armbianEnv.txt
├── boot.cmd / boot.scr
├── vmlinuz-4.4.194-rk322x
├── uInitrd-4.4.194-rk322x
└── dtb/ → dtb-4.4.194-rk322x/
    └── rk322x-box.dtb
```

## 10. Segurança

### Atual
- ✅ Autenticação LDAP/AD (credenciais institucionais)
- ✅ Sessões Flask com cookie assinado
- ✅ Transmissão via WebRTC (sem senha VNC fixa)
- ⚠️ HTTP (sem HTTPS)
- ❌ Sem rate limiting no login

### Recomendado
- [ ] HTTPS com certificado auto-assinado
- [ ] Rate limiting no /login
- [ ] Fail2ban para SSH
- [ ] Logs de auditoria

## 11. Modo de Desenvolvimento

### Ativação
```bash
CARAPROJETADA_ENV=dev
```

### Diferenças para produção
| item | dev | prod |
|------|-----|------|
| host padrão | `127.0.0.1` | `0.0.0.0` |
| porta padrão | `5000` | `80` |
| autenticação | mock | ad/ldap |
| ldap3 | opcional | obrigatório |
| webrtc | normal | normal |
| socket.io debug | ativo | desligado |

### Credenciais mock
| usuário | senha |
|---------|-------|
| `admin` | `admin` |
| qualquer | `dev` |
| `usuario` | `usuario` |

## 12. Desempenho

O alvo real é limitado. Toda evolução visual ou de serviço deve ser validada no RK3229.

Metas iniciais:
- Flask idle abaixo de 5% CPU.
- Memória do app abaixo de 120 MB sem stream.
- Memória total adicional abaixo de 180 MB com WebRTC ativo.
- Temperatura abaixo de 75°C em uso contínuo.
- Conexão WebRTC abaixo de 5 segundos para estabelecer.
- Tela `/display` sem uso excessivo de CPU mesmo rodando 24/7.

Detalhes e checklist: `PERFORMANCE.md`.
