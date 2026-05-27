# Roadmap do CaraProjetada

## Fase 1 — Baseline (CONCLUIDA) ✅
- [x] Flask app com autenticacao AD
- [x] Conexao VNC reversa
- [x] Kiosk Chromium
- [x] Watchdog e Guardian
- [x] Streaming RTSP
- [x] Servicos systemd

## Fase 2 — Estabilizacao
- [ ] Migrar para kernel 6.6+ (via CaraAzul)
- [ ] Substituir xfwm4 por window manager mais leve (openbox?)
- [ ] Adicionar fallback ethernet quando wifi falha
- [ ] Logs centralizados (syslog remoto)
- [ ] Script de backup automatico das configuracoes

## Fase 3 — Multi-projetor
- [ ] Dashboard central com status de todos os projetores
- [ ] Descobrimento automatico na rede (mDNS/Bonjour)
- [ ] Configuracao remota via API
- [ ] Agendamento de horarios (ligar/desligar)
- [ ] Monitoramento de temperatura do SoC

## Fase 4 — Seguranca e Robustez
- [ ] HTTPS com certificado auto-assinado
- [ ] Rate limiting no login
- [ ] Logs de auditoria de acesso
- [ ] Fail2ban para protecao SSH
- [ ] Atualizacao OTA via git pull

## Fase 5 — Features Avancadas
- [ ] Suporte a multiple usuarios simultaneos
- [ ] Streaming de audio via VNC
- [ ] Modo apresentacao (slides + anotacoes)
- [ ] Compatibilidade com Miracast/AirPlay
- [ ] App mobile para controle
