#!/bin/bash
# CaraProjetada Kiosk — tela do projetor, sem window manager
xset s off
xset -dpms
xset s noblank
unclutter -idle 0 -root &
# Aguarda Flask ficar pronto (até 60s)
for i in $(seq 1 30); do
  if curl -sf http://localhost:5000/api/health > /dev/null 2>&1; then
    break
  fi
  sleep 2
done
exec chromium --kiosk --no-sandbox --start-maximized --noerrdialogs \
  --disable-infobars --incognito --hide-scrollbars \
  --disable-gpu --disable-gpu-compositing --disable-software-rasterizer \
  --disable-accelerated-2d-canvas --disable-accelerated-video-decode \
  --autoplay-policy=no-user-gesture-required --process-per-site \
  --no-crashpad --no-first-run --user-data-dir=/tmp/chromium-kiosk \
  http://localhost:5000/display
