#!/bin/bash
# TOTEM RESET - Reinicializacao de emergencia do projetor
# Suporta: xfwm4 (legado) e openbox (recomendado)
# Uso: ./totem_reset.sh

export DISPLAY=:0

echo "========================================="
echo "  TOTEM RESET - Reiniciando servicos"
echo "========================================="

echo "Matando processos graficos..."
killall lightdm 2>/dev/null
killall chromium 2>/dev/null
killall xfce4-panel 2>/dev/null
killall xfce4-session 2>/dev/null
killall xfwm4 2>/dev/null
killall openbox 2>/dev/null
sleep 2

echo "Reiniciando LightDM..."
sudo systemctl restart lightdm

echo "========================================="
echo "  Totem reiniciado. Aguarde a tela subir."
echo "========================================="
