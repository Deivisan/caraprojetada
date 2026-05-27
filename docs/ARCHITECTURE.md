# 🏗️ Arquitetura do CaraProjetada - Multi-Sala

## Visão do Sistema

O CaraProjetada é um **sistema de projetores multi-sala** que permite a transmissão de tela via VNC com autenticação institucional.

---

## Arquitetura Central

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DASHBOARD CENTRAL                                  │
│                    (http://projetores.intranet.ufrb.edu.br)                   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                          Portal Web                                   │   │
│  │                                                                     │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐       │   │
│  │  │   SALA 1   │  │   SALA 2   │  │   SALA 3   │  │   SALA N   │       │   │
│  │  │ [ONLINE]   │  │ [OFFLINE]  │  │ [ONLINE]   │  │ [ONLINE]   │       │   │
│  │  │ 172.17.x.x │  │ 172.17.x.x │  │ 172.17.x.x │  │ 172.17.x.x │       │   │
│  │  │ [CONECTAR] │  │ [CONECTAR] │  │ [CONECTAR] │  │ [CONECTAR] │       │   │
│  │  └────────────┘  └────────────┘  └────────────┘  └────────────┘       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ HTTP API (JSON)
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              REGISTRO PROJETORES                             │
│                          (registry/projetores.json)                            │
│                                                                             │
│  {                                                                        │
│    "salas": {                                                             │
│      "sala-1": {"ip": "172.17.28.179", "status": "online",  │
│      "sala-2": {"ip": "172.17.28.180", "status": "offline"} │
│    }                                                                        │
│  }                                                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Multicast/Broadcast
                                    ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│PROJETOR A   │ │PROJETOR B   │ │PROJETOR C   │ │PROJETOR N   │
│(RK3229)    │ │(RK3229)    │ │(RK3229)    │ │(RK3229)    │
│             │ │             │ │             │ │             │
│             │ │             │ │             │ │             │
│xtightvncviewer │ │xtightvncviewer │ │xtightvncviewer │ │xtightvncviewer │
│Flask :80      │ │Flask :80      │ │Flask :80      │ │Flask :80      │
│LightDM/Xorg   │ │LightDM/Xorg   │ │LightDM/Xorg   │ │LightDM/Xorg   │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
```

---

## Fluxo Detalhado

### 1. Autenticação (Dashboard)

```
Browser -> GET /
        <- HTML Login
POST /login (username, password)
        -> LDAP Bind: user@intranet.ufrb.edu.br
        <- Session Cookie
        -> Redirect /dashboard
```

### 2. Descoberta de Salas

```
Dashboard -> GET /api/salas
         <- JSON:
         {
           "salas": [
             {"id": "sala-1", "ip": "172.17.28.179", "status": "online"},
             {"id": "sala-2", "ip": "172.17.28.180", "status": "offline"}
           ]
         }
```

### 3. Conexão VNC

```
Dashboard -> POST /sala/sala-1/conectar
         <- Redirect para tela de conexão
         -> Executa no projetor:
         xtightvncviewer <IP_USUARIO>:0 -autopass
```

---

## API Endpoints

| Rota | Método | Descrição |
|------|--------|-----------|
| `/` | GET | Login page |
| `/login` | POST | Autentica LDAP |
| `/dashboard` | GET | Lista de salas |
| `/api/salas` | GET | JSON com projetores |
| `/sala/{id}/status` | GET | Status de uma sala |
| `/sala/{id}/conectar` | POST | Conecta VNC |
| `/sala/{id}/desconectar` | POST | Desconecta VNC |

---

## Cliente Windows - UltraVNC

### Instalação Silenciosa

```powershell
# MSI UltraVNC com senha pré-definida
msiexec.exe /i UltraVNC-2.8.87.msi /VERYSILENT /SUPPRESSMSGBOXES

# Configurar senha headless
# (via registry ou arquivo .reg)
reg import vnc-config.reg
```

### Configuração Registry (UltraVNC)

```registry
[HKEY_LOCAL_MACHINE\SOFTWARE\UltraVNC]
"VNCpassword"=hex:61,e4,ff,...  ; hash do password 123456
"HTTPPortNumber"=dword:00000016  ; 22 decimal
"PortNumber"=dword:00001744        ; 5900 decimal
```

### Operação

1. Usuário instala cliente Windows (UltraVNC service)
2. Usuário acessa dashboard
3. Usuário clica "CONECTAR" em uma sala
4. Projetor executa `xtightvncviewer <IP_USUARIO>:0`
5. Tela do Windows aparece no projetor

---

## Segurança

| Camada | Implementação |
|--------|---------------|
| Autenticação | AD/LDAP (institucional) |
| Autorização | Sessão Flask + tokens |
| Rede | Firewall 172.17.0.0/16 |
| VNC | Senha pré-compartilhada |
| Logs | Windows Event + syslog |

---

## Deployment

### Projetor (RK322x)

```bash
# Instalar dependências
sudo apt install -y python3-flask python3-ldap3 xtightvncviewer

# Copiar app
sudo cp app/app.py /home/carapreta/
sudo cp systemd/projetor.service /etc/systemd/system/
sudo systemctl enable --now projetor
```

### Cliente Windows

1. Executar instalador UltraVNC silencioso
2. Configurar senha `123456`
3. Iniciar serviço VNC
4. Acessar dashboard institucional