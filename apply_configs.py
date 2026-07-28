#!/usr/bin/python3
import subprocess, os, textwrap, tempfile

SCRIPT = "./apply_configs.py"
with open(SCRIPT, "w") as f:
    f.write(textwrap.dedent("""
import os, subprocess, sys

HOST = "carapreta@172.17.11.101"
PASS = "carapreta123"

KIOSK = """ + repr(textwrap.dedent("""\
#!/bin/bash
xset s off
xset -dpms
xset s noblank
unclutter -idle 0 -root &
for i in $(seq 1 30); do
  if curl -sf http://localhost:5000/api/health > /dev/null 2>&1; then break; fi
  sleep 2
done
exec chromium --kiosk --no-sandbox --start-maximized --noerrdialogs --disable-infobars --incognito --hide-scrollbars --disable-gpu --disable-gpu-compositing --disable-software-rasterizer --disable-accelerated-2d-canvas --disable-accelerated-video-decode --autoplay-policy=no-user-gesture-required --process-per-site --no-crashpad --no-first-run --user-data-dir=/tmp/chromium-kiosk http://localhost:5000/display
""")) + """

DESKTOP = """ + repr(textwrap.dedent("""\
[Desktop Entry]
Name=CaraProjetada Kiosk
Comment=Only Chromium kiosk for projector
Exec=/home/carapreta/iniciar_kiosk.sh
Type=Application
""")) + """

LIGHTDM = """ + repr(textwrap.dedent("""\
[Seat:*]
autologin-user=carapreta
autologin-user-timeout=0
autologin-session=caraprojetada
user-session=caraprojetada
""")) + """

GUARD = """ + repr(textwrap.dedent("""\
#!/bin/bash
LOG="/home/carapreta/totem_guardian.log"
export DISPLAY=:0
sudo touch "$LOG" 2>/dev/null; sudo chmod 666 "$LOG" 2>/dev/null
log() { echo "$(date "+%Y-%m-%d %H:%M:%S") [GUARDIAN] $1" | tee -a "$LOG"; }
log "=== INICIANDO VERIFICACAO ==="
if ! pgrep -x Xorg > /dev/null; then
  log "Xorg morto! Tentando restart..."
  sudo systemctl restart lightdm 2>/dev/null
  sleep 15
fi
CHROMIUM_PID=$(pgrep -f "chromium.*kiosk.*display" 2>/dev/null | head -1)
if [ -z "$CHROMIUM_PID" ]; then
  log "Chromium nao encontrado. Iniciando..."
  rm -rf /tmp/chromium-kiosk
  export DISPLAY=:0
  /home/carapreta/iniciar_kiosk.sh &
  sleep 8
  CHROMIUM_PID=$(pgrep -f "chromium.*kiosk.*display" 2>/dev/null | head -1)
  if [ -n "$CHROMIUM_PID" ]; then log "Chromium iniciado PID: $CHROMIUM_PID"; else log "FALHA: Chromium nao subiu"; fi
else
  log "Chromium ja rodando (PID=$CHROMIUM_PID). OK."
fi
log "VERIFICACAO OK"
""")) + """

XORG = """ + repr(textwrap.dedent("""\
Section "Extensions"
    Option "DPMS" "Disable"
EndSection

Section "ServerFlags"
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
EndSection
""")) + """\n"""

with open("/tmp/setup_box.py", "w") as f:
    f.write(GUARD)

print("escrito")
"""))
print("script gerado")
