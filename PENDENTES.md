# Pendências - CaraProjetada

## 🔴 **RESOLVIDAS**

### 1. Instalação do TightVNC no Windows 11
**Status**: ✅ Resolvido via `windows-client/definitive-tightvnc.bat`  
**Arquivo**: `windows-client/definitive-tightvnc.bat` — instalador completo que:
- Auto-eleva para admin
- Baixa TightVNC 2.8.87 de 3 fontes
- Instala como serviço com start=auto
- Configura senha "123456" no registro
- Abre firewall (portas 5900, 5800)
- Verifica: serviço, porta, senha, firewall, teste TCP

### 2. Teste de Conectividade Bidirecional
**Status**: ✅ Cliente Linux (TigerVNC) funcionando. VM Windows com TightVNC resolvido via .bat

---

## 🟡 **EM DESENVOLVIMENTO**

### Extensão do Navegador
- ✅ Manifest V3 criado
- ✅ Popup HTML/CSS/JS criado  
- ✅ Background script criado
- ⏳ Testar em Chrome/Firefox
- ⏳ Integração com API REST

### Cliente Windows Python
- ✅ Script principal criado (`main.py`)
- ✅ Classe de gerenciamento VNC criada
- ⏳ Pacote para distribuição (.exe)
- ⏳ Testes no Windows 11

---

## 🟢 **CONCLUÍDAS**

### ✅ Cliente Linux (TigerVNC)

| Item | Status |
|------|--------|
| TigerVNC instalado no Arch Linux | ✅ |
| Senha "123456" configurada | ✅ |
| Porta 5903 (display :3) liberada no firewall | ✅ |
| Serviço systemd auto-init (`tigervnc@3`) | ✅ |
| Conexão VNC testada da box → Arch | ✅ |
| Documentação atualizada (`docs/CLIENT_LINUX.md`) | ✅ |

**Comando de conexão (da box):**
```bash
echo "123456" | DISPLAY=:0 /usr/bin/xtightvncviewer 172.17.23.130:3 -autopass
```

### API Flask Atualizada
- ✅ Novo endpoint `/api/v1/tab` - recebe aba selecionada
- ✅ Novo endpoint `/api/v1/register` - registra PC
- ✅ Novo endpoint `/api/v1/vnc/password` - senha dinâmica
- ✅ Novo endpoint `/api/v1/computers` - lista PCs
- ✅ Sessões VNC com expiração automática

### Documentação
- ✅ `BROWSER_EXTENSION.md` - arquitetura da extensão
- ✅ `WINDOWS_CLIENT.md` - especificação do cliente
- ✅ `INTEGRATION_TEST.md` - guia de testes
- ✅ `ROADMAP.md` - atualizado com Fase 6

---

## 📋 **Arquitetura de Comunicação Proposta**

```
Windows 11 (UltraVNC Server)
│
├── Porta 5900/TCP (espelhamento tela)
├── Cliente Python → registra no projetor
└── Heartbeat a cada 30s (online status)

           ↓

Projetor (RK3229 + Flask)
│
├── POST /api/v1/register ← heartbeat
├── POST /api/v1/tab ← extensão browser
├── xtightvncviewer → conecta no Windows:5900
└── chromium --kiosk → aba escolhida

           ↓

Navegador (Extensão CaraProjetada)
│
├── Lista abas disponíveis
├── Envia seleção via API
└── Notifica status do projetor
```

---

## 🧪 **Plano de Teste Imediato**

### Etapa 1: VNC no Windows 11
```bash
# 1. Conectar na VM
remote-viewer vnc://localhost:5900 &

# 2. Dentro do Windows, executar:
# - Download UltraVNC: https://www.uvnc.com/
# - Instalar como serviço
# - Configurar senha "123456"
# - Abrir firewall
```

### Etapa 2: Teste de Endpoint
```bash
# Do host, após instalar Flask:
python3 -c "
from app import app
with app.test_client() as c:
    r = c.post('/api/v1/tab', json={'url': 'https://google.com', 'title': 'Teste'})
    print(r.json)
"
```

### Etapa 3: Extensão no Navegador
- Carregar extensão em `chrome://extensions`
- Testar popup
- Verificar console para erros de API