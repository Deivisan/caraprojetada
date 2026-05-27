# CaraProjetada - Projector VNC Subsystem

## 🎯 Objetivo

Transformar um TV Box Rockchip RK322x em um **controlador de projetor inteligente** com:
- Autenticação institucional via Active Directory (LDAP)
- Conexão reversa VNC para espelhamento de tela
- Modo kiosk para exibição de conteúdo web
- Auto-recuperação com watchdog
- Streaming de câmera USB via RTSP

## 📋 Hardware

### Dispositivo Alvo
- **SoC**: Rockchip RK3228 / RK3229 (ARM Cortex-A7 quad-core)
- **Arquitetura**: ARMv7 32-bit (armhf)
- **RAM**: 1-2GB DDR3
- **GPU**: Mali-400 MP4
- **Rede**: Ethernet RTL8201F (10/100) + Wi-Fi (Realtek/Broadcom)
- **Saída**: HDMI para projetor/TV
- **Câmera**: USB compatível com V4L2 (opcional)

## 🏗️ Stack de Software

### Sistema Operacional
- **Base**: Armbian (Bullseye) ou Arch Linux ARM
- **Kernel**: 4.4.194-rk322x (ou 6.6+ com CaraAzul)
- **Init**: systemd
- **Display**: Xorg + LightDM
- **WM**: xfwm4 (window manager mínimo)

### Dependências

```bash
# Core
sudo apt install -y \
  python3 python3-flask python3-ldap3 \
  xtightvncviewer chromium x11-utils \
  xserver-xorg-core xfwm4 lightdm \
  vlc vlc-bin               # para streaming RTSP

# Manutenção
sudo apt install -y \
  x11-xserver-utils \
  xfce4-panel               # gerenciado pelo guardian
```

## 📦 Repositório

### Estrutura
```
caraprojetada/
├── app/
│   └── app.py              # Flask server (porta 80)
├── scripts/
│   ├── kiosk.sh            # Modo kiosk Chromium
│   ├── totem_guardian.sh   # Guardião de saúde
│   ├── totem_watchdog.sh   # Watchdog periódico
│   ├── totem_reset.sh      # Reset de emergência
│   └── start_rtsp.sh       # Streaming RTSP
├── systemd/
│   ├── projetor.service    # Serviço Flask
│   └── stream-cam.service  # Serviço de streaming
├── docs/
│   ├── SETUP.md            # Guia de implantação
│   └── TROUBLESHOOTING.md  # Resolução de problemas
├── toolchain/              # Scripts de setup
├── images/                 # Imagens de boot
└── exports/                # Configs exportadas
```

## 🔐 Fluxo de Autenticação

```
Usuário → HTTP GET / → Login page → POST /login (user+pass)
         → LDAP bind no AD → Sessão criada → Painel de controle
         → POST /conectar → xtightvncviewer <user_ip>:0
```

### Configurações do AD no app.py

```python
AD_SERVER = 'ldap://10.198.1.2'
AD_DOMAIN = 'intranet.ufrb.edu.br'
```

## 🖥️ Conexão VNC

O projetor age como **cliente VNC reverso**:
1. Usuário loga no painel web
2. Usuário clica "CONECTAR TELA"
3. Projetor executa: `xtightvncviewer <ip_do_usuario>:0`
4. Senha VNC hardcoded: `123456`

**Requisito**: O notebook do usuário precisa ter um servidor VNC rodando (ex: TigerVNC, TightVNC Server)

## 📹 Streaming RTSP

- Usa VLC para capturar `/dev/video0`
- Transcodifica para H.264
- Disponibiliza em `rtsp://<ip>:8554/stream`

## 🛡️ Sistema de Watchdog

### totem_guardian.sh (todo minuto via cron)
- Verifica IP da wlan0 — tenta dhclient se sem IP
- Verifica Xorg — restart lightdm se morto
- Verifica xfwm4 — reinstala/inicia se ausente
- Remove painéis XFCE que cobrem o kiosk
- Força resolução 1920x1080
- Verifica Chromium em kiosk — reinicia se URL errada
- Desliga screensaver e DPMS

### totem_watchdog.sh (a cada 30min + 30s delay)
- Verifica rede (wlan0)
- Verifica lightdm
- Verifica xfwm4 e xfce4-session
- Verifica Chromium kiosk
- Verifica resolução

## 📡 Serviços Systemd

### projetor.service
- Executa `app.py` na porta 80
- Restart automático em 5s
- Sobe após rede

### stream-cam.service
- Executa `start_rtsp.sh`
- Restart automático em 5s
- Depende de rede

## 🔧 Próximos Passos

1. **Deploy inicial** — Copiar app.py e scripts para o box
2. **Configurar AD** — Ajustar AD_SERVER e AD_DOMAIN no app.py
3. **Ativar serviços** — systemctl enable projetor stream-cam
4. **Configurar cron** — watchdog e guardian
5. **Testar VNC** — Conectar de notebook com VNC server
6. **Documentar** — Completar docs com troubleshooting

## 📝 Notas

- O xfwm4 é crítico — sem ele, o cursor vira um "X"
- O guardian roda a cada minuto via cron para recuperação rápida
- O watchdog roda a cada 30min para verificações pesadas
- Chromium em kiosk usa `--incognito` para evitar cache
- A senha VNC está em `~/.vnc_pass` (atual: 123456)
