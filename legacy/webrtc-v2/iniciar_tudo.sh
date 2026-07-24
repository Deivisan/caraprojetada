#!/bin/bash
export DISPLAY=:0
export XAUTHORITY=/root/.Xauthority

cd /home/carapreta/projeto-webrtc/

echo "====== [0/2] Desabilitando DPMS e screensaver ======"
xset -display :0 s off
xset -display :0 -dpms
xset -display :0 s noblank
xset -display :0 dpms force on

echo "====== [1/2] Iniciando o Servidor Web ======"
python3 app.py > /dev/null 2>&1 &
FLASK_PID=$!

sleep 3

# Inicializa o ocultador de mouse no Display :0
unclutter -idle 0 -root &

echo "====== [2/2] Iniciando o Chromium Kiosk ======"
# Força o tamanho da janela de forma nativa pelas flags do navegador

xinit /usr/bin/chromium \
  --kiosk \
  --no-sandbox \
  --no-first-run \
  --start-maximized \
  --window-size=1440,900 \
  --window-position=0,0 \
  --autoplay-policy=no-user-gesture-required \
  --check-for-update-interval=31536000 \
  --disable-infobars \
  --single-process \
  --renderer-process-limit=1 \
  --disable-extensions \
  --disable-component-extensions-with-background-pages \
  --disable-default-apps \
  --no-default-browser-check \
  --disk-cache-dir=/tmp/chromium-cache \
  --disk-cache-size=1 \
  --media-cache-size=1 \
  http://localhost:5000/display \
  -- :0

#xinit /usr/bin/firefox --kiosk http://localhost:5000/display -- :0

echo "Fechando o servidor Flask..."
if [ -n "$FLASK_PID" ]; then
    kill $FLASK_PID 2>/dev/null
fi
