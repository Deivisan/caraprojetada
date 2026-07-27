# sistema de projeções — caraprojetada

> documento autoritativo da arquitetura atual.  
> **caraazul descontinuado. VNC reverso descontinuado. Arquitetura: WebRTC.**

## 1. visão executiva

o `caraprojetada` transforma uma tv box rockchip rk3229 em um ponto de projeção institucional: a box fica ligada ao projetor via hdmi, exibe uma tela de instruções 24/7 e permite que usuários da rede institucional transmitam a tela do navegador via **webrtc**, autenticando via ad/ldap.

o modelo atual é **descentralizado por box**: cada projetor possui sua própria interface flask na porta 80, seu próprio chromium em kiosk no hdmi e seu próprio guardian local. a sinalização webrtc é feita via socket.io.

```text
navegador do professor
  └─ acessa http://<ip-da-box>
      └─ login (ad/ldap)
          └─ dashboard → "compartilhar tela"
              └─ getDisplayMedia() + RTCPeerConnection
                  └─ socket.io: offer/answer/ice
                      └─ chromium kiosk: /display
                          └─ hdmi → projetor
```

## 2. status do projeto

| item | estado |
|------|--------|
| projeto vivo | ✅ `caraprojetada` |
| projeto descontinuado | ❌ `caraazul` |
| box real em teste | ✅ `caraprojetada` / `carapreta-box` |
| ip atual da box | `172.17.28.179` |
| modo padrão | produção |
| branch de trabalho | `dev` |
| branch estável | `main` |
| arquitetura de mídia | webrtc (não vnc) |

## 3. hardware alvo

| componente | valor |
|---|---|
| soc | rockchip rk3229/rk322x |
| arquitetura | armv7 32-bit / armhf |
| ram | ~1 gb |
| armazenamento | emmc ~8 gb |
| os | armbian bullseye |
| kernel | 4.4 legacy rk322x |
| vídeo | hdmi |
| display stack | lightdm + xorg + openbox + chromium kiosk |

## 4. componentes em produção

| componente | função |
|---|---|
| `projetor.service` | serviço systemd que sobe o flask na porta 80 |
| `app/app.py` | aplicação flask principal + socket.io + webrtc (~535 linhas) |
| `/display` | tela do projetor exibida no hdmi pelo chromium kiosk |
| `/api/v1/status` | status json |
| `/dashboard` | painel do professor com captura de tela webrtc |
| `app/templates/display.html` | template do player webrtc com fallback ocioso |
| socket.io | sinalização webrtc (offer, answer, ice candidates) |
| lightdm | gerenciador gráfico com auto-login |
| openbox | window manager leve sem compositor |
| chromium kiosk | navegador fullscreen apontado para `/display` |
| cron | agenda guardian e watchdog |
| `totem_guardian.sh` | garante xorg/openbox/chromium |
| `totem_watchdog.sh` | verificação periódica leve |

## 5. fluxo operacional

### 5.1 boot da box

```text
energia ligada
  └─ systemd → graphical.target
      ├─ lightdm active
      │   └─ auto-login usuário carapreta
      │       └─ openbox
      ├─ projetor.service → flask :80 (com socket.io)
      └─ cron
          └─ totem_guardian.sh
              └─ chromium --kiosk http://localhost/display
```

### 5.2 tela hdmi em repouso

a tela `/display` exibe:
- logo ufrb (svg inline, viewBox 600x140)
- status "disponível" com dot verde pulsante
- relógio no canto superior direito
- footer "ufrb · universidade federal do recôncavo da bahia"
- gradiente azul-escuro de fundo (sem animações pesadas)

### 5.3 transmissão ativa

1. professor acessa `http://<ip-da-box>` no navegador
2. faz login com credenciais institucionais (ad/ldap)
3. dashboard lista salas disponíveis
4. clica "compartilhar tela"
5. navegador solicita permissão de captura de tela via `getDisplayMedia()`
6. sinalização webrtc via socket.io:
   - display (chromium) envia sdp offer
   - dashboard (navegador) responde com sdp answer
   - ice candidates trocados via servidor
7. vídeo em tempo real aparece na tela do projetor
8. botão "parar compartilhamento" encerra a transmissão

### 5.4 fallback de desconexão

se o socket do professor cair (perdeu rede, fechou navegador), o servidor detecta via `disconnect` e:
1. remove a sessão ativa
2. emite `session-ended` + `professor-desconectou` para a sala
3. o display reseta a tela (volta ao estado ocioso)

## 6. implementação técnica

### app.py — estrutura

```
app.py (~535 linhas)
├── configuração (ambiente, ad, logging)
├── app factory + socket.io
├── estado global: active_sessions, last_offer, heartbeats
├── funções auxiliares: get_ip(), registrar_log(), autenticar_ad(), get_salas()
├── rotas web: /, /login, /dashboard, /display
├── eventos socket.io: join, offer, answer, ice-candidate, session-start/end, heartbeat, disconnect
└── thread de limpeza: _cleanup_loop()
```

### configuração por ambiente

```python
DEV_MODE = os.environ.get('CARAPROJETADA_ENV', 'prod') == 'dev'
HOST = '127.0.0.1' if DEV_MODE else '0.0.0.0'
PORT = int(os.environ.get('PORT', 5000 if DEV_MODE else 80))
```

### templates

- `login.html`: formulário com logo ufrb, passos, brand, info do sistema, partículas animadas
- `dashboard.html`: app bar, grid de salas, botões compartilhar/parar, socket.io + webrtc js
- `display.html`: player webrtc, overlay de status, relógio, fundo gradiente

## 7. segurança

- ✅ Autenticação ad/ldap
- ✅ Sessões flask com cookie assinado
- ✅ WebRTC (sem expor senha vnc)
- ⚠️ http (sem https)
- ❌ sem rate limiting no login

## 8. desempenho

metas para o rk3229:
- cpu idle flask: `< 5%`
- memória sem stream: `< 120 mb`
- memória com webrtc: `< 180 mb`
- temperatura: `< 75°c`
- conexão webrtc: `< 5s`

ver checklist detalhada em `PERFORMANCE.md`.

## 9. observabilidade

- logs em `/tmp/caraprojetada-{user}.log`
- `GET /api/v1/status` → json com status da sessão
- monitoring legado (descontinuado, aguardando remoção)

## 10. histórico de migração

- **2025**: arquitetura vnc reverso (xtightvncviewer)
  - `/conectar`, `/desconectar`, `/projetor`, `/vnc-view`
  - templates inline no app.py
  - cliente windows (ultravnc/tightvnc)
  - extensão de navegador
- **2026**: migração para webrtc
  - `/dashboard` + `/display` com socket.io
  - screen capture via `getDisplayMedia()`
  - templates em arquivos separados
  - todas as funcionalidades vnc removidas