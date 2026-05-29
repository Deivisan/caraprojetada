#!/bin/bash
LOG="/home/carapreta/watchdog.log"
export DISPLAY=:0
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG"; }
log "=== WATCHDOG ==="
IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
[ -z "$IP" ] && log "ALERTA: Sem IP." || log "REDE: $IP"
pgrep -x "openbox" > /dev/null && log "OPENBOX OK" || log "OPENBOX OFFLINE"
log "VERIFICACAO OK"
