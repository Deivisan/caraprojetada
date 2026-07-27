# Roadmap do CaraProjetada

> ⚠️ Arquitetura atual: **WebRTC** (screen capture via navegador).
> VNC reverso descontinuado em 2026.

## ✅ Concluído (arquitetura WebRTC)

- [x] Flask + Socket.IO + WebRTC funcional
- [x] Login institucional com mock em dev, AD/LDAP em prod
- [x] Dashboard com captura de tela via `getDisplayMedia()`
- [x] Tela do projetor `/display` com player WebRTC
- [x] Multi-sala via socket.io rooms
- [x] Sinalização WebRTC (offer, answer, ICE)
- [x] Heartbeat + cleanup de sessões órfãs
- [x] Openbox como WM padrão (sem compositor)
- [x] Kiosk Chromium apontando para `/display`
- [x] Watchdog e Guardian (scripts wm-agnósticos)
- [x] Documentação atualizada para WebRTC

## 🟡 Em andamento / Pendente

- [ ] Testar WebRTC no hardware real (rk3229)
- [ ] Medir cpu/ram/temperatura com transmissão ativa
- [ ] Validar login AD/LDAP real em produção
- [ ] Verificar compatibilidade socket.io 4.x com chromium do armbian bullseye
- [ ] Confirmar STUN/TURN para跨 rede
- [ ] Limpeza do repositório: remover artefatos VNC (`legacy/`, `windows-client/`, `depreciated/`)

## 🔮 Futuro

- [ ] Dashboard central com status de todos os projetores via API
- [ ] Descobrimento automático na rede (mDNS/Bonjour)
- [ ] Logs centralizados (syslog remoto)
- [ ] Fallback ethernet quando wifi falha
- [ ] HTTPS com certificado auto-assinado
- [ ] Rate limiting no /login
- [ ] Fail2ban para SSH

## ❌ Descontinuado (VNC reverso)

- ~~Flask app com autenticação AD + VNC reverso~~
- ~~Cliente Windows (TightVNC/UltraVNC)~~
- ~~Cliente Linux (TigerVNC)~~
- ~~Extensão do navegador~~
- ~~Streaming RTSP (mantido como opcional independente)~~
- ~~xfwm4 → migração concluída para openbox~~