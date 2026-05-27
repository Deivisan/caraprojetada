#!/bin/bash
# Streaming de camera USB via RTSP usando VLC
# Disponibiliza em: rtsp://<ip>:8554/stream

# Configuracao
DEVICE="/dev/video0"
WIDTH=640
HEIGHT=360
FPS=10
PORT=8554

echo "Iniciando streaming RTSP da camera ${DEVICE}..."
echo "Stream: rtsp://$(hostname -I | awk '{print $1}'):${PORT}/stream"

cvlc v4l2://${DEVICE}:width=${WIDTH}:height=${HEIGHT}:fps=${FPS} \
    --live-caching=300 \
    --sout "#transcode{vcodec=h264,fps=${FPS},venc=x264{preset=ultrafast},vb=512,acodec=none}:rtp{sdp=rtsp://:${PORT}/stream}"

# Se falhar, tenta sem especificar fps
if [ $? -ne 0 ]; then
    echo "Falha na configuracao com FPS. Tentando sem FPS..."
    cvlc v4l2://${DEVICE}:width=${WIDTH}:height=${HEIGHT} \
        --live-caching=300 \
        --sout "#transcode{vcodec=h264,venc=x264{preset=ultrafast},vb=512,acodec=none}:rtp{sdp=rtsp://:${PORT}/stream}"
fi
