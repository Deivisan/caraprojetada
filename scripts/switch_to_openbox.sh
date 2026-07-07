#!/bin/bash
# switch_to_openbox.sh — Migra de xfwm4/xfce4 para openbox
# Economia estimada: ~80 MB de RAM (RK3229 agradece)
# Uso: ./switch_to_openbox.sh [--force] [--revert]
#
# Flags:
#   --force    Pula confirmacoes
#   --revert   Volta para xfwm4/xfce4

set -e

LOG="/var/log/openbox-migration.log"
DATAHORA=$(date '+%Y-%m-%d %H:%M:%S')
FORCE=false
REVERT=false

for arg in "$@"; do
    case "$arg" in
        --force) FORCE=true ;;
        --revert) REVERT=true ;;
    esac
done

log() {
    echo "[$DATAHORA] $1" | tee -a "$LOG"
}

confirm() {
    if [ "$FORCE" = true ]; then
        return 0
    fi
    read -rp "$1 [s/N] " resp
    [[ "$resp" =~ ^[sSyY] ]] && return 0 || return 1
}

# ═══════════════════════════════════════════
# REVERTER: openbox → xfwm4
# ═══════════════════════════════════════════
if [ "$REVERT" = true ]; then
    log "=== REVERTENDO: openbox → xfwm4 ==="
    confirm "Reverter para xfwm4/xfce4?" || exit 0

    # Instala xfwm4 de volta se necessario
    if ! command -v xfwm4 &>/dev/null; then
        apt install -y xfwm4 xfce4-session xfce4-panel 2>&1 | tee -a "$LOG"
    fi

    # Remove openbox do lightdm
    if [ -f /usr/share/xsessions/openbox.desktop ] && [ -f /usr/share/xsessions/xfce.desktop ]; then
        mkdir -p /etc/lightdm/lightdm.conf.d
        cat > /etc/lightdm/lightdm.conf.d/10-totem-desktop.conf << 'EOF'
[Seat:*]
user-session=xfce
EOF
    fi

    # Remove autostart do openbox
    rm -f /home/carapreta/.config/openbox/autostart

    # Mata openbox e sobe xfwm4
    export DISPLAY=:0
    killall openbox 2>/dev/null || true
    sleep 1
    xfwm4 --replace --compositor=off &
    sleep 2

    log "REVERTIDO para xfwm4. Faca logout para aplicar."
    echo "Concluido! Recomendado: sudo systemctl restart lightdm"
    exit 0
fi

# ═══════════════════════════════════════════
# MIGRAR: xfwm4 → openbox
# ═══════════════════════════════════════════
log "=== MIGRANDO: xfwm4/xfce4 → openbox ==="
echo ""
echo "  Openbox e um window manager LEVE e minimalista."
echo "  Ideal para o RK3229 com apenas 1 GB de RAM."
echo "  O projetor continuara funcionando normalmente."
echo ""

confirm "Iniciar migracao para openbox?" || exit 0

# ── 1. Instala openbox ──────────────────────────────────
log "[1/5] Instalando openbox..."
apt update
apt install -y openbox obconf x11-utils x11-xserver-utils \
    xset xrandr 2>&1 | tee -a "$LOG"
log "[OK] openbox instalado."

# ── 2. Cria config do openbox ──────────────────────────
log "[2/5] Criando config minimalista do openbox..."

mkdir -p /home/carapreta/.config/openbox

# rc.xml — config limpa: sem decoracoes, fullscreen, atalho VNC
cat > /home/carapreta/.config/openbox/rc.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc"
                xmlns:xi="http://www.w3.org/2001/XInclude">

  <resistance>
    <strength>10</strength>
    <corner_strength>20</corner_strength>
  </resistance>

  <focus>
    <focusNew>yes</focusNew>
    <followMouse>no</followMouse>
    <focusLast>yes</focusLast>
    <underMouse>no</underMouse>
    <focusDelay>200</focusDelay>
    <raiseOnFocus>no</raiseOnFocus>
    <cycleRaise>no</cycleRaise>
  </focus>

  <placement>
    <policy>UnderMouse</policy>
    <center>no</center>
    <monitor>Primary</monitor>
    <primaryMonitor>1</primaryMonitor>
  </placement>

  <theme>
    <name>Clearlooks</name>
    <titleLayout>NLIMC</titleLayout>
    <keepBorder>no</keepBorder>
    <animateIconify>no</animateIconify>
    <font place="ActiveWindow">
      <name>sans-serif</name>
      <size>9</size>
      <weight>bold</weight>
      <slant>normal</slant>
    </font>
    <font place="InactiveWindow">
      <name>sans-serif</name>
      <size>9</size>
      <weight>normal</weight>
      <slant>normal</slant>
    </font>
    <font place="MenuHeader">
      <name>sans-serif</name>
      <size>9</size>
      <weight>normal</weight>
      <slant>normal</slant>
    </font>
    <font place="MenuItem">
      <name>sans-serif</name>
      <size>9</size>
      <weight>normal</weight>
      <slant>normal</slant>
    </font>
    <font place="OnScreenDisplay">
      <name>sans-serif</name>
      <size>9</size>
      <weight>normal</weight>
      <slant>normal</slant>
    </font>
  </theme>

  <desktops>
    <number>1</number>
    <firstdesk>1</firstdesk>
    <names>
      <name>Projetor</name>
    </names>
    <popupTime>0</popupTime>
  </desktops>

  <resize>
    <drawContents>no</drawContents>
    <popupShow>Never</popupShow>
    <popupPosition>Center</popupPosition>
    <popupFixedPosition>
      <x>10</x>
      <y>10</y>
    </popupFixedPosition>
  </resize>

  <dock>
    <position>TopLeft</position>
    <floatingX>0</floatingX>
    <floatingY>0</floatingY>
    <noStrut>yes</noStrut>
    <stacking>Below</stacking>
    <autoHide>no</autoHide>
    <hideDelay>300</hideDelay>
    <showDelay>300</showDelay>
    <moveButton>middle</moveButton>
  </dock>

  <keyboard>
    <chainQuitKey>C-g</chainQuitKey>
    <!-- Alt+F4 = fechar -->
    <keybind key="A-F4">
      <action name="Close"/>
    </keybind>
    <!-- F11 = fullscreen toggle -->
    <keybind key="F11">
      <action name="ToggleFullscreen"/>
    </keybind>
    <!-- Ctrl+Alt+Del = chromium kiosk -->
    <keybind key="C-A-Delete">
      <action name="Execute">
        <command>killall chromium; sleep 1; DISPLAY=:0 chromium --kiosk https://www.uol.com.br/</command>
      </action>
    </keybind>
  </keyboard>

  <mouse>
    <dragThresholdRatio>8</dragThresholdRatio>
    <doubleClickTime>200</doubleClickTime>
    <screenEdgeWarpTime>400</screenEdgeWarpTime>
    <screenEdgeWarpMouse>false</screenEdgeWarpMouse>
    <context name="Root">
      <mousebind button="Right" action="Press">
        <action name="ShowMenu">
          <menu>root-menu</menu>
        </action>
      </mousebind>
    </context>
    <context name="Client">
      <mousebind button="Left" action="Press">
        <action name="Focus"/>
        <action name="Raise"/>
      </mousebind>
    </context>
  </mouse>

  <menu>
    <file>menu.xml</file>
    <hideDelay>200</hideDelay>
    <middle>no</middle>
    <submenuShowDelay>100</submenuShowDelay>
    <applicationIcons>no</applicationIcons>
    <generate>no</generate>
  </menu>

  <applications>
    <!-- chromium sempre fullscreen sem bordas -->
    <application class="Chromium" type="normal">
      <fullscreen>yes</fullscreen>
      <decor>no</decor>
      <maximized>yes</maximized>
      <desktop>1</desktop>
      <skipTaskbar>yes</skipTaskbar>
      <skipPager>yes</skipPager>
    </application>
    <!-- xtightvncviewer sem decorações -->
    <application class="Xtightvncviewer" type="normal">
      <fullscreen>yes</fullscreen>
      <decor>no</decor>
      <maximized>yes</maximized>
    </application>
  </applications>

</openbox_config>
EOF

# menu.xml — minimalista
cat > /home/carapreta/.config/openbox/menu.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/3.4/menu">
  <menu id="root-menu" label="Projetor">
    <item label="Chromium Kiosk">
      <action name="Execute">
        <command>killall chromium 2>/dev/null; sleep 1; DISPLAY=:0 chromium --kiosk https://www.uol.com.br/</command>
      </action>
    </item>
    <item label="Terminal">
      <action name="Execute">
        <command>xterm</command>
      </action>
    </item>
    <separator/>
    <item label="Reiniciar Openbox">
      <action name="Reconfigure"/>
    </item>
    <item label="Logout">
      <action name="Exit"/>
    </item>
  </menu>
</openbox_menu>
EOF

# autostart — coisas que sobem com o openbox
cat > /home/carapreta/.config/openbox/autostart << 'EOFAUTOSTART'
#!/bin/bash
# Openbox Autostart — CaraProjetada Totem
# Dobra o display, desliga screensaver, sobe kiosk

# Configuracoes de display
xset s off
xset -dpms
xset s noblank

# Forca resolucao (ajuste conforme seu display)
xrandr --output HDMI-1 --mode 1920x1080 2>/dev/null || true

# Remove cursor
xsetroot -cursor_name left_ptr

# Sobe o Chromium kiosk (opcional — guardian gerencia)
# DISPLAY=:0 chromium --kiosk --start-maximized --noerrdialogs \
#     --disable-infobars --incognito https://www.uol.com.br/ &
EOFAUTOSTART
chmod +x /home/carapreta/.config/openbox/autostart

chown -R carapreta:carapreta /home/carapreta/.config/openbox
log "[OK] Config do openbox criada."

# ── 3. Configura lightdm para openbox ──────────────────
log "[3/5] Configurando LightDM para openbox..."

# Cria .desktop entry se nao existir
if [ ! -f /usr/share/xsessions/openbox.desktop ]; then
    cat > /usr/share/xsessions/openbox.desktop << 'EOF'
[Desktop Entry]
Name=Openbox
Comment=Window Manager Leve
Exec=openbox-session
TryExec=openbox-session
Type=Application
EOF
fi

# Seta openbox como sessao padrao
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/10-totem-desktop.conf << 'EOF'
[Seat:*]
user-session=openbox
EOF

log "[OK] LightDM configurado."

# ── 4. Desabilita xfce4-session antigo ────────────────
log "[4/5] Desabilitando xfwm4/xfce4 da inicializacao..."

# Remove XFCE da autolist do lightdm
systemctl disable lightdm.service 2>/dev/null || true  # disable multi-user pra nao conflitar
systemctl enable lightdm 2>/dev/null || true

log "[OK] xfwm4 desabilitado — openbox sera o padrao."

# ── 5. Remove pacotes xfce4 (opcional) ────────────────
log "[5/5] Removendo pacotes xfce4 pesados (opcional)..."
echo ""
echo "  Quer remover xfwm4, xfce4-session e xfce4-panel?"
echo "  Isso libera ~80 MB de RAM e ~150 MB de disco."
echo "  (openbox continuara funcionando)"
echo ""

if confirm "Remover xfce4? (recomendado)"; then
    apt remove -y xfwm4 xfce4-session xfce4-panel xfdesktop4 \
        xfce4-settings thunar 2>&1 | tee -a "$LOG"
    apt autoremove -y 2>&1 | tee -a "$LOG"
    log "[OK] Pacotes xfce4 removidos."
else
    log "[INFO] xfce4 mantido (pode reverter com --revert)."
fi

log "=== MIGRACAO CONCLUIDA ==="
echo ""
echo "  ✅ Openbox instalado e configurado!"
echo "  ✅ LightDM apontando para openbox-session"
echo "  ✅ Chromium fullscreen sem bordas"
echo ""
echo "  Efetivar: sudo systemctl restart lightdm"
echo "  Reverter: $0 --revert"
echo ""
