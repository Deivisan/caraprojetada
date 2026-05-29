<p align="center">
  <img src="./assets/images/logo.svg" alt="caraprojetada" width="110">
</p>

<h1 align="center">🎯 caraprojetada</h1>

<p align="center">
  <strong>projetor institucional embarcado em rk3229 · flask · vnc reverso · ad/ldap</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/branch-dev-6A1B9A?style=for-the-badge" alt="branch dev">
  <img src="https://img.shields.io/badge/status-em%20desenvolvimento-FFB300?style=for-the-badge" alt="status">
  <img src="https://img.shields.io/badge/hardware-rk3229%20armv7-003366?style=for-the-badge" alt="rk3229">
  <img src="https://img.shields.io/badge/flask-python-008B9E?style=for-the-badge" alt="flask">
  <img src="https://img.shields.io/badge/vnc-dev%20simulado-orange?style=for-the-badge" alt="vnc dev">
</p>

<p align="center">
  <a href="#-visão-geral">visão geral</a> ·
  <a href="#-modo-dev-local">modo dev</a> ·
  <a href="#-rotas-principais">rotas</a> ·
  <a href="#-desempenho">desempenho</a> ·
  <a href="#-próximos-passos">próximos passos</a>
</p>

---

## ✨ visão geral

`caraprojetada` transforma uma tv box **rockchip rk3229** em um ponto de projeção institucional: o usuário acessa uma interface web, autentica com credenciais institucionais e espelha a tela do notebook no projetor via **vnc reverso**.

esta branch `dev` contém o laboratório atual: **modo dev local**, **emulação visual da conexão vnc**, **tela idle 24/7 do projetor** e scripts preparados para migração de `xfwm4` para `openbox`.

> ⚠️ `main` continua sendo a linha segura/produção. daqui para frente, a migração será feita aos poucos após testes na rede 172 e no hardware real.

---

## 🧭 mapa do sistema

```mermaid
flowchart LR
  user[notebook do usuário<br/>servidor vnc ativo] --> web[painel web flask]
  web --> auth[auth mock dev<br/>ad/ldap em prod]
  web --> connect[/conectar]
  connect --> devview[/vnc-view<br/>emulação dev]
  connect --> viewer[xtightvncviewer<br/>produção]
  idle[/projetor<br/>arte 24/7] --> hdmi[projetor hdmi]
  devview --> hdmi
  viewer --> hdmi
```

se o github não renderizar o diagrama acima, a arquitetura equivalente é:

```text
notebook do usuário → flask na box → auth → conectar → vnc/emulação → hdmi/projetor
```

---

## 🧱 arquitetura atual

| camada | branch dev |
|---|---|
| app web | `app/app.py`, flask com templates inline |
| autenticação | mock em `dev`; ad/ldap em produção |
| vnc | simulado em dev; `xtightvncviewer` real em produção |
| tela idle | `/projetor`, fullscreen, 24/7 |
| emulação | `/vnc-view`, experiência visual tightvnc em dev |
| display | xorg `:0` + lightdm + openbox/xfwm4 |
| hardware alvo | rk3229, armv7, ~1 gb ram |
| observabilidade | `/api/v1/status`, logs e `PERFORMANCE.md` |

---

## 🚀 modo dev local

rode fora da rede da ufrb, sem tocar na box real:

```bash
cd app
CARAPROJETADA_ENV=dev flask --app app:app run --host 127.0.0.1 --port 5000
```

atalho local no ambiente do deivison:

```bash
caraprojetadadev
```

### login dev

| usuário | senha | observação |
|---|---|---|
| `admin` | `admin` | administrador mock |
| qualquer usuário | `dev` | login rápido |
| `usuario` | `usuario` | usuário=senha |

### fluxo feliz

```text
abrir / → login admin/admin → painel sem "sp" → conectar tela
→ /vnc-view → validar emulação tightvnc → desconectar → /projetor livre
```

---

## 🖥️ telas novas da dev

### `/projetor` — arte idle 24/7

tela para ficar fixa no hdmi quando ninguém estiver conectado.

| elemento | função |
|---|---|
| identidade | sistema de projeções · ufrb · cetens |
| passos | como acessar, logar e conectar |
| url grande | `http://<ip-da-box>` |
| status | livre/ocupado + usuário ativo |
| relógio | referência visual contínua |
| polling | atualiza a cada 30s |

### `/vnc-view` — emulação da conexão

tela dev que mostra como a experiência do projetor se comporta quando alguém conecta.

| elemento | função |
|---|---|
| toolbar tightvnc | aparência do viewer real |
| led verde | conexão ativa |
| tempo decorrido | sessão em andamento |
| desktop simulado | área onde a tela real apareceria |
| botões | voltar ao painel / desconectar |

---

## 🛣️ rotas principais

| método | rota | modo | descrição |
|---|---|---|---|
| `GET` | `/` | dev/prod | login ou painel |
| `POST` | `/login` | dev/prod | autentica usuário |
| `POST` | `/logout` | dev/prod | encerra sessão web |
| `POST` | `/conectar` | dev/prod | simula ou inicia vnc |
| `POST` | `/desconectar` | dev/prod | libera projetor |
| `GET` | `/projetor` | dev/prod futuro | idle screen 24/7 |
| `GET` | `/vnc-view` | dev | emulação vnc |
| `GET` | `/api/v1/status` | dev/prod | status json |
| `POST` | `/api/dev/reset` | dev | limpa sessão atual |

---

## 📦 estrutura

```text
caraprojetada/
├── app/
│   ├── app.py                 # flask, templates inline, auth, vnc, dev mode
│   └── requirements.txt       # flask + ldap3
├── scripts/
│   ├── switch_to_openbox.sh   # migração xfwm4 → openbox com revert
│   ├── kiosk.sh               # chromium fullscreen
│   ├── totem_guardian.sh      # health check frequente
│   ├── totem_watchdog.sh      # watchdog periódico
│   ├── totem_reset.sh         # reset emergencial gráfico
│   └── start_rtsp.sh          # rtsp opcional
├── systemd/                   # serviços
├── docs/                      # documentação html legada/online
├── assets/                    # logos e imagens
├── AGENTS.md                  # instruções locais para agentes
├── PERFORMANCE.md             # metas e checklist de desempenho
├── SPEC.md                    # especificação técnica
└── README.md
```

---

## ⚡ desempenho

o alvo real é pequeno. toda melhoria visual precisa ser validada no rk3229 antes de ir para `main`.

| métrica | alvo inicial |
|---|---|
| cpu idle flask | `< 5%` |
| memória sem vnc | `< 120 mb` |
| memória com vnc | `< 180 mb` somando viewer |
| temperatura | ideal `< 75°c` |
| tempo de conexão | `< 3s` |
| polling da tela idle | não agressivo, hoje 30s |

ver detalhes em [`PERFORMANCE.md`](./PERFORMANCE.md).

---

## 🧪 comandos úteis

```bash
# verificar sintaxe
python3 -m py_compile app/app.py

# status dev
curl -s http://127.0.0.1:5000/api/v1/status | python3 -m json.tool

# reset dev
curl -s -X POST http://127.0.0.1:5000/api/dev/reset | python3 -m json.tool

# recursos no hardware real
ssh caraprojetada 'free -h; uptime; df -h /; cat /sys/class/thermal/thermal_zone0/temp'
```

---

## 🧩 próximos passos

- [x] modo dev local.
- [x] login mock.
- [x] emulação vnc.
- [x] arte idle do projetor.
- [x] remover retângulo roxo `sp`.
- [x] docs separadas para `dev` e `main`.
- [ ] amanhã: melhorar telas e menus.
- [ ] amanhã: testar na rede 172 com notebook real.
- [ ] medir cpu/ram/temperatura da tela `/projetor`.
- [ ] migrar commits da `dev` para `main` em blocos pequenos.

---

## 🔒 notas de segurança

- manter o repositório privado.
- não promover `CARAPROJETADA_ENV=dev` para produção.
- não expor credenciais ou dados sensíveis.
- validar ad/ldap real antes de qualquer merge para `main`.

<p align="center">
  <strong>caraprojetada</strong> · ufrb/cetens · rk3229 · dev branch
</p>
