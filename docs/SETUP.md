# Setup do Projetor VNC - Guia de Implantacao

## 📋 Pre-requisitos

- TV Box RK322x com Armbian instalado
- Acesso SSH ao dispositivo
- Projetor/TV conectado via HDMI
- (Opcional) Camera USB para streaming

## 🚀 Deploy passo a passo

### 1. Conectar via SSH

```bash
ssh carapreta@172.17.28.179
# Senha: carapreta123
```

### 2. Instalar dependencias

```bash
sudo apt update
sudo apt install -y \
  python3 python3-flask python3-ldap3 \
  xtightvncviewer chromium-browser \
  x11-utils xserver-xorg-core xfwm4 lightdm \
  vlc vlc-bin
```

### 3. Configurar o app Flask

```bash
# Copiar o app
cp caraprojetada/app/app.py /home/carapreta/

# Ajustar permissoes
chmod +x /home/carapreta/app.py
```

**Editar configuracoes do AD no app.py:**
```python
AD_SERVER = 'ldap://10.198.1.2'        # IP do Domain Controller
AD_DOMAIN = 'intranet.ufrb.edu.br'      # Seu dominio
```

### 4. Configurar servicos systemd

```bash
sudo cp caraprojetada/systemd/projetor.service /etc/systemd/system/
sudo cp caraprojetada/systemd/stream-cam.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now projetor

# Se tiver camera:
sudo systemctl enable --now stream-cam
```

### 5. Configurar scripts de manutencao

```bash
# Copiar scripts
cp caraprojetada/scripts/*.sh /home/carapreta/
chmod +x /home/carapreta/*.sh

# Configurar cron
crontab -e
# Adicionar:
* * * * * /home/carapreta/totem_guardian.sh
* * * * * sleep 30 && /home/carapreta/totem_watchdog.sh
*/30 * * * * /home/carapreta/totem_watchdog.sh
```

### 6. Configurar Chromium como kiosk

```bash
# Testar manualmente:
export DISPLAY=:0
chromium --kiosk --start-maximized --noerrdialogs \
         --disable-infobars --incognito https://www.uol.com.br/ &
```

### 7. Configurar senha VNC

```bash
echo "123456" > ~/.vnc_pass
chmod 600 ~/.vnc_pass
```

## 🔄 Fluxo de uso

1. **Usuario** acessa `http://172.17.28.179:80`
2. **Login** com credenciais institucionais (AD)
3. **Cliente** inicia servidor VNC no notebook
4. **Clica** "CONECTAR TELA" no painel
5. **Projetor** exibe tela do usuario

## ✅ Verificacao pos-deploy

```bash
# Verificar servicos
systemctl status projetor
systemctl status stream-cam

# Verificar porta 80
ss -tlnp | grep 80

# Verificar cron
crontab -l

# Testar autenticacao AD
python3 -c "
from ldap3 import Server, Connection, ALL
server = Server('ldap://10.198.1.2', get_info=ALL)
conn = Connection(server, user='teste@intranet.ufrb.edu.br', password='senha', authentication='SIMPLE')
print('AD OK' if conn.bind() else 'AD FALHOU')
"
```
