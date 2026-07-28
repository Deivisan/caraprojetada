# Troubleshooting — WebRTC / Projetor

## Tela preta ou azul no `/display`

**Solução:**
```bash
# Verificar se chromium está rodando
pgrep -a chromium || pkill -9 -f "chromium"

# Verificar resolução
DISPLAY=:0 xrandr | grep connected

# Forçar resolução 1440x900
xrandr --newmode "1440x900_60" 106.50 1440 1528 1672 1904 900 903 909 934 -hsync +vsync
xrandr --addmode HDMI-1 1440x900_60
xrandr --output HDMI-1 --mode 1440x900_60
```

## WebRTC n conecta (após autorizar)

**Solução:**
```bash
# Verificar logs do flask
tail -f /var/log/projetor-acessos.log

# Verificar se o display entrou na sala
tail -f /tmp/caraprojetada.log | grep -i display

# Verificar socket.io
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5000/socket.io/?EIO=4&transport=polling

# Nat / firewall: se professor e projetor estão na mesma rede 172.17.x.x, stun deve resolver automaticamente
```

## Flask não inicia na porta 80

**Solução:**
```bash
# Verificar se outra coisa ocupa a porta
sudo ss -tlnp | grep ':80'

# Verificar permissão do serviço (porta <1024)
sudo setcap 'cap_net_bind_service=+ep' $(which python3)

# Verificar configuração do systemd
cat /etc/systemd/system/projetor.service
```

## Chromium não abre em kiosk

**Solução:**
```bash
# Matar processos antigos
pkill -9 -f "chromium"

# Garantir DISPLAY e XAUTHORITY corretos
export DISPLAY=:0
export XAUTHORITY=/home/carapreta/.Xauthority

# Testar sem kiosk primeiro (depuração)
chromium --no-sandbox http://localhost/display

# Se Xorg não estiver rodando, o script deve usar xinit
pgrep -x Xorg || (o script deve cair para xinit)
```

## Guitarra: cursor visível

**Solução:**
```bash
# Verificar se openbox está rodando
pgrep -x openbox || openbox --replace &

# Verificar se compositor está ativo (deve estar OFF)
pgrep -a compton || pkill -f compton
```

## Temperatura acima de 75°c

**Solução:**
```bash
# Verificar processos consumindo cpu
ps -eo pid,ppid,comm,%cpu,%mem,rss --sort=-%cpu | head -15

# Reduzir carga do chromium
pkill -9 -f "chromium" && sleep 2
# editar --renderer-process-limit=1 no iniciar_tudo.sh
```

## Socket não conecta após mudança de rede do professor

**Solução:**
- feche o navegador e abra o dashboard novamente
- verifique se o ip do professor mudou e se o stun publico foi alcançado
- o app não usa turn — só funciona na mesma rede institucional

## Debug socket.io

```bash
# No console do chromium (projetor)
sudo DISPLAY=:0 XAUTHORITY=/home/carapreta/.Xauthority chromium --no-sandbox http://localhost/display
# Abra DevTools (Ctrl+Shift+I) e vá para a aba Network
# Filtre por socket.io para ver conexões e mensagens
```

## Desligar websocket para debugging

`CARAPROJETADA_ENV=dev` habilita logs detalhados. Para produção, remova essas linhas no `app.py`:

```python
logger=DEV_MODE,
engineio_logger=DEV_MODE
```