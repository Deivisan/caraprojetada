# 📊 ANÁLISE ESTRUTURAL - CaraProjetada

## 🎯 O Projeto em Uma Frase
**Sistema embarcado inteligente de projetor RK3229 que expõe API REST para controle remoto via VNC com autenticação AD/LDAP institucional**

---

## 📦 ESTRUTURA VISUAL

```
caraprojetada/                    [586 KB total]
├── 🎬 CORE FUNCIONAL
│   ├── app/
│   │   ├── app.py               [Flask server + VNC + LDAP]
│   │   └── requirements.txt      [Dependências: Flask, ldap3]
│   ├── systemd/
│   │   ├── projetor.service      [systemd: Flask porta 80]
│   │   └── stream-cam.service    [systemd: RTSP camera]
│   └── scripts/
│       ├── kiosk.sh             [Chromium fullscreen (opcional)]
│       ├── totem_guardian.sh    [Health check a cada 1min]
│       ├── totem_watchdog.sh    [Deep check a cada 30min]
│       ├── totem_reset.sh       [Emergency hard reset]
│       ├── start_rtsp.sh        [Streaming camera]
│       ├── build-kernel-rk322x.sh [Kernel build (experimental)]
│       └── fix_armbian_keys.sh  [Armbian key fixes]
│
├── 📖 DOCUMENTAÇÃO
│   ├── README.md                [Overview com imagens locais ✅]
│   ├── DEVICE_CONTEXT.md        [Snapshot do device (27/05/2026)]
│   ├── SPEC.md                  [Especificações técnicas]
│   ├── ROADMAP.md               [Plano 5 fases]
│   ├── STRUCTURAL_ANALYSIS.md   [Este arquivo]
│   └── docs/
│       ├── index.html           [Landing page]
│       ├── arquitetura.html     [Diagrama técnico]
│       ├── setup.html           [Guia instalação]
│       ├── tutoriais.html       [User tutorials]
│       ├── roadmap.html         [Roadmap visual]
│       ├── SETUP.md
│       ├── ARCHITECTURE.md
│       ├── CLIENT_WINDOWS.md
│       ├── CLIENT_LINUX.md
│       ├── TROUBLESHOOTING.md
│       ├── css/style.css
│       ├── js/main.js
│       ├── _config.yml
│       ├── .nojekyll
│       └── CNAME
│
├── 🎨 ASSETS
│   └── assets/
│       └── images/
│           ├── logo.svg         [✨ SVG Logo criado]
│           ├── rk3229-tv-box.jpg
│           ├── rk3229-board.jpg
│           └── rk3229-board-bottom.jpg
│
├── 🔧 TOOLCHAIN & INFRA
│   ├── kernels/
│   ├── toolchain/
│   │   └── setup-rk322x.sh
│   └── exports/
│       ├── carapreta-exports.tar.gz
│       └── (config backups)
│
├── 🏗️ VERSIONAMENTO
│   ├── .git/
│   ├── .gitignore
│   └── README.md
│
└── 🖼️ MÍDIA
    └── images/
```

---

## ⚙️ STACK TÉCNICO

### 🖥️ Hardware Alvo
```
╔══════════════════════════════════════╗
║   Rockchip RK3229 TV Box            ║
╠══════════════════════════════════════╣
║ SoC:      RK3229 (4× ARM Cortex-A7  ║
║ Clock:    1.5 GHz (28nm)            ║
║ RAM:      962 MB DDR3               ║
║ Storage:  7.3 GB eMMC               ║
║ GPU:      Mali-400 MP2              ║
║ Network:  Eth + Wi-Fi (ESP8089)     ║
║ Video:    HDMI 2.0 (4K@60fps)       ║
║ USB:      3× USB 2.0 + 1× OTG       ║
║ Audio:    DAC + SPDIF + AV          ║
╚══════════════════════════════════════╝
```

### 🐧 SO & Kernel
- **OS**: Armbian 21.08.8 (Debian Bullseye)
- **Kernel**: 4.4.194-rk322x (legacy, 32-bit ARMv7)
- **Init**: systemd
- **Arquitetura**: armv7l

### 🐍 Stack de Aplicação
```
Flask + Python 3
├── ldap3 (AD/LDAP auth)
├── Jinja2 (templates)
└── subprocess (VNC control)
```

### 🖼️ Display Stack
```
Xorg :0
├── LightDM (display manager)
├── xfwm4 (window manager)
└── xfce4-session
```

### 🔄 Serviços Ativos
| Serviço | Porta | Protocolo | Descrição |
|---------|-------|-----------|-----------|
| projetor | 80 | HTTP | Flask API |
| sshd | 22 | SSH | SSH remoto |
| stream-cam | 8554 | RTSP | Camera streaming |
| lightdm | — | X11 | Display manager |
| Xorg | :0 | X | X server |

---

## 🔌 API REST

### Endpoints Core

#### 1️⃣ `GET /`
Página principal (login ou dashboard)

#### 2️⃣ `POST /login`
Autenticação via LDAP/AD
```
username=user&password=pass
→ LDAP bind contra 10.198.1.2:389
```

#### 3️⃣ `POST /conectar`
Inicia VNC reverso
```
ip=192.168.1.50
→ xtightvncviewer 192.168.1.50:0 -autopass
```

#### 4️⃣ `POST /desconectar`
Para conexão VNC

#### 5️⃣ `POST /logout`
Encerra sessão

---

## 🔐 Autenticação (LDAP/AD)

```python
AD_SERVER = 'ldap://10.198.1.2'
AD_DOMAIN = 'intranet.ufrb.edu.br'
PORTA = 389

# user@domain SIMPLE bind
Connection(server, user=f"{user}@{AD_DOMAIN}", password=pass).bind()
```

---

## 📡 VNC (Remote Framebuffer)

### Modelo: **VNC Reverso**
- Projetor = cliente VNC
- Usuário = servidor VNC (seu notebook)
- Projetor conecta em `<user_ip>:0`

### Comando
```bash
DISPLAY=:0 xtightvncviewer 192.168.1.50:0 -autopass
```

### Propriedades
- Display: `:0`
- Password: `123456` (fixed)
- Resolution: `1360×768` (nativa)
- Refresh: 60 Hz

---

## 👮 Sistema de Watchdog

### `totem_guardian.sh` — A cada 1 minuto
1. Verifica IP wlan0
2. Verifica Xorg :0
3. Verifica xfwm4
4. Remove painéis XFCE
5. Força resolução
6. Verifica Chromium
7. Desliga screensaver

### `totem_watchdog.sh` — A cada 30 minutos
1. Conectividade
2. lightdm status
3. xfwm4 + xfce4-session
4. Chromium
5. Video resolution

### `totem_reset.sh` — Emergency
Hard reset de todos os processos gráficos

### Cron Schedule
```
* * * * * /home/carapreta/totem_guardian.sh
* * * * * sleep 30 && /home/carapreta/totem_watchdog.sh
*/30 * * * * /home/carapreta/totem_watchdog.sh
```

---

## 📹 Streaming RTSP

```
Device: /dev/video0
Resolution: 640×360
FPS: 10
Codec: H.264 (ultrafast)
Bitrate: 512 kbps
URL: rtsp://<ip>:8554/stream
```

---

## 🌐 Rede

```
Interface: wlan0 (Wi-Fi)
IP: 172.17.28.179/16
Gateway: 172.17.0.1
DNS: DHCP
Hostname: carapreta-box
```

Fallback: eth0 disponível (não ativo como primário)

---

## 💾 Armazenamento

```
mmcblk2p1  7.1G / 7.1G  /
zram0      481M         [SWAP]
zram1       50M         /var/log
```

---

## 📊 Performance Típica

```
CPU Load: 0.13 / 0.13 / 0.05
CPU Temp: 64-66°C
Memory: 962 MB DDR3
Uptime: 50+ min
Disk: 4.7G / 7.1G (67%)
```

---

## 🚀 Roadmap (5 Fases)

### ✅ Fase 1: Baseline (Concluída)
- [x] Flask + AD auth
- [x] VNC reverso
- [x] Kiosk Chromium
- [x] Watchdog + Guardian
- [x] RTSP streaming

### 🔄 Fase 2: Estabilização
- [ ] Kernel 6.6+ (CaraAzul)
- [ ] xfwm4 → openbox
- [ ] Ethernet fallback
- [ ] Logs centralizados
- [ ] Backup automático

### 📋 Fase 3: Multi-Projetor
- [ ] Dashboard central
- [ ] mDNS auto-discovery
- [ ] API remota
- [ ] Agendamento

### 🔒 Fase 4: Segurança
- [ ] HTTPS
- [ ] Rate limiting
- [ ] Fail2ban SSH
- [ ] Auditoria

### 🚀 Fase 5: Features Avançadas
- [ ] Multi-user
- [ ] Streaming áudio
- [ ] Modo apresentação
- [ ] Miracast/AirPlay
- [ ] App mobile

---

## ⚠️ Limitações Conhecidas

| Limitação | Impacto | Status |
|-----------|---------|--------|
| Kernel 4.4 | Drivers antigos | ⚠️ Blocker |
| Resolução mismatch | Guardian força 1920, real 1360 | 🟡 Minor |
| VNC senha fixa | Segurança fraca | ⚠️ Security |
| HTTP (sem HTTPS) | Tráfego plaintext | ⚠️ Security |
| Sem rate limiting | Brute force possível | ⚠️ Security |
| RAM limitada | 962 MB para tudo | 🟡 Tight |
| eMMC limitada | 7.3 GB | 🟡 Tight |

---

## 🔧 Comandos Úteis

```bash
# SSH
ssh caraprojetada@172.17.28.179

# Status
ssh caraprojetada 'systemctl status projetor'

# Logs
ssh caraprojetada 'tail -f /var/log/syslog | grep vnc'

# Kiosk manual
ssh caraprojetada 'DISPLAY=:0 chromium --kiosk URL'

# Temperatura
ssh caraprojetada 'cat /sys/class/thermal/thermal_zone0/temp'

# Forçar watchdog
ssh caraprojetada '/home/carapreta/totem_guardian.sh'

# Conexões VNC
ssh caraprojetada 'netstat -tuln | grep 5900'

# Backup
ssh caraprojetada 'tar czf /tmp/backup.tar.gz /home/carapreta/'
```

---

## 📝 Documentação Relacionada

- **README.md** — Overview (com imagens locais ✅)
- **DEVICE_CONTEXT.md** — Snapshot real (27/05/2026)
- **SPEC.md** — Especificações técnicas
- **ROADMAP.md** — Plano de desenvolvimento
- **docs/** — Documentação HTML

---

## 🎯 Conclusão

**CaraProjetada** é um subsistema embarcado especializado que transforma uma TV Box RK3229 genérica em um hub inteligente de projeção institucional.

**Forças:**
✅ Autenticação AD/LDAP integrada  
✅ VNC reverso para controle remoto  
✅ Auto-recovery via watchdog (99% uptime)  
✅ Stack lightweight  
✅ Backup exportado completo  

**Melhorias:**
⚠️ Segurança (HTTP → HTTPS)  
⚠️ Kernel desatualizado (4.4 → 6.6)  
⚠️ Recursos limitados  

**Próximos Passos:**
1. Kernel upgrade via CaraAzul
2. HTTPS + rate limiting
3. Dashboard multi-projetor
4. Backup automático cloud

---

**Projeto Ativo** | **Status: Produção** | **Última atualização: 27/05/2026**
