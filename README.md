# CaraProjetada 🎯

<p align="center">
  <img src="https://upload.wikimedia.org/wikipedia/commons/7/74/Arch_Linux_logo.svg" alt="Arch Linux Logo" width="110" />
</p>

![Status](https://img.shields.io/badge/status-produçao-green)
![Platform](https://img.shields.io/badge/platform-RK322x%20(ARMv7)-blue)
![VNC](https://img.shields.io/badge/VNC-xtightvnc-orange)
![Auth](https://img.shields.io/badge/auth-AD%20LDAP-1f6feb)

> **CaraPreta** inspirou o boot.  
> **CaraAzul** trouxe o kernel moderno.  
> **CaraProjetada** é o subsistema de controle de projetores com autenticação institucional e acesso remoto via VNC.

---

## 🚀 Visão do projeto

Transformar TV Boxes RK322x em **controladores de projetores inteligentes** com:

- 🔐 Autenticação via Active Directory (LDAP)
- 🖥️ Conexão VNC reversa (usuário conecta a tela ao projetor)
- 📺 Kiosk mode (Chromium em tela cheia)
- 📹 Streaming de câmera RTSP
- 🛡️ Watchdog automático de recuperação
- ⚡ Zero manutenção — auto-recuperável

### Como funciona

```
Usuário → Navegador → app.py (Flask) → Autentica AD → Conecta VNC
                                                         ↓
                                           Projetor exibe tela do usuário
```

---

## 📌 Estado atual

- ✅ Flask app com autenticação AD/LDAP
- ✅ Conexão VNC reversa (xtightvncviewer)
- ✅ Kiosk Chromium com auto-recuperação
- ✅ Watchdog e Guardian (cron + systemd)
- ✅ Streaming RTSP de câmera USB
- ✅ Serviços systemd auto-iniciáveis
- ✅ Resolução HDMI 1920x1080 forçada

---

## 🏗️ Arquitetura

```
caraprojetada/
├── app/                # Aplicação web Flask
│   └── app.py          # Servidor de controle do projetor
├── scripts/            # Scripts de manutenção e operação
│   ├── kiosk.sh        # Modo kiosk Chromium
│   ├── totem_guardian.sh   # Guardião de saúde do sistema
│   ├── totem_watchdog.sh   # Watchdog periódico
│   ├── totem_reset.sh      # Reset completo
│   └── start_rtsp.sh       # Streaming de câmera
├── systemd/            # Serviços systemd
│   ├── projetor.service    # Serviço principal Flask
│   └── stream-cam.service  # Serviço de streaming
├── docs/               # Documentação
├── kernels/            # Kernels RK322x (como CaraAzul)
├── toolchain/          # Scripts de setup
├── images/             # Imagens de boot/sistema
└── exports/            # Exportações e backups
```

---

## 🛠️ Deploy rápido

```bash
# Instalar dependências
sudo apt install -y python3-flask python3-ldap3 xtightvncviewer chromium

# Copiar app
sudo cp app/app.py /home/carapreta/
sudo cp systemd/projetor.service /etc/systemd/system/
sudo systemctl enable --now projetor

# Copiar scripts de watchdog
sudo cp scripts/*.sh /home/carapreta/
crontab -e
# Adicionar:
# * * * * * /home/carapreta/totem_guardian.sh
# */30 * * * * /home/carapreta/totem_watchdog.sh
```

---

## 🔐 Fluxo de autenticação

1. Usuário acessa `http://<ip-do-projetor>:80`
2. Insere credenciais institucionais (usuário@dominio)
3. Flask autentica via LDAP no Active Directory
4. Painel exibe IP do usuário + botão "CONECTAR TELA"
5. Ao clicar, o projetor inicia `xtightvncviewer <ip>:0`
6. Usuário deve estar com VNC server rodando na máquina

---

## 📡 Endpoints da API

| Rota | Método | Descrição |
|------|--------|-----------|
| `/` | GET | Página inicial (login ou painel) |
| `/login` | POST | Autenticação LDAP |
| `/logout` | POST | Encerrar sessão |
| `/conectar` | POST | Conectar VNC ao IP do usuário |
| `/desconectar` | POST | Desconectar VNC |

---

## 🔧 Hardware alvo

- **SoC**: Rockchip RK3228/RK3229 (ARM Cortex-A7)
- **RAM**: 1-2GB DDR3
- **GPU**: Mali-400 MP4
- **Saída**: HDMI (projetor/TV)
- **Rede**: Ethernet 10/100 + Wi-Fi
- **Câmera**: USB (opcional, para streaming)

---

## 🏷️ Tópicos

`rk322x` `rockchip` `tv-box` `armv7` `vnc` `projetor` `ldap` `active-directory` `kiosk` `chromium` `armbian` `embedded-linux`
