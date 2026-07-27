# Pendências — CaraProjetada (WebRTC)

> ⚠️ este documento foi atualizado para refletir a arquitetura WebRTC atual.
> funcionalidades VNC reverso, cliente Windows e extensão navegador foram descontinuadas.

## 🟡 EM DESENVOLVIMENTO

### Teste WebRTC no hardware real
- [ ] Testar `/display` no chromium kiosk da box rk3229
- [ ] Medir cpu/ram/temperatura com transmissão webrtc ativa por 15 min
- [ ] Validar reconexão após queda de socket
- [ ] Confirmar que múltiplas salas funcionam via socket.io rooms
- [ ] Testar login ad/ldap real (produção)

### Melhorias na interface
- [ ] Adicionar indicador de qualidade/força de sinal no dashboard
- [ ] Feedback visual mais claro quando a transmissão está "conectando"
- [ ] Timer de sessão no /display

### Documentação
- [ ] Atualizar `docs/SISTEMA_DE_PROJECOES.md` para webrtc (✅ pendente verificação)
- [ ] Remover referências a VNC nas docs de arquitetura
- [ ] Consolidar `docs/` com apenas documentação webrtc

### Limpeza do repositório
- [ ] Arquivar `legacy/webrtc-v2/` (versão anterior quase idêntica)
- [ ] Remover `windows-client/` (substituído por webrtc no navegador)
- [ ] Remover `monitoring/` se não for mais usado
- [ ] Remover `depreciated/`

### Infraestrutura
- [ ] Verificar se `flask-socketio` precisa de `eventlet` ou `gevent` no rk3229
- [ ] Confirmar compatibilidade do socket.io 4.x com chromium do armbian bullseye
- [ ] Testar sem stun server (só ice host candidates na mesma rede)

## ✅ CONCLUÍDAS (nova arquitetura)

| Item | Status |
|------|--------|
| Flask + Socket.IO + WebRTC | ✅ Funcional em modo dev |
| Tela de login UFRB/CETENS | ✅ Com logo, passos, formulário |
| Painel de controle com salas | ✅ Grid de salas, webrtc presenter |
| Tela do projetor (/display) | ✅ Player webrtc + status ocioso/ativo |
| Autenticação mock em dev | ✅ admin/admin, user=senha |
| Autenticação AD/LDAP | ✅ Real (produção) |
| Multi-sala via socket.io rooms | ✅ Cada box tem sua sala |
| Heartbeat do display | ✅ Limpa sessões órfãs |
| Thread de limpeza | ✅ Remove heartbeats antigos a cada 15s |
| Scripts de watchdog | ✅ Guardian + cron (wm-agnósticos) |
| Openbox WM | ✅ Ativo, sem compositor |

## ❌ DESCONTINUADO (VNC reverso)

| Funcionalidade | Motivo |
|---------------|--------|
| VNC reverso (xtightvncviewer) | Substituído por WebRTC (screen capture no navegador) |
| Cliente Windows (UltraVNC/TightVNC) | Não é mais necessário — tudo via navegador |
| Extensão do navegador | Não é mais necessária — screen capture integrado ao dashboard |
| `/conectar` e `/desconectar` (VNC) | Substituído por webrtc session-start/session-end |
| `/vnc-view` (emulação dev) | Substituído pelo player webrtc no `/display` |
| `/api/dev/reset` | Não faz mais sentido (não há sessão "presa" de VNC) |
| Senha VNC "123456" fixa | Não se aplica — autenticação via AD/LDAP |

## 📋 Arquitetura Atual

```
Navegador (Professor)                    Projetor (RK3229)
       │                                      │
       ├── login (AD/LDAP) ─────────────────→│
       │                                      │
       ├── dashboard ───────────────────────→│ /display (chromium kiosk)
       │    │                                 │
       │    └── getDisplayMedia()            │
       │         └── RTCPeerConnection ─────→│ RTCPeerConnection
       │              ├── offer/answer        │
       │              └── ICE candidates      │
       │                                      │
       │    📡 vídeo via WebRTC (P2P) ──────→│ video.play()
       │                                      │
       └── session-end ────────────────────→│ resetarTela()
```

## Comandos de Teste

```bash
# Dev local
cd app
CARAPROJETADA_ENV=dev flask --app app:app run --host 127.0.0.1 --port 5000

# Verificar sintaxe
python3 -m py_compile app/app.py

# Status
curl -s http://127.0.0.1:5000/api/v1/status | python3 -m json.tool
```