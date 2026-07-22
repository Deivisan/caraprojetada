#!/bin/bash
# caraprojetada — Startup Script (WebRTC)
# Inicia o servidor Flask-SocketIO e o Chromium Kiosk
# Projetado para rodar como root (systemd) ou user carapreta (dev)

export DISPLAY=:0
export XAUTHORITY="${XAUTHORITY:-/root/.Xauthority}"
export CARAPROJETADA_ENV="${CARAPROJETADA_ENV:-prod}"

# Configurações da sala (customize por box)
export SALA_ID="${SALA_ID:-sala-101}"
export SALA_NOME="${SALA_NOME:-Sala 101}"
export PORT="${PORT:-5000}"

# Path base
APP_DIR="/home/carapreta/projeto-webrtc"

echo "====== 🚀 caraprojetada WebRTC ======"
echo "Sala: $SALA_ID ($SALA_NOME)"
echo "Porta: $PORT"
echo "Modo: $CARAPROJETADA_ENV"
echo ""

cd "$APP_DIR"

# [1/3] Inicia servidor Flask-SocketIO
echo "====== [1/3] Iniciando Servidor Web ======"

# Mata qualquer flask anterior
pkill -f "python3 app.py" 2>/dev/null
sleep 1

# Garante que o log está acessível
rm -f /tmp/flask-webrtc.log 2>/dev/null

python3 app.py > /tmp/flask-webrtc.log 2>&1 &
FLASK_PID=$!
sleep 3

# Verifica se subiu (verifica a porta)
if ! ss -tlnp | grep -q ":${PORT}"; then
    echo "❌ ERRO: Flask não subiu na porta ${PORT}. Log:"
    tail -5 /tmp/flask-webrtc.log
    cat /tmp/caraprojetada-*.log 2>/dev/null | tail -5
    exit 1
fi
echo "✅ Servidor rodando na porta ${PORT} (PID: $FLASK_PID)"

# [2/3] Inicia ocultador de mouse
echo "====== [2/3] Ocultando cursor ======"
unclutter -idle 0 -root 2>/dev/null &

# [3/3] Inicia Chromium Kiosk (SEM --single-process, estável no ARM)
echo "====== [3/3] Iniciando Chromium Kiosk ======"
echo "URL: http://localhost:${PORT}/display"

# Mata chromium anterior se existir
pkill -9 -f "chromium.*kiosk" 2>/dev/null
sleep 1

# Se Xorg não estiver rodando, usa xinit; senão, usa o display existente
if pgrep -x Xorg > /dev/null; then
    # X já rodando, só inicia chromium
    /usr/bin/chromium \
      --kiosk \
      --no-sandbox \
      --no-first-run \
      --start-maximized \
      --window-size=1280,720 \
      --window-position=0,0 \
      --autoplay-policy=no-user-gesture-required \
      --check-for-update-interval=31536000 \
      --disable-infobars \
      --renderer-process-limit=2 \
      --disable-extensions \
      --disable-component-extensions-with-background-pages \
      --disable-default-apps \
      --no-default-browser-check \
      --disable-sync \
      --disable-translate \
      --disable-save-password-bubble \
      --disk-cache-dir=/tmp/chromium-cache \
      --disk-cache-size=1 \
      --media-cache-size=1 \
      --disable-software-rasterizer \
      http://localhost:${PORT}/display &
    CHROME_PID=$!
    echo "✅ Chromium lançado no display existente (PID: $CHROME_PID)"
    # Aguarda o chromium fechar
    wait $CHROME_PID 2>/dev/null
else
    # X não está rodando, usa xinit (inicia X + chromium)
    echo "Xorg não detectado. Iniciando com xinit..."
    # Limpa locks anteriores
    rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null
    
    # Cria .xinitrc temporário para iniciar chromium
    cat > /tmp/xinitrc-webrtc << XINITRC
#!/bin/sh
# xinitrc para caraprojetada WebRTC
exec /usr/bin/chromium \
  --kiosk \
  --no-sandbox \
  --no-first-run \
  --start-maximized \
  --window-size=1280,720 \
  --window-position=0,0 \
  --autoplay-policy=no-user-gesture-required \
  --check-for-update-interval=31536000 \
  --disable-infobars \
  --renderer-process-limit=2 \
  --disable-extensions \
  --disable-component-extensions-with-background-pages \
  --disable-default-apps \
  --no-default-browser-check \
  --disable-sync \
  --disable-translate \
  --disable-save-password-bubble \
  --disk-cache-dir=/tmp/chromium-cache \
  --disk-cache-size=1 \
  --media-cache-size=1 \
  http://localhost:${PORT}/display
XINITRC
    chmod +x /tmp/xinitrc-webrtc
    
    echo "Rodando: xinit /tmp/xinitrc-webrtc -- :0 vt1 -keeptty"
    xinit /tmp/xinitrc-webrtc -- :0 vt1 -keeptty > /tmp/xinit.log 2>&1
    XINIT_EXIT=$?
    echo "xinit exit code: $XINIT_EXIT"
    tail -20 /tmp/xinit.log
fi

# Se chegou aqui, chromium fechou/crashou
echo "⚠️ Chromium encerrou. Parando servidor Flask..."
kill $FLASK_PID 2>/dev/null

# systemd restartará o serviço com Restart=always
exit 0
