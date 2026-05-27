# Troubleshooting - Projetor VNC

## ❌ Tela preta apos boot

**Causas possiveis:**
- Xorg nao iniciou
- LightDM falhou
- Resolucao incorreta

**Solucao:**
```bash
# Verificar se Xorg esta rodando
pgrep -x Xorg || sudo systemctl restart lightdm

# Verificar resolucao
DISPLAY=:0 xrandr | grep connected

# Forcar resolucao
DISPLAY=:0 xrandr --output HDMI-1 --mode 1920x1080
```

## ❌ Cursor aparece como "X"

**Causa:** xfwm4 (window manager) nao esta rodando.

**Solucao:**
```bash
# Verificar se xfwm4 esta instalado
which xfwm4 || sudo apt install -y xfwm4

# Iniciar manualmente
DISPLAY=:0 xfwm4 --replace --compositor=off &
```

O `totem_guardian.sh` faz isso automaticamente.

## ❌ Chromium nao abre em kiosk

**Solucao:**
```bash
# Matar processos antigos
killall chromium 2>/dev/null

# Iniciar manualmente
DISPLAY=:0 chromium --kiosk --start-maximized \
  --noerrdialogs --disable-infobars \
  --incognito https://www.uol.com.br/ &
```

## ❌ "No route to host" no VNC

**Causa:** wlan0 sem IP ou rede instavel.

**Solucao:**
```bash
# Verificar IP
ip addr show wlan0

# Forcar DHCP
sudo dhclient wlan0

# Verificar conectividade com o cliente
ping <ip_do_cliente>
```

## ❌ Autenticacao AD falhando

**Verificacoes:**
```bash
# Testar conectividade com AD
nc -zv 10.198.1.2 389

# Testar bind LDAP
python3 -c "
from ldap3 import Server, Connection, ALL
server = Server('ldap://10.198.1.2', get_info=ALL)
conn = Connection(server, user='teste@intranet.ufrb.edu.br', password='senha', authentication='SIMPLE')
print('Bind OK' if conn.bind() else 'Bind FALHOU')
"
```

**Configuracoes no app.py:**
```python
AD_SERVER = 'ldap://10.198.1.2'       # IP do Domain Controller
AD_DOMAIN = 'intranet.ufrb.edu.br'     # Dominio correto
```

## ❌ xtightvncviewer nao conecta

**Causa:** Cliente não tem servidor VNC rodando.

**Solucao (no notebook do usuario):**
```bash
# Linux - Iniciar servidor VNC (compartilhando tela atual)
x11vnc -display :0 -usepw -forever

# Windows - Usar TightVNC Server ou TigerVNC
```

## ❌ Erro "glamor initialization failed"

**Causa:** Driver de video Mali-400 nao carregou corretamente.

**Solucao:** Geralmente nao afeta a operacao. O X11 funciona em modo fallback.

## 🔄 Reset de emergencia

```bash
# Reset completo do totem
/home/carapreta/totem_reset.sh

# Ou manualmente:
sudo systemctl restart lightdm
killall chromium
export DISPLAY=:0
chromium --kiosk --start-maximized --noerrdialogs \
  --disable-infobars --incognito https://www.uol.com.br/ &
```

## 📊 Logs

```bash
# Log do guardian
tail -f /var/log/totem_guardian.log

# Log do watchdog
tail -f /home/carapreta/watchdog.log

# Log do projetor
journalctl -u projetor -f

# Log do streaming
journalctl -u stream-cam -f

# Log do sistema
dmesg | tail -20
sudo tail -f /var/log/syslog
```

## 🛡️ Watchdog nao esta executando

```bash
# Verificar cron
crontab -l

# Forcar execucao manual
bash /home/carapreta/totem_guardian.sh
bash /home/carapreta/totem_watchdog.sh

# Verificar permissoes
ls -la /home/carapreta/*.sh
chmod +x /home/carapreta/*.sh
```
