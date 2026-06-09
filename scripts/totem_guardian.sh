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
CHROMIUM_PID=$(pgrep -f "chromium.*--kiosk" 2>/dev/null | head -1)
if [ -z "$CHROMIUM_PID" ] || [ "$(ps -p "$CHROMIUM_PID" -o rss= 2>/dev/null)" -lt 20000 ]; then
  # Mata processos fantasmas
  pkill -f "chromium.*--kiosk" 2>/dev/null; sleep 1
  log "Chromium nao encontrado ou RSS baixo. Iniciando..."
  rm -rf /tmp/chromium-kiosk
  DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0 \
  chromium --kiosk --start-maximized --noerrdialogs \
    --disable-infobars --incognito --hide-scrollbars \
    --disable-gpu --disable-gpu-compositing \
    --disable-software-rasterizer --disable-accelerated-2d-canvas \
    --disable-accelerated-video-decode --disable-features=VizDisplayCompositor \
    --process-per-site --no-crashpad --no-first-run \
    --user-data-dir=/tmp/chromium-kiosk \
    http://localhost/projetor &
  CHROME_PID=$!
  log "Chromium iniciado PID: $CHROME_PID"
  sleep 5
  # Verifica se realmente subiu
  if [ "$(ps -p "$CHROME_PID" -o rss= 2>/dev/null)" -lt 20000 ]; then
    log "ALERTA: Chromium pode nao ter iniciado corretamente (RSS baixo)"
  fi
else
  log "Chromium ja rodando (PID=$CHROMIUM_PID). OK."
fi
DISPLAY=:0 xset s off 2>/dev/null; DISPLAY=:0 xset -dpms 2>/dev/null; DISPLAY=:0 xset s noblank 2>/dev/null
log "VERIFICACAO OK"
