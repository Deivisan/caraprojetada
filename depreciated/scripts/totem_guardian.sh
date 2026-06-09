#!/bin/bash
LOG="/home/carapreta/totem_guardian.log"
export DISPLAY=:0
export XAUTHORITY=/var/run/lightdm/root/:0
sudo touch "$LOG" 2>/dev/null; sudo chmod 666 "$LOG" 2>/dev/null
log() { echo "$(date "+%Y-%m-%d %H:%M:%S") [GUARDIAN] $1" | tee -a "$LOG"; }
log "=== INICIANDO VERIFICACAO ==="
IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP "(?<=inet\s)\d+(\.\d+){3}" | head -1)
if [ -z "$IP" ]; then log "ALERTA: Sem IP."; sudo dhclient wlan0; sleep 5; else log "REDE OK: $IP"; fi
pgrep -x "Xorg" > /dev/null || { log "Xorg morto"; sudo systemctl restart lightdm; sleep 15; }
if ! pgrep -x "openbox" > /dev/null; then
  if command -v openbox &>/dev/null; then log "Subindo openbox..."; DISPLAY=:0 openbox --replace & sleep 2
  elif command -v xfwm4 &>/dev/null; then log "Subindo xfwm4..."; DISPLAY=:0 xfwm4 --replace --compositor=off & sleep 2; fi
fi
# So inicia chromium se nao estiver rodando (NUNCA mata)
if ! pgrep -f "chromium.*--kiosk" > /dev/null; then
  log "Chromium nao encontrado. Iniciando..."
  rm -rf /tmp/chromium-kiosk
  DISPLAY=:0 chromium --kiosk --start-maximized --noerrdialogs \
    --disable-infobars --incognito --hide-scrollbars \
    --user-data-dir=/tmp/chromium-kiosk --no-first-run \
    http://localhost/projetor &
  log "Chromium iniciado PID: $!"
else
  log "Chromium ja rodando. OK."
fi
DISPLAY=:0 xset s off 2>/dev/null; DISPLAY=:0 xset -dpms 2>/dev/null; DISPLAY=:0 xset s noblank 2>/dev/null
log "VERIFICACAO OK"
