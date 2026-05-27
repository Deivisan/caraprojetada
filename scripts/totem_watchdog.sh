#!/bin/bash
# TOTEM WATCHDOG - Verificacao Periodica do Totem
# Criado por DevSan para o Totem (carapreta@172.17.28.179)
# Executado via cron

LOG="/home/carapreta/watchdog.log"
export DISPLAY=:0
export XAUTHORITY=/home/carapreta/.Xauthority

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG"
}

log "========================================="
log "Iniciando verificacao do Totem..."

# 1. VERIFICAR REDE
IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
if [ -z "$IP" ]; then
    log "ERRO: Sem IP na wlan0. Tentando subir rede..."
    sudo dhclient wlan0 2>&1 | tee -a "$LOG"
    sleep 5
else
    log "REDE OK: IP $IP"
fi

# 2. VERIFICAR LIGHTDM
if ! pgrep -x "lightdm" > /dev/null; then
    log "ALERTA: LightDM nao esta rodando. Tentando iniciar..."
    sudo systemctl start lightdm 2>&1 | tee -a "$LOG"
    sleep 10
fi

# 3. VERIFICAR XFWM4 / XFCE SESSION
if ! pgrep -x "xfwm4" > /dev/null; then
    log "ALERTA: xfwm4 (Window Manager) nao encontrado. Tentando iniciar XFCE..."
    if ! pgrep -x "xfce4-session" > /dev/null; then
        DISPLAY=:0 xfce4-session &
        sleep 5
    fi
    DISPLAY=:0 xfce4-wm --replace &
    sleep 2
    log "XFCE/Window Manager reiniciado."
fi

# 4. VERIFICAR CHROMIUM
if ! pgrep -f "chromium.*kiosk" > /dev/null; then
    log "ALERTA: Chromium nao esta rodando. Iniciando Kiosk..."
    killall chromium 2>/dev/null
    sleep 1
    DISPLAY=:0 chromium --kiosk --start-maximized --noerrdialogs \
             --disable-infobars --incognito https://ufrb.edu.br/portal/ &
    log "Chromium iniciado."
else
    log "CHROMIUM OK: Processo rodando."
fi

# 5. VERIFICAR RESOLUCAO
RES=$(DISPLAY=:0 xrandr 2>/dev/null | grep " connected" | grep -oP '\d+x\d+')
if [ -z "$RES" ]; then
    log "ALERTA: Nao foi possivel detectar resolucao via xrandr."
else
    log "RESOLUCAO OK: $RES"
fi

log "Verificacao concluida."
