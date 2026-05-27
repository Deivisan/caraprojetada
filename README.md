<p align="center">
  <img src="https://raw.githubusercontent.com/Deivisan/caraprojetada/main/assets/images/logo.svg" alt="CaraProjetada" width="120">
</p>

<h1 align="center">🎯 CaraProjetada</h1>

<p align="center">
  <strong>Subsistema inteligente de projetores multi-sala com autenticação institucional</strong>
</p>

<p align="center">
  <a href="https://github.com/Deivisan/caraprojetada"><img src="https://img.shields.io/badge/status-produçao-green?style=flat"></a>
  <a href="#"><img src="https://img.shields.io/badge/SoC-RK3229%20(ARMv7)-blue?style=flat"></a>
  <a href="#"><img src="https://img.shields.io/badge/VNC-UltraVNC-orange?style=flat"></a>
  <a href="#"><img src="https://img.shields.io/badge/auth-AD%20LDAP-1f6feb?style=flat"></a>
</p>

---

## 🏗️ Arquitetura Multi-Projetor

### Visão Geral

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DASHBOARD CENTRAL (Web)                             │
│                   http://projetores.intranet.ufrb.edu.br                    │
│                                                                             │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐          │
│  │   SALA A   │  │   SALA B   │  │   SALA C   │  │   SALA D   │          │
│  │  172.17.x.x│  │ 172.17.x.x │  │ 172.17.x.x │  │ 172.17.x.x │          │
│  │   [CONECTAR]│  │ [CONECTAR] │  │ [CONECTAR] │  │ [CONECTAR] │          │
│  └──────┬─────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
└─────────┼───────────────┼─────────────────┼─────────────────┼─────────────────┘
          ▼               ▼                 ▼                 ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   PROJETOR A    │ │   PROJETOR B    │ │   PROJETOR C    │ │   PROJETOR D    │
│   RK3229        │ │   RK3229        │ │   RK3229        │ │   RK3229        │
│   192.168.1.101 │ │   192.168.1.102 │ │   192.168.1.103 │ │   192.168.1.104 │
│   ┌───────────┐ │ │   ┌───────────┐ │ │   ┌───────────┐ │ │   ┌───────────┐ │
│   │ xtightvnc│ │ │   │ xtightvnc│ │ │   │ xtightvnc│ │ │   │ xtightvnc│ │
│   │ viewer    │ │ │   │ viewer    │ │ │   │ viewer    │ │ │   │ viewer    │
│   └─────┬─────┘ │ │   └─────┬─────┘ │ │   └─────┬─────┘ │ │   └─────┬─────┘ │
│         ▼       │ │         ▼       │ │         ▼       │ │         ▼       │
│   ┌───────────┐ │ │   ┌───────────┐ │ │   ┌───────────┐ │ │   ┌───────────┐ │
│   │ Flask API │ │ │   │ Flask API │ │ │   │ Flask API │ │ │   │ Flask API │ │
│   │ (porta 80)│ │ │   │ (porta 80)│ │ │   │ (porta 80)│ │ │   │ (porta 80)│ │
│   └─────┬─────┘ │ │   └─────┬─────┘ │ │   └─────┬─────┘ │ │   └─────┬─────┘ │
│         ▼       │ │         ▼       │ │         ▼       │ │         ▼       │
│   ┌───────────┐ │ │   ┌───────────┐ │ │   ┌───────────┐ │ │   ┌───────────┐ │
│   │ LightDM   │ │ │   │ LightDM   │ │ │   │ LightDM   │ │ │   │ LightDM   │ │
│   │ Xorg :0   │ │ │   │ Xorg :0   │ │ │   │ Xorg :0   │ │ │   │ Xorg :0   │ │
│   └───────────┘ │ │   └───────────┘ │ │   └───────────┘ │ │   └───────────┘ │
└─────────────────┘ └─────────────────┘ └─────────────────┘ └─────────────────┘
```

---

## 🔐 Fluxo de Autenticação

### Dashboard Central

```
Usuario          Dashboard            AD Server
   │                 │                    │
   │  1. GET /          │                    │
   │ ───────────────────►│                    │
   │                 │  2. HTML Login        │
   │  ◄───────────────────│                    │
   │                 │                    │
   │  3. POST /login      │                    │
   │ ───────────────────►│                    │
   │                 │  4. LDAP bind          │
   │                 │ ───────────────►       │
   │                 │ ◄──────────────OK       │
   │  ◄───────────────────│                    │
   │                 │  5. HTML Dashboard     │
   │                 │  (lista salas)          │
```

### Conexão a uma Sala

```
Usuario          Projetor (A)
   │                 │
   │  6. POST /sala/a/conectar         │
   │ ───────────────────────────────►│
   │                 │  7. Killa viewer antigo │
   │                 │     (se existir)        │
   │                 │  8. Executa:            │
   │                 │     xtightvncviewer      │
   │                 │     <IP_USUARIO>:0       │
   │                 │     -autopass (123456)  │
   │                 │ ───────────────────────►│
   │  9. VNC Server (UltraVNC)               │
   │ ◄═════════════════════════════════════════►│
   │      Tela do notebook no projetor
```

---

## 📊 Hardware Target

### Rockchip RK3229 TV Box

| Componente | Especificação |
|------------|---------------|
| **SoC** | Rockchip RK3229, 28nm |
| **CPU** | 4x Cortex-A7 @ 1.5 GHz |
| **GPU** | Mali-400 MP2 |
| **RAM** | 1 GB DDR3 |
| **eMMC** | 8 GB |
| **Rede** | 10/100 Ethernet + Wi-Fi |
| **USB** | 3x USB 2.0 |
| **Vídeo** | HDMI 2.0 (4K@60fps) |

<img src="https://raw.githubusercontent.com/Deivisan/caraprojetada/main/assets/images/rk3229-tv-box.jpg" width="400" alt="RK3229 TV Box">

---

## 📦 Estrutura do Projeto

```
caraprojetada/
├── app/
│   ├── app.py              # Flask server + VNC control + AD auth
│   └── requirements.txt    # Flask, LDAP3
├── scripts/
│   ├── kiosk.sh            # Chromium kiosk mode
│   ├── totem_guardian.sh   # System health guardian
│   ├── totem_watchdog.sh   # Periodic watchdog
│   ├── totem_reset.sh      # Emergency reset
│   ├── start_rtsp.sh       # RTSP camera streaming
│   └── build-kernel.sh     # Kernel building (CaraAzul)
├── systemd/
│   ├── projetor.service    # Flask service (port 80)
│   └── stream-cam.service  # RTSP streaming service
├── docs/
│   ├── ARCHITECTURE.md     # Arquitetura detalhada
│   ├── CLIENT_WINDOWS.md   # Guia cliente Windows
│   ├── SETUP.md            # Guia de implantação
│   └── TROUBLESHOOTING.md  # Solução de problemas
└── assets/
    └── images/             # Imagens do hardware
```

---

## 🎯 Roadmap

### Fase 1: Projetor Único (Atual)

✅ SSH keyless access (`ssh caraprojetada`)  
✅ Flask + LDAP auth  
✅ VNC reverse via xtightvncviewer  
✅ Watchdog + Guardian  
✅ Streaming RTSP  

### Fase 2: Multi-Sala

- [ ] Dashboard central web com lista de salas
- [ ] Registry de projetores (IP + status)
- [ ] API `/api/salas` para descoberta
- [ ] Compatibilidade UltraVNC <-> xtightvncviewer

### Fase 3: Cliente Windows

- [ ] Instalador automático UltraVNC
- [ ] Configuração senha headless (123456)
- [ ] Auto-descoberta via dashboard
- [ ] Botão "Transmitir para Projetor"

---

## 🔧 Comandos Úteis

```bash
# SSH direto
caraprojetada

# Status do projetor
ssh caraprojetada 'systemctl status projetor'

# Logs do VNC
ssh caraprojetada 'tail -f /var/log/vnc.log'

# Kiosk manual
ssh caraprojetada 'DISPLAY=:0 chromium --kiosk https://www.uol.com.br/'
```

---

## 📋 Perguntas para Arquitetura Final

### P1: Descoberta
**Resposta do usuário**: Dashboard web com salas listadas - o usuário clica em "CONECTAR"

**Implementação**:
- Endpoint `/api/salas` retorna JSON com projetores ativos
- Frontend mostra cards de salas com status online/offline
- Ao clicar, chama `/sala/{id}/conectar`

### P2: Autenticação
**Resposta do usuário**: AD/LDAP

### P3: Conexão
**Resposta do usuário**: Botão manual

### P4: Protocolo
**Resposta do usuário**: UltraVNC

---

<p align="center">
  <a href="https://github.com/Deivisan/caraprojetada">github.com/Deivisan/caraprojetada</a>
</p>