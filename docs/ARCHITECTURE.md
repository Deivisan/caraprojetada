# 🏗️ Arquitetura do CaraProjetada — WebRTC Multi-Sala

## Visão do Sistema

O CaraProjetada é um **sistema de projetores multi-sala** que permite a transmissão de tela via **WebRTC** com autenticação institucional (AD/LDAP).

> ⚠️ A arquitetura VNC reverso foi substituída por WebRTC em 2026. Esta documentação reflete o sistema atual.

## Arquitetura Central

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            PROJETOR (RK3229)                                 │
│                    (http://172.17.28.179 ou http://<ip-da-box>)              │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                          Flask + Socket.IO                           │   │
│  │                                                                     │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐                     │   │
│  │  │   /login    │  │ /dashboard │  │  /display  │                     │   │
│  │  │  (auth AD)  │  │ (webrtc    │  │ (chromium  │                     │   │
│  │  │             │  │  presenter)│  │  kiosk)    │                     │   │
│  │  └────────────┘  └────────────┘  └────────────┘                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                       │
│                                    │ Socket.IO + WebRTC                     │
│                                    ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        Chromium --kiosk                               │   │
│  │                        http://localhost/display                       │   │
│  │                        (HDMI → Projetor)                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Rede 172.17.x.x
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        NAVEGADOR DO PROFESSOR                                │
│                                                                             │
│  1. GET /login                         → autentica AD/LDAP                  │
│  2. GET /dashboard                     → painel, lista salas               │
│  3. getDisplayMedia()                  → captura tela                      │
│  4. RTCPeerConnection + Socket.IO      → sinalização + mídia               │
│  5. POST /logout                       → encerra sessão                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Fluxo Detalhado

### 1. Autenticação

```
Browser → GET /login
       ← HTML Login
POST /login (username, password)
       → LDAP Bind: user@intranet.ufrb.edu.br
       ← Session Cookie
       → Redirect /dashboard
```

### 2. WebRTC Sinalização

```
Dashboard (Presenter)              Display (Chromium Kiosk)
       │                                │
       │── socket.io: join(sala) ─────→│
       │←── socket.io: join(tvbox) ────│
       │←────── offer (SDP) ───────────│
       │────── answer (SDP) ──────────→│
       │←── ice-candidate (candidates) →│
       │── ice-candidate (candidates) →│
       │                                │
       │    📡 WebRTC P2P Video        │
```

### 3. Fluxo do Display

```
/display carregado no chromium
  └─ socket.io connect
      └─ join('tvbox') no servidor
      └─ aguarda offer do presenter
          └─ RTCPeerConnection criada
              └─ vídeo exibido no <video>
              └─ status "Em transmissão"
                  └─ session-ended → resetarTela()
```

## Eventos Socket.IO

| Evento | Quem emite | Quem recebe | Descrição |
|--------|-----------|-------------|-----------|
| `join` `{sala, tipo}` | Ambos | Servidor | Entra na sala/sala de sinalização |
| `offer` `{type, sdp, sala}` | Display | Dashboard | SDP offer |
| `answer` `{type, sdp, sala}` | Dashboard | Display | SDP answer |
| `ice-candidate` `{candidate, sala}` | Ambos | Ambos | ICE candidates via servidor |
| `session-start` `{sala, username, fullname}` | Dashboard | Servidor | Marca sala ocupada |
| `session-end` `{sala}` | Dashboard | Servidor | Libera sala |
| `session-active` `{sala, user, since}` | Servidor | Display | Avisa que sessão iniciou |
| `session-ended` `{sala}` | Servidor | Display | Avisa que sessão encerrou |
| `professor-desconectou` | Servidor | Display | Fallback se socket do presenter cai |
| `heartbeat` `{sala}` | Display | Servidor | Keep-alive (~15s) |

## API REST

| Rota | Método | Descrição |
|------|--------|-----------|
| `/` | GET | Redireciona conforme sessão |
| `/login` | GET/POST | Tela de login / autenticação |
| `/dashboard` | GET | Painel WebRTC presenter |
| `/display` | GET | Tela do projetor (chromium kiosk) |
| `/api/v1/status` | GET | JSON com status do sistema |

## Stack

- **Web Server**: Flask 3.x (Python 3.11)
- **Sinalização**: Flask-Socket.IO
- **Mídia**: WebRTC (RTCPeerConnection, getDisplayMedia)
- **Auth**: AD/LDAP (via ldap3), mock em dev
- **Display**: Xorg + LightDM + Openbox + Chromium kiosk
- **Hardware**: Rockchip RK3229, 1GB RAM, Armbian Bullseye

## Segurança

| Camada | Implementação |
|--------|---------------|
| Autenticação | AD/LDAP (institucional) |
| Autorização | Sessão Flask + cookie assinado |
| Rede | Firewall 172.17.0.0/16 |
| Mídia | WebRTC P2P (sem servidor intermediário) |
| Stun | Google STUN público (fallback para host candidates) |

## Deployment

### Projetor (RK322x)

```bash
# Instalar dependências
sudo apt install -y python3-flask python3-flask-socketio python3-ldap3 chromium

# Copiar app
cp -r app/* /home/carapreta/app/
sudo cp systemd/projetor.service /etc/systemd/system/
sudo systemctl enable --now projetor

# O chromium kiosk abre http://localhost/display automaticamente
```

### Navegador (Professor)

Nenhuma instalação necessária — apenas um navegador moderno (Chrome, Edge, Firefox) que suporte `getDisplayMedia()`.