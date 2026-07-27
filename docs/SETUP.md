# Setup — Deploy WebRTC no Projetor

## Pré-requisitos

- TV Box RK322x com Armbian Bullseye instalado
- Acesso SSH ao dispositivo
- Projetor/TV conectado via HDMI
- Navegador moderno no laptop/professor (Chrome/Edge/Firefox, suporte a `getDisplayMedia`)

## 1. Clone do repositório

```bash
git clone <repo-url> caraprojetada
cd caraprojetada
git checkout dev
```

## 2. Instalar dependências no projetor (RK322x)

```bash
ssh carapreta@172.17.28.179
sudo apt update
sudo apt install -y \
  python3 python3-flask python3-flask-socketio python3-ldap3 \
  chromium \
  x11-utils xserver-xorg-core openbox lightdm \
  vlc vlc-bin
```

## 3. Configurar o app Flask

```bash
cp -r app/ /home/carapreta/app/
cd /home/carapreta/app
```

crie o virtualenv recomendado na box:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

> dica: o python3 padrão da armbian bullseye pode ser 3.9; o app funciona com 3.9+.

## 4. Configurar AD/LDAP (produção)

edite `/home/carapreta/app/app.py` ou use variáveis de ambiente:

```bash
export AD_SERVER='ldap://10.198.1.2'
export AD_DOMAIN='intranet.ufrb.edu.br'
export AD_BASE_DN='dc=intranet,dc=ufrb,dc=edu,dc=br'
```

em produção, nunca deixe os valores padrão se o ad interno já for diferente.

## 5. Configurar serviço systemd

```bash
sudo cp systemd/projetor.service /etc/systemd/system/projetor.service
sudo systemctl daemon-reload
sudo systemctl enable --now projetor
```

verifique:

```bash
sudo systemctl status projetor
journalctl -u projetor -f
```

## 6. Configurar chromium kiosk

o script `scripts/iniciar_tudo.sh` faz tudo automaticamente, mas o passo essencial é:

```bash
export DISPLAY=:0
export XAUTHORITY=/home/carapreta/.Xauthority
chromium --kiosk http://localhost/display \
  --no-sandbox --disable-gpu-vsync --disable-extensions \
  --disk-cache-dir=/tmp/chromium-cache --disk-cache-size=1
```

## 7. Acesso via navegador (professor)

1. acesse `http://172.17.28.179/` no navegador
2. faça login com credenciais institucionais
3. clique "Compartilhar Tela" (autoriza screen capture)
4. vídeo chega no projetor automaticamente

## 8. Modo dev (local, sem box real)

```bash
cd caraprojetada/app
CARAPROJETADA_ENV=dev flask --app app:app run --host 127.0.0.1 --port 5000
```

- login mock: `admin/admin`, `qualquer/dev`, `usuario/usuario`
- abra `http://127.0.0.1:5000/`
- abra `http://127.0.0.1:5000/display` em outra aba (simula projetor)

## 9. Watchdog e manutenção

```bash
# guardian: a cada 1 minuto
* * * * * /home/carapreta/totem_guardian.sh

# watchdog: a cada 30 minutos
*/30 * * * * /home/carapreta/totem_watchdog.sh
```

scripts salvos em:
- `scripts/totem_guardian.sh` — 1min, mais frequente
- `scripts/totem_watchdog.sh` — 30min, verificação periódica
- `scripts/switch_to_openbox.sh` — migração xfwm4 → openbox

## 10. Verificação pós-deploy

```bash
# py_compile
python3 -m py_compile app/app.py

# status json
curl -s http://127.0.0.1:5000/api/v1/status | python3 -m json.tool

# serviços
systemctl status lightdm
pgrep -a 'chromium|flask|Xorg|openbox'

# recursos
ssh caraprojetada 'free -h; uptime; df -h /; cat /sys/class/thermal/thermal_zone0/temp'
```