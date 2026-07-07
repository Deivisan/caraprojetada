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
- **Parâmetros**: `pin` (string, 4 dígitos — senha do servidor VNC do usuário)
- **IP do cliente**: autodetectado via `request.remote_addr` (não é mais campo de formulário)
- **Ação**: Executa `echo "<pin>" | xtightvncviewer <ip>:0 -autopass` usando o PIN digitado como senha VNC
- **Validação de conexão**: o viewer é lançado e o app aguarda até ~6s; se o processo sai (PIN/senha errado ou servidor VNC off) a sessão **não** é marcada como ativa e um erro é retornado ao usuário. Só marca "conectado" quando o viewer continua rodando (conexão estabelecida de verdade).

### `POST /desconectar`
- **Ação**: Mata processo `xtightvncviewer`

### `GET /projetor`
- **Descrição**: Tela idle do projetor, desenhada para ficar 24/7 em fullscreen no hdmi.
- **Conteúdo**: Identidade do sistema, instruções de conexão, URL de acesso, relógio e status livre/ocupado.
- **Atualização**: Polling de `/api/v1/status` a cada 30 segundos.

### `GET /vnc-view`
- **Descrição**: Emulação visual da experiência TightVNC no modo desenvolvimento.
- **Disponibilidade**: Somente quando `CARAPROJETADA_ENV=dev`; em produção redireciona para `/`.
- **Uso**: Após `POST /conectar` em modo dev, a aplicação redireciona para esta tela.

### `GET /api/v1/status`
- **Descrição**: Retorna status JSON do projetor, modo, sessão ativa, usuário atual, IP e display.

### `POST /api/dev/reset`
- **Descrição**: Reseta `current_session` em modo dev.
- **Disponibilidade**: Somente quando `CARAPROJETADA_ENV=dev`.

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
echo "<pin>" | DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0 \
  /usr/bin/xtightvncviewer -autopass -quality 6 -compresslevel 9 \
  -fullscreen <user_ip>:<display>
```
- O `<pin>` é o valor digitado na interface (a própria senha do servidor VNC do usuário).
- `<display>` é `:0` (Windows/macOS) ou `:3` (Linux), detectado pelo `User-Agent`.
- Não há mais senha VNC fixa no código — ela vem do campo PIN da interface.

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
- ✅ PIN/senha VNC informado pelo usuário na interface (sem valor fixo no código)
- ✅ Validação real de conexão VNC (não marca "conectado" se a senha estiver errada)
- ⚠️ HTTP (sem HTTPS)
- ❌ Sem rate limiting no login

### Recomendado
- [ ] HTTPS com certificado auto-assinado
- [ ] Rate limiting no /login
- [ ] Fail2ban para SSH
- [ ] Senha VNC configurável por sessão
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
| vnc | simulado | real via `xtightvncviewer` |
| `/api/dev/reset` | disponível | indisponível |
| `/vnc-view` | disponível | redireciona |

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
- Memória do app abaixo de 120 MB sem VNC.
- Memória total adicional abaixo de 180 MB com VNC ativo.
- Temperatura abaixo de 75°C em uso contínuo.
- Tempo de conexão VNC abaixo de 3 segundos.
- Tela `/projetor` sem uso excessivo de CPU mesmo rodando 24/7.

Detalhes e checklist: `PERFORMANCE.md`.
