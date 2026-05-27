#!/bin/bash
# TOTEM GUARDIAN - Script Robusto de Prevencao de Erros
# Criado por DevSan - Versao Final
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

# ===== 3. VERIFICACAO DO WINDOW MANAGER (xfwm4) =====
if ! pgrep -x "xfwm4" > /dev/null; then
    log "ALERTA: xfwm4 (Window Manager) nao encontrado. Instalando/Iniciando..."
    if ! command -v xfwm4 &> /dev/null; then
        log "Instalando xfwm4..."
        sudo apt install -y xfwm4 2>&1 | tee -a "$LOG"
    fi
    DISPLAY=:0 xfwm4 --replace --compositor=off &
    sleep 2
    log "xfwm4 forcado a subir."
else
    log "XFWM4 OK: Gerenciador de janelas rodando."
fi

# ===== 4. VERIFICACAO DE PAINEIS XFCE =====
PANELS=$(DISPLAY=:0 xfconf-query -c xfce4-panel -p /panels 2>/dev/null | grep -c "Value" || echo "0")
if [ "$PANELS" != "0" ]; then
    log "ALERTA: Paineis XFCE detectados. Removendo..."
    DISPLAY=:0 xfconf-query -c xfce4-panel -p /panels -s 0 2>/dev/null
    killall xfce4-panel 2>/dev/null
    log "Paineis removidos."
else
    log "PAINEIS OK: Nenhum painel XFCE ativo."
fi

# ===== 5. VERIFICACAO DE RESOLUCAO =====
RES=$(DISPLAY=:0 xrandr 2>/dev/null | grep " connected" | grep -oP '\d+x\d+' | head -1)
if [ "$RES" != "1920x1080" ]; then
    log "ALERTA: Resolucao incorreta ($RES). Forcando 1920x1080..."
    DISPLAY=:0 xrandr --output HDMI-1 --mode 1920x1080 2>/dev/null
    sleep 1
    log "Resolucao ajustada."
else
    log "RESOLUCAO OK: $RES"
fi

# ===== 6. VERIFICACAO DO CHROMIUM (Kiosk) =====
if ! pgrep -f "chromium.*kiosk" > /dev/null; then
    log "ALERTA: Chromium nao esta rodando em modo kiosk. Iniciando..."
    killall chromium 2>/dev/null
    sleep 2
    DISPLAY=:0 chromium --kiosk --start-maximized --noerrdialogs \
             --disable-infobars --incognito --hide-scrollbars \
             https://www.uol.com.br/ &
    log "Chromium iniciado."
elif ! pgrep -f "chromium.*uol.com.br" > /dev/null; then
    log "ALERTA: Chromium rodando mas URL incorreta. Reiniciando..."
    killall chromium 2>/dev/null
    sleep 2
    DISPLAY=:0 chromium --kiosk --start-maximized --noerrdialogs \
             --disable-infobars --incognito --hide-scrollbars \
             https://www.uol.com.br/ &
    log "Chromium com URL correta iniciado."
else
    log "CHROMIUM OK: Processo rodando com URL correta."
fi

# ===== 7. DESATIVAR SCREENSAVER =====
DISPLAY=:0 xset s off 2>/dev/null
DISPLAY=:0 xset -dpms 2>/dev/null
DISPLAY=:0 xset s noblank 2>/dev/null

log "Verificacao concluida. Totem saudavel."
