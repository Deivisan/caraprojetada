# Teste de Integração - CaraProjetada

## Testes de Conectividade VNC

### 1. Verificar VM Windows 11
```bash
# Verificar estado
virsh domstate win11-ufrb

# Verificar porta VNC
ss -tlnp | rg 5900

# Conectar via remote-viewer
remote-viewer vnc://localhost:5900
```

### 2. Dentro do Windows 11
- Abrir o navegador Chrome
- Instalar a extensão CaraProjetada (arquivo .crx)
- Executar o cliente Python

### 3. Teste de Espelhamento de Aba

#### Cenário 1: Extensão do Navegador
1. Usuário abre Chrome com múltiplas abas
2. Clica no ícone da extensão CaraProjetada
3. Seleciona uma aba específica
4. Extensão envia POST `/api/v1/tab`
5. Projetor (RK3229) abre URL em modo kiosk
6. VNC continua transmitindo tela inteira

#### Cenário 2: VNC Reverso (Fallback)
1. Usuário não tem extensão
2. Conecta via painel web (`CONECTAR TELA`)
3. VNC viewer abre conexão para `user_ip:5900`
4. UltraVNC Server no Windows transmite tela

## Teste Manual do VNC

```bash
# Do projetor (RK3229) ou do host:
xtightvncviewer localhost:5900 -autopass

# Ou usando remmina:
remmina vnc://localhost:5900
```

## Verificação de Logs

```bash
# Logs do projetor
ssh carapreta@carapreta-box 'journalctl -u projetor -f'

# Logs do Flask
tail -f /var/log/flask.log

# Heartbeat visualization
curl http://localhost/api/v1/computers
```

## API Endpoints para Teste

```bash
# Status do projetor
curl http://localhost/api/v1/status

# Listar sessões VNC
curl http://localhost/api/v1/sessions

# Simular registro de PC
curl -X POST http://localhost/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{"hostname": "TEST-PC"}'
```

## Troubleshooting

### VNC não conecta
```powershell
# No Windows 11:
netstat -an | findstr 5900
Get-Service -Name "UltraVNC*"
```

### Firewall bloqueando
```powershell
# Verificar regra
netsh advfirewall firewall show rule name="UltraVNC Server"

# Adicionar regra
netsh advfirewall firewall add rule name="UltraVNC Server" dir=in action=allow protocol=TCP localport=5900
```

### Extensão não aparece
- Chrome → `chrome://extensions`
- Habilitar "Developer mode"
- Carregar extensão descompactada