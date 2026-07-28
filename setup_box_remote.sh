#!/bin/bash
# Setup remoto da box — TODOS os arquivos inline (sem dependencia externa)
set -euo pipefail

HOST="carapreta@172.17.11.101"
PASS="carapreta123"

echo "=== Copiando arquivos para $HOST ==="

# Cria temp dir local
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# ====== GUARDIAN SCRIPT ======
cat > "$TMPDIR/totem_guardian.sh" << 'GUARD'
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
GUARD

# ====== KIOSK SCRIPT ======
cat > "$TMPDIR/iniciar_kiosk.sh" << 'KIO'
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
KIO

# ====== DESKTOP SESSION ======
cat > "$TMPDIR/caraprojetada.desktop" << 'DESK'
[Desktop Entry]
Name=CaraProjetada Kiosk
Comment=Only Chromium kiosk for projector
Exec=/home/carapreta/iniciar_kiosk.sh
Type=Application
DESK

# ====== LIGHTDM CONF ======
cat > "$TMPDIR/01-caraprojetada.conf" << 'LDM'
[Seat:*]
autologin-user=carapreta
autologin-user-timeout=0
autologin-session=caraprojetada
user-session=caraprojetada
LDM

# ====== XORG DPMS CONF ======
cat > "$TMPDIR/10-disable-dpms.conf" << 'XORG'
Section "Extensions"
    Option "DPMS" "Disable"
EndSection
Section "ServerFlags"
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
EndSection
XORG

# ====== SCP ======
scp -q "$TMPDIR"/totem_guardian.sh \
      "$TMPDIR"/iniciar_kiosk.sh \
      "$TMPDIR"/caraprojetada.desktop \
      "$TMPDIR"/01-caraprojetada.conf \
      "$TMPDIR"/10-disable-dpms.conf \
      "$HOST":/tmp/
echo "scp OK"

# ====== COMANDOS REMOTOS VIA EXPECT ======
expect << REMOTE_EXPECT
set timeout 60
set pass "$PASS"
spawn ssh -tt $HOST
expect "Last login:" { sleep 1 }
expect "$ " { sleep 0.3 }

send "echo \$pass | sudo -S cp /tmp/caraprojetada.desktop /usr/share/xsessions/caraprojetada.desktop && echo DSK\r"
expect "DSK" { sleep 0.3 }

send "echo \$pass | sudo -S cp /tmp/01-caraprojetada.conf /etc/lightdm/lightdm.conf.d/01-caraprojetada.conf && echo LDM\r"
expect "LDM" { sleep 0.3 }

send "echo \$pass | sudo -S cp /tmp/10-disable-dpms.conf /etc/X11/xorg.conf.d/10-disable-dpms.conf && echo X11\r"
expect "X11" { sleep 0.3 }

send "echo \$pass | sudo -S chmod 644 /usr/share/xsessions/caraprojetada.desktop && echo PERM\r"
expect "PERM" { sleep 0.3 }

send "cp /tmp/iniciar_kiosk.sh /home/carapreta/iniciar_kiosk.sh && chmod +x /home/carapreta/iniciar_kiosk.sh && echo KIO\r"
expect "KIO" { sleep 0.3 }

send "cp /tmp/totem_guardian.sh /home/carapreta/totem_guardian.sh && chmod +x /home/carapreta/totem_guardian.sh && echo GRD\r"
expect "GRD" { sleep 0.3 }

send "rm -f /home/carapreta/.config/openbox/lxde-rc.xml /home/carapreta/.config/openbox/autostart && echo RM\r"
expect "RM" { sleep 0.3 }

send "echo \$pass | sudo -S bash -c 'echo \"carapreta ALL=(ALL) NOPASSWD: /usr/sbin/lightdm, /usr/bin/systemctl, /usr/bin/touch, /bin/chmod\" > /etc/sudoers.d/carapreta-kiosk && chmod 440 /etc/sudoers.d/carapreta-kiosk' && echo SUDO\r"
expect "SUDO" { sleep 0.3 }

send "echo \$pass | sudo -S systemctl restart lightdm\r"
expect "$ " { sleep 15 }

send "echo '=== VERIFICACAO ==='; systemctl is-active lightdm; echo 'X:'; pgrep -x Xorg || echo 'OFF'; echo 'FLASK:'; systemctl is-active projetor; echo 'DPMS:'; DISPLAY=:0 xset q 2>/dev/null | grep -E 'DPMS|Monitor|Safer'; echo 'DONE'\r"
expect "$ " { sleep 2 }
send "exit\r"
expect "$ " { puts "FIM" }
close
REMOTE_EXPECT

echo "=== CONCLUIDO ==="
