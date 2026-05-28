#!/bin/bash
# TOTEM GUARDIAN - Script Robusto de Prevencao de Erros
# Criado por DevSan - Versao Final
# Suporta: xfwm4 (legado) e openbox (recomendado)
# Mantem o totem (projetor) funcionando 24/7

LOG="/var/log/totem_guardian.log"
export DISPLAY=:0
export XAUTHORITY=/home/carapreta/.Xauthority

sudo touch "$LOG" 2>/dev/null
sudo chmod 666 "$LOG" 2>/dev/null

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [GUARDIAN] $1" | tee -a "$LOG"
}

log "========================================="
log "Iniciando verificacao de saude do Totem..."

# ── DETECTA WINDOW MANAGER ATIVO ──────────────────────────
detect_wm() {
    if pgrep -x "openbox" > /dev/null; then
        echo "openbox"
    elif pgrep -x "xfwm4" > /dev/null; then
        echo "xfwm4"
    else
        echo "none"
    fi
}

WM_ATIVO=$(detect_wm)
log "Window manager detectado: ${WM_ATIVO}"

# ===== 1. VERIFICACAO DE REDE (WiFi) =====
IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
if [ -z "$IP" ]; then
    log "ALERTA: Sem IP na wlan0. Tentando subir rede..."
    sudo dhclient wlan0 2>&1 | tee -a "$LOG"
    sleep 5
    IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    [ -n "$IP" ] && log "REDE RECUPERADA: IP $IP" || log "ERRO: Falha ao obter IP."
else
    log "REDE OK: IP $IP"
fi

# ===== 2. VERIFICACAO DO XORG =====
if ! pgrep -x "Xorg" > /dev/null; then
    log "ALERTA: Xorg nao esta rodando. Reiniciando LightDM..."
    sudo systemctl restart lightdm
    sleep 15
fi

# ===== 3. VERIFICACAO DO WINDOW MANAGER =====
if [ "$WM_ATIVO" = "none" ]; then
    # Tenta openbox primeiro (recomendado), depois xfwm4
    if command -v openbox &>/dev/null; then
        log "ALERTA: Nenhum WM ativo. Iniciando openbox..."
        DISPLAY=:0 openbox --replace &
        sleep 2
        WM_ATIVO="openbox"
        log "openbox iniciado."
    elif command -v xfwm4 &>/dev/null; then
        log "ALERTA: Nenhum WM ativo. Iniciando xfwm4..."
        DISPLAY=:0 xfwm4 --replace --compositor=off &
        sleep 2
        WM_ATIVO="xfwm4"
        log "xfwm4 iniciado."
    else
        log "ERRO: Nenhum window manager disponivel (openbox/xfwm4)."
    fi
elif [ "$WM_ATIVO" = "xfwm4" ]; then
    log "XFWM4 OK: Gerenciador de janelas rodando."
else
    log "OPENBOX OK: Gerenciador de janelas rodando."
fi

# ===== 4. VERIFICACAO DE PAINEIS XFCE (so para xfwm4) =====
if [ "$WM_ATIVO" = "xfwm4" ]; then
    PANELS=$(DISPLAY=:0 xfconf-query -c xfce4-panel -p /panels 2>/dev/null | grep -c "Value" || echo "0")
    if [ "$PANELS" != "0" ]; then
        log "ALERTA: Paineis XFCE detectados. Removendo..."
        DISPLAY=:0 xfconf-query -c xfce4-panel -p /panels -s 0 2>/dev/null
        killall xfce4-panel 2>/dev/null
        log "Paineis removidos."
    else
        log "PAINEIS OK: Nenhum painel XFCE ativo."
    fi
fi

# ===== 5. VERIFICACAO DE RESOLUCAO =====
RES=$(DISPLAY=:0 xrandr 2>/dev/null | grep " connected" | grep -oP '\d+x\d+' | head -1)
TARGET_RES="1920x1080"
if [ "$RES" != "$TARGET_RES" ] && [ -n "$RES" ]; then
    log "ALERTA: Resolucao $RES. Forcando ${TARGET_RES}..."
    DISPLAY=:0 xrandr --output HDMI-1 --mode ${TARGET_RES} 2>/dev/null
    sleep 1
    log "Resolucao ajustada para ${TARGET_RES}."
elif [ -z "$RES" ]; then
    log "ALERTA: Nao foi possivel detectar resolucao."
else
    log "RESOLUCAO OK: $RES"
fi

# ===== 6. VERIFICACAO DO CHROMIUM (Kiosk) =====
KIOSK_URL="https://www.uol.com.br/"
if ! pgrep -f "chromium.*kiosk" > /dev/null; then
    log "ALERTA: Chromium nao esta rodando em modo kiosk. Iniciando..."
    killall chromium 2>/dev/null
    sleep 2
    DISPLAY=:0 chromium --kiosk --start-maximized --noerrdialogs \
             --disable-infobars --incognito --hide-scrollbars \
             "${KIOSK_URL}" &
    log "Chromium iniciado."
elif ! pgrep -f "chromium.*$(echo $KIOSK_URL | sed 's|https://||;s|/.*||')" > /dev/null; then
    log "ALERTA: Chromium rodando mas URL incorreta. Reiniciando..."
    killall chromium 2>/dev/null
    sleep 2
    DISPLAY=:0 chromium --kiosk --start-maximized --noerrdialogs \
             --disable-infobars --incognito --hide-scrollbars \
             "${KIOSK_URL}" &
    log "Chromium com URL correta iniciado."
else
    log "CHROMIUM OK: Processo rodando com URL correta."
fi

# ===== 7. DESATIVAR SCREENSAVER =====
DISPLAY=:0 xset s off 2>/dev/null
DISPLAY=:0 xset -dpms 2>/dev/null
DISPLAY=:0 xset s noblank 2>/dev/null

log "Verificacao concluida. Totem saudavel (WM: ${WM_ATIVO})."
