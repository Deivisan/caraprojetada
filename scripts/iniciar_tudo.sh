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

# ───────────────────────────────────────────────
# [1/3] Inicia servidor Flask-SocketIO
# ───────────────────────────────────────────────
echo "====== [1/3] Iniciando Servidor Web ======"

pkill -f "python3 app.py" 2>/dev/null
sleep 1
rm -f /tmp/flask-webrtc.log 2>/dev/null

python3 app.py > /tmp/flask-webrtc.log 2>&1 &
FLASK_PID=$!
sleep 3

if ! ss -tlnp | grep -q ":${PORT}"; then
    echo "❌ ERRO: Flask não subiu na porta ${PORT}. Log:"
    tail -5 /tmp/flask-webrtc.log
    cat /tmp/caraprojetada-*.log 2>/dev/null | tail -5
    exit 1
fi
echo "✅ Servidor rodando na porta ${PORT} (PID: $FLASK_PID)"

# ───────────────────────────────────────────────
# [2/3] Ocultador de mouse
# ───────────────────────────────────────────────
echo "====== [2/3] Ocultando cursor ======"
unclutter -idle 0 -root 2>/dev/null &

# ───────────────────────────────────────────────
# [3/3] Chromium Kiosk
# ───────────────────────────────────────────────
echo "====== [3/3] Iniciando Chromium Kiosk ======"
echo "URL: http://localhost:${PORT}/display"

pkill -9 -f "chromium" 2>/dev/null
sleep 1

# ── Detecta resolução ──
RES=""
XORG_RODANDO=false
pgrep -x Xorg > /dev/null && XORG_RODANDO=true

if $XORG_RODANDO; then
    xrandr --output HDMI-1 --auto 2>/dev/null
    sleep 1
    RES=$(xdpyinfo 2>/dev/null | grep dimensions | awk '{print $2}')
fi

if [ -z "$RES" ]; then
    RES="1440x900"  # fallback
fi

W="${RES%x*}"  # largura (ex: 1440)
H="${RES#*x}"  # altura (ex: 900)
echo "Resolução: $RES (${W}x${H})"

# ── Monta comando chromium ──
CHROMIUM_BIN=/usr/bin/chromium
CHROMIUM_URL="http://localhost:${PORT}/display"
CHROMIUM_FLAGS="\
  --kiosk \
  --no-sandbox \
  --no-first-run \
  --disable-gpu-vsync \
  --window-size=$RES \
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
  --media-cache-size=1"

# ── Helper: redimensiona TODAS as janelas chromium (UMA VEZ) via WM_CLASS ──
xdotool_resize_una_vez() {
    local w=$1 h=$2
    local wins
    for i in 1 2 3; do
        wins=$(xdotool search --class "chromium" 2>/dev/null | sort -u)
        if [ -n "$wins" ]; then
            local count=0
            for wid in $wins; do
                local geo cur_w cur_h
                geo=$(xdotool getwindowgeometry "$wid" 2>/dev/null)
                cur_w=$(echo "$geo" | sed -n 's/.*Geometry: \([0-9]*\)x.*/\1/p')
                cur_h=$(echo "$geo" | sed -n 's/.*x\([0-9]*\).*/\1/p')
                if [ "$cur_w" != "$w" ] || [ "$cur_h" != "$h" ]; then
                    xdotool windowmap "$wid" 2>/dev/null
                    xdotool windowsize "$wid" "$w" "$h" 2>/dev/null
                    xdotool windowmove "$wid" 0 0 2>/dev/null
                    count=$((count + 1))
                fi
            done
            if [ "$count" -gt 0 ]; then
                echo "xdotool: $count janela(s) redim p/ ${w}x${h}"
            else
                echo "xdotool: janelas já em ${w}x${h}"
            fi
            return 0
        fi
        sleep 5
    done
    echo "⚠️ xdotool: nenhuma janela chromium encontrada"
    return 1
}

# ── Se Xorg não rodando: usa xinit ──
if ! $XORG_RODANDO; then
    echo "Xorg não detectado. Iniciando com xinit..."
    rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null

    cat > /tmp/xinitrc-webrtc << XINITRC
#!/bin/sh
xrandr --output HDMI-1 --auto 2>/dev/null
sleep 1
export DISPLAY=:0
$CHROMIUM_BIN $CHROMIUM_FLAGS --window-position=0,0 $CHROMIUM_URL &
CPID=\$!
# espera janela aparecer e redimensiona UMA VEZ (sem loop)
for i in 1 2 3; do
  sleep 3
  WINS=\$(xdotool search --class "chromium" 2>/dev/null | sort -u)
  [ -n "\$WINS" ] && {
    echo "\$WINS" | while read W; do
      GEO=\$(xdotool getwindowgeometry \$W 2>/dev/null | grep Geometry | awk '{print \$2}')
      W_CUR=\$(echo "\$GEO" | cut -dx -f1)
      H_CUR=\$(echo "\$GEO" | cut -dx -f2)
      if [ "\$W_CUR" != "$W" ] || [ "\$H_CUR" != "$H" ]; then
        xdotool windowmap \$W 2>/dev/null
        xdotool windowsize \$W $W $H 2>/dev/null
        xdotool windowmove \$W 0 0 2>/dev/null
      fi
    done
    echo "xdotool: janelas verificadas/redim"
    break
  }
done
wait \$CPID
XINITRC
    chmod +x /tmp/xinitrc-webrtc

    echo "Rodando: xinit /tmp/xinitrc-webrtc -- :0 vt1 -keeptty"
    xinit /tmp/xinitrc-webrtc -- :0 vt1 -keeptty > /tmp/xinit.log 2>&1
    echo "xinit exit code: $?"
    tail -5 /tmp/xinit.log

    echo "⚠️ Xinit encerrou. Parando servidor Flask..."
    kill $FLASK_PID 2>/dev/null
    exit 0
fi

# ── Xorg já rodando: inicia direto ──
echo "Iniciando chromium (PID background)..."
$CHROMIUM_BIN $CHROMIUM_FLAGS $CHROMIUM_URL &
CHROME_PID=$!
echo "Chromium PID: $CHROME_PID"

# xdotool UMA VEZ em background (sem loop contínuo)
(sleep 8 && xdotool_resize_una_vez $W $H) &

wait $CHROME_PID 2>/dev/null

echo "⚠️ Chromium encerrou. Parando servidor Flask..."
kill $FLASK_PID 2>/dev/null
exit 0
