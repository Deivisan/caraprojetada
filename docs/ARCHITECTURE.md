# 🏗️ Arquitetura do CaraProjetada

## Visão Geral

O CaraProjetada é um **subsistema de controle de projetores** que transforma um TV Box RK3229 em um ponto de acesso para espelhamento de tela institucional.

### Stack Tecnológica

```
┌─────────────────────────────────────────────────────────────────┐
│                        APLICAÇÃO                                │
│  Flask (Python 3) · Porta 80 · LDAP3 · subprocess             │
├─────────────────────────────────────────────────────────────────┤
│                       SERVIÇOS SYSTEMD                          │
│  projetor.service · stream-cam.service · lightdm.service       │
├─────────────────────────────────────────────────────────────────┤
│                     GERENCIAMENTO (cron)                        │
│  totem_guardian.sh (1min) · totem_watchdog.sh (30min)          │
├─────────────────────────────────────────────────────────────────┤
│                        DISPLAY                                  │
│  Xorg · xfwm4 · Chromium (kiosk) · xtightvncviewer            │
├─────────────────────────────────────────────────────────────────┤
│                    SISTEMA OPERACIONAL                           │
│  Armbian 21.08.8 · Kernel 4.4.194-rk322x · Debian Bullseye    │
├─────────────────────────────────────────────────────────────────┤
│                        HARDWARE                                 │
│  Rockchip RK3229 · 4× Cortex-A7 · 1GB RAM · 8GB eMMC          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Fluxo Completo de Operação

### 1. Inicialização (boot)

```
Power On
  │
  ▼
U-Boot (boot.scr)
  │
  ▼
Kernel 4.4.194-rk322x
  │
  ▼
systemd init
  ├── lightdm.service → Xorg :0 → xfwm4
  ├── projetor.service → Flask na porta 80
  ├── stream-cam.service → VLC RTSP (se câmera presente)
  ├── NetworkManager → wlan0 (Wi-Fi)
  └── sshd → porta 22
        │
        ▼
  cron:
  ├── * * * * * totem_guardian.sh
  ├── * * * * * sleep 30 && totem_watchdog.sh
  └── */30 * * * * totem_watchdog.sh
```

### 2. Estado Ocioso (Kiosk)

Quando ninguém está usando o projetor:

```
Xorg :0
  │
  ▼
xfwm4 (window manager)
  │
  ▼
Chromium --kiosk https://www.uol.com.br/
  │
  ▼
HDMI → Projetor exibe site
```

### 3. Conexão VNC (Usuário Autenticado)

```
USUÁRIO                          CARAPRETA-BOX
  │                                    │
  │  GET http://172.17.28.179/         │
  │ ─────────────────────────────►     │
  │                                    │
  │  Renderiza LOGIN_HTML              │
  │ ◄──────────────────────────────    │
  │                                    │
  │  POST /login (user+pass)           │
  │ ─────────────────────────────►     │
  │                                    │
  │  autenticar_ad(username, password) │
  │  │                                 │
  │  ├── Server(ldap://10.198.1.2)    │
  │  ├── user_principal = user@domínio │
  │  ├── Connection.bind()             │
  │  │                                 │
  │  ├── Se OK → session['username']   │
  │  └── Se fail → {"error": ...}      │
  │                                    │
  │  Renderiza CONTROL_HTML            │
  │ ◄──────────────────────────────    │
  │                                    │
  │  POST /conectar                    │
  │  (user_ip = request.remote_addr)   │
  │ ─────────────────────────────►     │
  │                                    │
  │  pkill xtightvncviewer             │
  │  echo "123456" |                   │
  │  xtightvncviewer <user_ip>:0       │
  │  -autopass                         │
  │                                    │
  │  VNC CONNECT ═══════════════►      │
  │  (usuário deve ter VNC server      │
  │   rodando em :0)                   │
  │                                    │
  │  TELA DO USUÁRIO → PROJETOR        │
  │                                    │
  │  POST /desconectar                 │
  │ ─────────────────────────────►     │
  │  pkill xtightvncviewer             │
  │  Volta ao kiosk Chromium           │
```

---

## 🔐 Sistema de Autenticação

### Active Directory / LDAP

```
Servidor AD: ldap://10.198.1.2 (porta 389)
Domínio:     intranet.ufrb.edu.br

Formato do usuário: username@intranet.ufrb.edu.br
```

### Fluxo de Bind LDAP

```python
user_principal = f"{username}@{AD_DOMAIN}"
server = Server(AD_SERVER, get_info=ALL)
conn = Connection(server, user=user_principal, 
                  password=password, authentication='SIMPLE')
if conn.bind():
    # Autenticado!
    session['username'] = username
```

### Sessões Flask

- `secret_key`: `chave_secreta_para_sessoes_vnc_projetor`
- Sessão baseada em cookies
- Timeout: padrão Flask (31 dias) ou até logout

---

## 🛡️ Sistema de Watchdog

### totem_guardian.sh (execução: a cada 1 minuto via cron)

| Verificação | Ação corretiva |
|-------------|---------------|
| Wi-Fi sem IP | `sudo dhclient wlan0` |
| Xorg morto | `sudo systemctl restart lightdm` |
| xfwm4 ausente | Instala e inicia `xfwm4 --replace` |
| Painéis XFCE | Remove com `xfconf-query` |
| Resolução incorreta | Força `xrandr --mode 1920x1080` |
| Chromium não-kiosk | Mata e reinicia com URL correta |
| Screensaver ligado | `xset s off`, `xset -dpms`, `xset s noblank` |

### totem_watchdog.sh (execução: a cada 30 min + 30s delay)

| Verificação | Ação corretiva |
|-------------|---------------|
| Rede (wlan0) | `dhclient wlan0` se sem IP |
| LightDM | `systemctl start lightdm` |
| xfwm4 / xfce4-session | Inicia sessão XFCE |
| Chromium kiosk | Mata e reinicia |
| Resolução | Verifica via xrandr |

### totem_reset.sh (manual — emergência)

```bash
/home/carapreta/totem_reset.sh
```

Mata lightdm, chromium, xfce4-panel e reinicia o display manager.

---

## 📡 Serviços Systemd

### projetor.service

```ini
[Unit]
Description=Servico Web de Controle do Projetor VNC
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/carapreta
ExecStart=/usr/bin/python3 /home/carapreta/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Comportamento**: Se o Flask cair, reinicia em 5 segundos. Sempre.

### stream-cam.service

```ini
[Unit]
Description=Streaming da Webcam via VLC
After=network-online.target

[Service]
Type=simple
User=carapreta
ExecStart=/home/carapreta/start_rtsp.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Stream**: `rtsp://<ip>:8554/stream`

---

## 💾 Armazenamento e Boot

### Partições

```
mmcblk2 (7.3 GB eMMC)
├── mmcblk2p1 (7.1 GB) → / (ext4)
├── mmcblk2boot0 (2 MB) → Bootloader Rockchip
├── mmcblk2boot1 (2 MB) → Bootloader Rockchip
└── mmcblk2rpmb (128 KB) → RPMB

zram0 (481 MB) → SWAP
zram1 (50 MB) → /var/log
```

### Parâmetros de Boot

```
root=UUID=213d2a8b-27c6-447e-8f51-38cdda32f4d3
console=ttyS2,115200n8
console=tty1
rootwait rootfstype=ext4
usb-storage.quirks=0x2537:0x1066:u,0x2537:0x1068:u
```

### Trigger Maskrom (U-Boot)

O `boot.cmd` inclui lógica para entrar em modo Rockchip maskrom:
```bash
if gpio input D25; then
    mw 0x110005c8 0xEF08A53C
    reset
fi
```
Isso permite recuperação via USB mesmo se o sistema não bootar.

---

## 📊 Métricas de Desempenho

| Métrica | Valor |
|---------|-------|
| RAM total | 962 MB |
| RAM livre (ocioso) | ~842 MB |
| RAM usada (Flask + Xorg) | ~83 MB |
| CPU (ocioso) | ~8% |
| Disco livre | 2.1 GB (70% usado) |
| Swap | 481 MB (0% usado) |
| Uptime | 2h37min |
| Temp. CPU | ~66°C |

---

## 🔄 Upgrade Path

### Curto Prazo
- Migrar kernel para 6.6 LTS via CaraAzul
- Corrigir resolução real (1360x768, não 1920x1080)
- Adicionar HTTPS

### Médio Prazo
- Substituir xfwm4 por openbox (mais leve)
- Adicionar fallback Ethernet
- Dashboard multi-projetor

### Longo Prazo
- Migrar para Arch Linux ARM (CaraAzul)
- Substituir Chromium por WebView nativo
- Compatibilidade Miracast/AirPlay
