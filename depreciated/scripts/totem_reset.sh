#!/bin/bash
export DISPLAY=:0
killall chromium 2>/dev/null; killall openbox 2>/dev/null; killall xfwm4 2>/dev/null
sudo systemctl restart lightdm
echo "Totem reiniciado."
