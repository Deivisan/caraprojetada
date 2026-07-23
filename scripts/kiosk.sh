#!/bin/bash
# Kiosk mode - Chromium em tela cheia no projetor
# Uso: ./kiosk.sh [url]
# Default: https://www.uol.com.br

URL="${1:-https://www.uol.com.br}"
export DISPLAY=:0
export XAUTHORITY=~/.Xauthority

# Desabilitar screensaver
xset s off
xset -dpms
xset s noblank

echo "Iniciando Kiosk - ${URL}..."

while true; do
    if pgrep -f "chromium.*$(echo $URL | sed 's|https://||;s|/.*||')" > /dev/null; then
        echo "Chromium ja esta rodando com a URL certa. Monitorando..."
        sleep 30
        continue
    fi

    echo "Iniciando/Reiniciando Chromium para ${URL}..."
    killall chromium 2>/dev/null
    sleep 2

    chromium --kiosk --start-maximized --noerrdialogs \
             --disable-infobars --incognito \
             --autoplay-policy=no-user-gesture-required \
             --disable-features=TranslateUI \
             --no-first-run "${URL}" &

    wait $!
    echo "Chromium encerrou. Reiniciando em 5s..."
    sleep 5
done
