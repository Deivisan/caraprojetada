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
- **Display**: Xorg + LightDM + xfwm4
- **Shell**: bash 5.x

### Dependências Core
```bash
# Web server + auth
python3 python3-flask python3-ldap3

# VNC
xtightvncviewer

# Display
xserver-xorg-core xfwm4 lightdm x11-utils

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
| `projetor` | 80 | ✅ Ativo | Flask: controle VNC + AD |
| `sshd` | 22 | ✅ Ativo | Acesso remoto |
| `lightdm` | — | ✅ Ativo | Gerenciador de display |
| `stream-cam` | 8554 | ✅ Ativo | Streaming RTSP (câmera) |
| `NetworkManager` | — | ✅ Ativo | Gerenciamento de rede |

## 3. API REST

### `GET /`
- **Descrição**: Página inicial
- **Resposta**: HTML (tela de login ou painel de controle)

### `POST /login`
- **Parâmetros**: `username` (string), `password` (string)
- **Autenticação**: LDAP bind contra Active Directory
- **Resposta sucesso**: Redirect para `/`
- **Resposta erro**: HTML com mensagem de erro

### `POST /logout`
- **Descrição**: Encerra sessão
- **Resposta**: Redirect para `/`

### `POST /conectar`
- **Parâmetros**: `ip` (string, IP do cliente)
- **Ação**: Executa `xtightvncviewer <ip>:0 -autopass`
- **Senha VNC**: 123456

### `POST /desconectar`
- **Ação**: Mata processo `xtightvncviewer`

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

## 5. VNC (Remote Framebuffer)

### Modelo: VNC Reverso
- O projetor é **cliente** VNC (não servidor)
- O usuário deve ter um **servidor** VNC rodando em sua máquina
- O projetor conecta no IP do usuário porta 5900 (:0)

### Comando Executado
```bash
echo "123456" | DISPLAY=:0 sudo /usr/bin/xtightvncviewer <user_ip>:0 -autopass
```

### Display
- `:0` — Display Xorg principal
- Resolução atual: **1360×768** (nativa do projetor conectado)
- Suporta: 1920×1080i, 1280×720, 1024×768, 800×600, 640×480

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
3. Verifica xfwm4 → reinstala/inicia
4. Remove painéis XFCE
5. Força resolução 1920×1080
6. Verifica Chromium kiosk
7. Desliga screensaver

### totem_watchdog.sh (30 minutos)
1. Verifica rede
2. Verifica lightdm
3. Verifica xfwm4/xfce4-session
4. Verifica Chromium
5. Verifica resolução

## 7. Streaming RTSP

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
- ⚠️ HTTP (sem HTTPS)
- ⚠️ Senha VNC fixa (123456)
- ❌ Sem rate limiting no login

### Recomendado
- [ ] HTTPS com certificado auto-assinado
- [ ] Rate limiting no /login
- [ ] Fail2ban para SSH
- [ ] Senha VNC configurável por sessão
- [ ] Logs de auditoria

## 11. Desempenho e Observabilidade

O alvo de produção é uma box RK3229 com recursos limitados. Toda mudança visual, novo serviço ou nova dependência deve ser medida no hardware real antes de ser promovida para `main`.

Metas iniciais:

- CPU idle abaixo de 5%.
- Memória do app abaixo de 120 MB sem VNC.
- Conexão VNC em até 3 segundos após o clique.
- Temperatura ideal abaixo de 75°C.
- Espaço livre em `/` acima de 1 GB.
- Logs curtos para evitar saturar `/var/log` em zram.

Checklist e comandos: `PERFORMANCE.md`.
