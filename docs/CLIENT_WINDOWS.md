# Cliente VNC para Windows - Guia e Cenarios

## Objetivo

Criar um pacote de instalacao automatica para Windows que:
1. Instala TightVNC Server em modo service (headless)
2. Configura senha pre-definida (123456)
3. Inicia automaticamente
4. Permite descoberta automatica de projetores na rede

---

## Cenario Atual (reverse VNC)

```
Usuario (Windows/Linux)           Projetor (RK322x)
+---------------------+            +---------------------+
| VNC SERVER rodando  | <-------- | xtightvncviewer     |
| na porta :0         |   conecta | (cliente)           |
+---------------------+            +---------------------+
                                     ^
                                     |
                              http://172.17.28.179:80
                                     |
                                  Flask + AD
```

Problema: O usuario precisa instalar manualmente um VNC server.

---

## Solucao: Cliente Windows Auto-configuravel

### Opcao 1: TightVNC MSI Silencioso

```powershell
# Instalar TightVNC com senha pre-definida
msiexec.exe /i tightvnc-2.8.87-gpl-setup-64bit.msi /quiet /norestart `
  VALUE_OF_PASSWORD=123456 `
  VALUE_OF_CONTROLPASSWORD=123456 `
  VALUE_OF_VIEWONLYPASSWORD=123456

# Instalar como servico
tvnserver.exe -install -silent
tvnserver.exe -start
```

### Opcao 2: UltraVNC (alternativa)

UltraVNC tambem oferece instalacao silenciosa e pode ser mais leve:

```powershell
UltraVNC-2.8.87.msi /VERYSILENT /SUPPRESSMSGBOXES /MERGETASKS="!desktopicon,!desktopicon\common,!fileassoc,!installservice"
```

---

## Perguntas a Responder (para arquitetura final)

### P1: Como descobrir projetores na rede?

Opcoes:
- [ ] mDNS/Zeroconf: Projetores anunciam servico _vnc._tcp
- [ ] Scan ICMP: Broadcast ping na rede 172.17.0.0/16 procurando porta 80
- [ ] HTTP REST: Novo endpoint /api/discover no Flask
- [ ] WebSocket: Conexao persistente para notificacao de disponibilidade

### P2: Autenticacao sem AD/LDAP?

Opcoes:
- [ ] Token pre-shared: Codigo unico gerado no projetor (ex: PROJ-XXXX)
- [ ] QR Code: Scanner no projetor para pareamento
- [ ] IP Whitelist: Lista de IPs autorizados
- [ ] Keep AD: Manter autenticacao institucional

### P3: Conexao automatica ou botao?

Opcoes:
- [ ] Auto-conexao: Windows detecta projetor e conecta automaticamente
- [ ] Botao manual: Usuario clica para conectar
- [ ] Hotkey: Ctrl+Alt+V para iniciar transmissao
- [ ] Tray icon: Icone na bandeja com menu "Transmitir para projetor"

### P4: Qual protocolo VNC?

| Ferramenta | Compatibilidade | Comentarios |
|------------|-----------------|-------------|
| TightVNC 2.x | Total | Recomendado, MSI silencioso |
| TigerVNC | Total | Mais moderno, sem MSI |
| UltraVNC | Total | Mais leve |
| RealVNC | Parcial | Pode precisar de licenca |

---

## Configuracao TightVNC via Registry

```registry
[HKEY_LOCAL_MACHINE\SOFTWARE\TightVNC\Server]
"Password"=hex:61,e4,...
"ControlPassword"=hex:...
"AcceptConnections"=dword:00000001
"LoopbackOnly"=dword:00000000
```

---

## Roadmap

### Fase 1 - Proof of Concept
- [ ] Script PowerShell para instalar TightVNC
- [ ] Configurar senha via registry
- [ ] Testar com carapreta-box

### Fase 2 - Auto-descoberta
- [ ] Scanner de rede para projetores
- [ ] Tray icon com menu

### Fase 3 - Integracao Total
- [ ] QR Code para pareamento
- [ ] WebSocket para notificacao