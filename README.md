<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/deivisan/caraprojetada/main/assets/logo-dark.svg">
    <img alt="CaraProjetada" src="https://raw.githubusercontent.com/deivisan/caraprojetada/main/assets/logo-light.svg" width="120">
  </picture>
</p>

<h1 align="center">🎯 CaraProjetada</h1>

<p align="center">
  <strong>Subsistema inteligente de controle de projetores com autenticação institucional</strong>
</p>

<p align="center">
  <a href="https://github.com/deivisan/caraprojetada"><img src="https://img.shields.io/badge/status-produção-green?style=flat-square"></a>
  <a href="#"><img src="https://img.shields.io/badge/SoC-RK3229%20(ARMv7)-blue?style=flat-square"></a>
  <a href="#"><img src="https://img.shields.io/badge/VNC-xtightvnc-orange?style=flat-square"></a>
  <a href="#"><img src="https://img.shields.io/badge/auth-AD%20LDAP-1f6feb?style=flat-square"></a>
  <a href="#"><img src="https://img.shields.io/badge/kernel-4.4.194--rk322x-red?style=flat-square"></a>
  <a href="https://github.com/deivisan/caraprojetada/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-lightgrey?style=flat-square"></a>
</p>

<br>

> **CaraPreta** → nome do dispositivo físico (TV Box)  
> **CaraAzul** → reabilitação do hardware com kernel moderno (Arch Linux ARM)  
> **CaraProjetada** → subsistema de controle de projetores que RODA neste hardware

---

## 📋 O que é

O **CaraProjetada** transforma um TV Box chinês **Rockchip RK3229** (1GB RAM, 8GB eMMC) em um **controlador inteligente de projetores** institucionais.

O sistema permite que qualquer usuário autenticado via **Active Directory** conecte sua tela ao projetor através de **VNC reverso** — sem fios, sem adaptadores, sem complicação.

### ✨ Funcionalidades

| Recurso | Descrição |
|---------|-----------|
| 🔐 **Autenticação AD/LDAP** | Login com credenciais institucionais |
| 🖥️ **VNC Reverso** | Projetor conecta na tela do usuário |
| 📺 **Kiosk Mode** | Chromium em tela cheia quando ocioso |
| 📹 **Streaming RTSP** | Câmera USB disponível na rede |
| 🛡️ **Auto-recuperação** | Watchdog + Guardian cuidam do sistema 24/7 |
| ⚡ **Zero manutenção** | Tudo automático, restart em 5s se falhar |

---

## 🧠 Arquitetura

### Componentes

```
┌──────────────────────────────────────────────────────────┐
│                    CARAPRETA-BOX                          │
│                   (RK3229 · 1GB RAM)                      │
│                                                           │
│  ┌──────────┐    ┌──────────────┐    ┌────────────────┐  │
│  │  Flask    │    │   Chromium   │    │  xtightvncviewer │  │
│  │  :80      │    │   Kiosk      │    │  (VNC cliente)  │  │
│  └────┬─────┘    └──────┬───────┘    └───────┬──────────┘  │
│       │                 │                    │              │
│  ┌────▼─────┐    ┌──────▼───────┐    ┌───────▼──────────┐  │
│  │  LDAP    │    │   totem_    │    │   stream-cam     │  │
│  │  Auth    │    │   guardian   │    │   (RTSP :8554)   │  │
│  └──────────┘    └──────────────┘    └──────────────────┘  │
│                                                           │
│  ┌──────────────────────────────────────────────────────┐ │
│  │         systemd · cron · lightdm · xfwm4             │ │
│  └──────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
         │
         │ HDMI
         ▼
┌───────────────────┐
│    PROJETOR / TV   │
│   1360x768 / 1080p │
└───────────────────┘
```

### Fluxo de Conexão VNC

```
USUÁRIO                    CARAPRETA-BOX                   PROJETOR
  │                             │                             │
  │  1. Abre navegador          │                             │
  │  ──────────────────────►    │                             │
  │  http://172.17.28.179       │                             │
  │                             │                             │
  │  2. Insere login/senha AD   │                             │
  │  ──────────────────────►    │                             │
  │                             │  3. LDAP bind               │
  │                             │  ───────► AD Server         │
  │                             │  ◄─────── OK                │
  │  ◄──────────────────────    │                             │
  │       Painel de controle    │                             │
  │                             │                             │
  │  4. Clica "CONECTAR TELA"   │                             │
  │  ──────────────────────►    │                             │
  │                             │  5. xtightvncviewer         │
  │                             │     <user_ip>:0             │
  │                             │  ───────────────────────►   │
  │  6. VNC Server (:0)         │                             │
  │  ◄═════════════════════════════════════════════════════►   │
  │                             │                             │
  │      TELA DO USUÁRIO NO PROJETOR                         │
```

---

## 🔧 Hardware

### Rockchip RK3229 TV Box

![RK3229 TV Box](https://raw.githubusercontent.com/deivisan/caraprojetada/main/assets/images/rk3229-tv-box.jpg)

> Imagem ilustrativa de um TV Box MXQ 4K com Rockchip RK3229. O hardware real pode variar em aparência, mas o chipset é o mesmo.

| Componente | Especificação |
|------------|---------------|
| **SoC** | Rockchip RK3229, 28nm |
| **CPU** | 4× Cortex-A7 @ 1.5 GHz |
| **GPU** | Mali-400 MP2 |
| **RAM** | 1 GB DDR3 |
| **Storage** | 8 GB eMMC |
| **Rede** | 10/100 Ethernet + Wi-Fi 802.11 b/g/n |
| **USB** | 3× USB 2.0 + 1× USB OTG |
| **Vídeo** | HDMI 2.0 (4K@60fps) + AV composto |
| **Áudio** | HDMI + SPDIF + AV |
| **Expansão** | Micro SD (até 128 GB) |
| **Alimentação** | DC 5V/2A |

### Pinagem Serial (UART)

Para acesso ao console serial, o conector não-populado na placa (3 pinos) segue:

```
Pino 1: GND
Pino 2: TX (3.3V)
Pino 3: RX (3.3V)
```

Configuração: **115200 baud, 8N1**

---

## 📦 Repositório

```
caraprojetada/
├── app/
│   ├── app.py              # 🎯 Flask: servidor web + AD auth + VNC
│   └── requirements.txt    # Dependências Python
├── scripts/
│   ├── kiosk.sh            # 🖥️ Chromium kiosk mode
│   ├── totem_guardian.sh   # 🛡️ Guardião (execução: a cada 1 min)
│   ├── totem_watchdog.sh   # 🔍 Watchdog (execução: a cada 30 min)
│   ├── totem_reset.sh      # 🔄 Reset de emergência
│   ├── start_rtsp.sh       # 📹 Streaming de câmera RTSP
│   └── build-kernel-rk322x.sh  # ⚙️ Build de kernel RK322x
├── systemd/
│   ├── projetor.service    # ⚡ Serviço Flask (porta 80)
│   └── stream-cam.service  # ⚡ Serviço de streaming RTSP
├── docs/
│   ├── SETUP.md            # Guia de implantação completo
│   ├── TROUBLESHOOTING.md  # Guia de resolução de problemas
│   └── ARCHITECTURE.md     # Arquitetura detalhada
├── toolchain/
│   └── setup-rk322x.sh     # 🔧 Ambiente de build cross-compile
├── assets/
│   └── images/             # 📸 Imagens do hardware e diagramas
├── exports/                # 📤 Backup dos arquivos do dispositivo
├── .gitignore
├── README.md               # Você está aqui
├── SPEC.md                 # Especificação técnica completa
├── DEVICE_CONTEXT.md       # Contexto do dispositivo físico
└── ROADMAP.md              # Roadmap do projeto
```

---

## ⚡ Deploy Rápido

```bash
# 1. Conectar no dispositivo
ssh carapreta@172.17.28.179

# 2. Instalar dependências
sudo apt update && sudo apt install -y \
  python3-flask python3-ldap3 xtightvncviewer chromium

# 3. Copiar e iniciar o serviço
git clone https://github.com/deivisan/caraprojetada.git
sudo cp caraprojetada/systemd/projetor.service /etc/systemd/system/
sudo systemctl enable --now projetor

# 4. Configurar watchdog (cron)
crontab -e
# Adicione:
# * * * * * /home/carapreta/totem_guardian.sh
# */30 * * * * /home/carapreta/totem_watchdog.sh
```

> 📖 Guia completo em: [`docs/SETUP.md`](docs/SETUP.md)

---

## 🔐 Endpoints da API

| Rota | Método | Descrição |
|------|--------|-----------|
| `/` | GET | Página inicial (login ou painel) |
| `/login` | POST | Autenticação via LDAP/AD |
| `/logout` | POST | Encerrar sessão |
| `/conectar` | POST | Iniciar VNC reverso para o IP do usuário |
| `/desconectar` | POST | Desconectar VNC |

---

## 🔗 Projetos Relacionados

- **[CaraAzul](https://github.com/deivisan/caraazul)** — Kernel 6.6+ moderno + Arch Linux ARM para o mesmo hardware RK322x
- **[CaraPreta](https://github.com/deivisan/carapreta)** — Documentação do dispositivo físico e bootchain

---

## 📄 Licença

MIT © Deivison Santana

---

<p align="center">
  <sub>Feito com 🎯 para transformar sucata eletrônica em infraestrutura funcional</sub>
</p>
