# Status Final - CaraProjetada

## ✅ **Produção na TV Box (29/05/2026)**

### Box `caraprojetada` (172.17.28.179)
| Item | Status |
|------|--------|
| Flask 3.1.3 | ✅ Rodando na porta 80 |
| Openbox WM | ✅ Ativo (sem compositor) |
| xtightvncviewer | ✅ 1.3.10 instalado |
| Chromium kiosk | ✅ Rodando (tela do projetor) |
| Perfil chromium | ✅ `/tmp/chromium-kiosk` (nunca restaura sessão) |
| Guardian/Watchdog | ✅ Scripts ativos via cron |
| Logs | ✅ Em `/home/carapreta/` (evita zram) |
| RAM | 🟢 66Mi / 962Mi |
| Temp | 🟢 65°C |

### Comando VNC Otimizado (anti-travamento)
```bash
echo "123456" | DISPLAY=:0 /usr/bin/xtightvncviewer \
  <ip>:<display> -autopass \
  -quality 6 -compresslevel 9 -encodings "tight hextile"
```

## ✅ **Cliente Linux - Completo**

### TigerVNC Server no Arch Linux
```bash
systemctl --user status tigervnc@3   # Porta 5903, senha 123456
```

**Documentação:** `docs/CLIENT_LINUX.md`

## ✅ **Cliente Windows - TightVNC**

**Instalador:** `windows-client/definitive-tightvnc.bat`
- Auto-admin, download TightVNC 2.8.87, instalação silenciosa
- Senha "123456", firewall 5900/5800, serviço automático
- Verificação completa de funcionamento

## 📁 **Estrutura do Projeto**

### app/
- `app.py` (964 linhas) — produção, sem dev/emulação

### scripts/ (na box)
- `totem_guardian.sh` — watchdog 1min
- `totem_watchdog.sh` — verificação periódica
- `totem_reset.sh` — reset emergencial
- `switch_to_openbox.sh` — migração WM

### windows-client/
- `definitive-tightvnc.bat` — instalador completo TightVNC
- `main.py` — cliente Python
- `provisioning/` — scripts de setup

### browser-extension/
- `manifest.json`, `popup/`, `background/` — extensão Chrome/Firefox

### docs/
- `CLIENT_LINUX.md`, `WINDOWS_CLIENT.md`, `BROWSER_EXTENSION.md`
- `INTEGRATION_TEST.md`, `TROUBLESHOOTING.md`

## 📊 **Status Consolidado**

| Item | Estado |
|------|--------|
| API Flask (produção) | ✅ Rodando na box |
| Tela de login UFRB/CETENS | ✅ Com logos |
| Painel de controle | ✅ Com IP, SO, sessão |
| Tela do projetor (/projetor) | ✅ Idle screen 24/7 |
| Autenticação AD/LDAP | ✅ Real (produção) |
| Conexão VNC reversa | ✅ Com otimizações |
| Watchdogs | ✅ Guardian + cron |
| Openbox WM | ✅ Ativo, sem compositor |
| Cliente Linux (TigerVNC) | ✅ Testado |
| Cliente Windows (TightVNC) | ✅ .bat pronto |
| Extensão navegador | ⏳ Pendente teste |
| Vídeo travando | ✅ Resolvido (quality 6 + compress 9 + openbox)