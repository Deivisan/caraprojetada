# 🎯 caraprojetada

subsistema embarcado para transformar uma tv box rk3229 em um ponto de projeção institucional com login ad/ldap, controle vnc reverso, tela de projetor 24/7 e modo dev com emulação visual da experiência real.

> branch atual: `dev`  
> estado: desenvolvimento ativo, com modo dev local, emulação vnc e tela idle do projetor.

---

## visão rápida

| área | estado na branch dev |
|---|---|
| app web | flask em `app/app.py` |
| auth | mock em dev, ad/ldap em produção |
| vnc | simulado em dev, `xtightvncviewer` em produção |
| tela do projetor | `/projetor`, fullscreen, 24/7 |
| emulação vnc | `/vnc-view`, somente dev |
| wm alvo | migração preparada para openbox, com fallback xfwm4 |
| hardware alvo | rockchip rk3229, armv7, 1 gb ram |

---

## arquitetura atual

```text
notebook do usuário
  ├─ acessa http://<ip-da-box>/
  ├─ autentica com siape/senha
  └─ roda servidor vnc local
              │
              ▼
carapreta-box / rk3229
  ├─ flask :80 em produção / :5000 em dev
  ├─ /              login + painel de controle
  ├─ /projetor      arte idle 24/7 para o projetor
  ├─ /conectar      inicia/simula conexão vnc
  ├─ /vnc-view      emulação visual da conexão (dev)
  ├─ /api/v1/status status json
  ├─ xorg :0 + lightdm
  ├─ openbox ou xfwm4
  └─ xtightvncviewer conectado ao notebook
              │
              ▼
projetor hdmi
  ├─ idle screen quando livre
  └─ tela do notebook quando conectado
```

---

## modo dev local

o modo dev permite desenvolver fora da rede ufrb e sem tocar no hardware real.

```bash
cd app
CARAPROJETADA_ENV=dev flask --app app:app run --host 127.0.0.1 --port 5000
```

atalho local já criado no ambiente do deivison:

```bash
caraprojetadadev
```

### login dev

| usuário | senha |
|---|---|
| `admin` | `admin` |
| qualquer usuário | `dev` |
| `usuario` | `usuario` |

### urls principais em dev

| url | função |
|---|---|
| `http://127.0.0.1:5000/` | login/painel |
| `http://127.0.0.1:5000/projetor` | tela idle do projetor |
| `http://127.0.0.1:5000/vnc-view` | emulação vnc, após conectar |
| `http://127.0.0.1:5000/api/v1/status` | status json |

### fluxo dev esperado

```text
abrir / → login admin/admin → painel limpo sem "sp" → conectar tela
→ /vnc-view → ver emulação tightvnc → desconectar
```

---

## produção esperada

em produção, `CARAPROJETADA_ENV` fica ausente ou `prod`.

```text
flask porta 80
ad/ldap real
xtightvncviewer real
log em /var/log/projetor-acessos.log
/api/dev/reset indisponível
/vnc-view redireciona para /
```

variáveis relevantes:

| variável | padrão | uso |
|---|---|---|
| `CARAPROJETADA_ENV` | `prod` | ativa `dev` quando igual a `dev` |
| `SECRET_KEY` | valor interno | cookie flask |
| `AD_SERVER` | `ldap://10.198.1.2` | servidor ldap |
| `AD_DOMAIN` | `intranet.ufrb.edu.br` | domínio institucional |
| `AD_BASE_DN` | `dc=intranet,dc=ufrb,dc=edu,dc=br` | base dn |
| `LOG_FILE` | `/var/log/projetor-acessos.log` | auditoria |
| `PORT` | `5000` em dev, `80` em prod | porta flask |
| `HOST` | `127.0.0.1` em dev, `0.0.0.0` em prod | bind |

---

## tela do projetor 24/7

a rota `/projetor` é a arte que deve ficar em fullscreen na box enquanto ninguém está conectado.

ela mostra:

- identidade do sistema: sistema de projeções, ufrb, cetens
- passos para conectar
- endereço grande: `http://<ip-da-box>`
- status livre/ocupado
- relógio
- animações leves
- polling de status a cada 30s

atenção: amanhã, quando melhorar telas e menus, validar essa tela no rk3229 real para garantir que as animações não aumentem cpu/temperatura.

---

## emulação vnc dev

a rota `/vnc-view` simula a experiência visual do projetor após conectar:

- toolbar tightvnc
- ip/display conectado
- indicador verde de conexão
- tempo decorrido
- desktop simulado
- watermark `dev mode`
- botão voltar ao painel
- botão desconectar

em produção, essa tela não é usada; o `xtightvncviewer` real assume o display hdmi.

---

## estrutura do projeto

```text
caraprojetada/
├── app/
│   ├── app.py              # flask, templates inline, auth, vnc, dev mode
│   └── requirements.txt    # flask + ldap3
├── scripts/
│   ├── switch_to_openbox.sh # migração xfwm4 → openbox com revert
│   ├── kiosk.sh             # chromium fullscreen
│   ├── totem_guardian.sh    # health check frequente, wm-agnóstico
│   ├── totem_watchdog.sh    # health check periódico, wm-agnóstico
│   ├── totem_reset.sh       # reset emergencial gráfico
│   └── start_rtsp.sh        # streaming rtsp opcional
├── systemd/
│   ├── projetor.service
│   └── stream-cam.service
├── docs/                    # documentação html legada/online
├── assets/                  # logos e imagens
├── DEVICE_CONTEXT.md        # snapshot da box real
├── SPEC.md                  # especificação técnica
├── PERFORMANCE.md           # notas de desempenho
├── AGENTS.md                # instruções locais para agentes
└── README.md
```

---

## endpoints

| método | rota | descrição |
|---|---|---|
| `GET` | `/` | login ou painel |
| `POST` | `/login` | autenticação |
| `POST` | `/logout` | encerra sessão |
| `POST` | `/conectar` | conecta/simula vnc |
| `POST` | `/desconectar` | libera projetor |
| `GET` | `/projetor` | idle screen 24/7 |
| `GET` | `/vnc-view` | emulação vnc dev |
| `GET` | `/api/v1/status` | status do projetor |
| `POST` | `/api/dev/reset` | reset dev, somente `CARAPROJETADA_ENV=dev` |

---

## desempenho: pontos de atenção

hardware alvo é limitado: rk3229, armv7 32-bit, ~1 gb ram e armazenamento emmc pequeno. cada decisão de ui precisa respeitar isso.

metas iniciais:

| métrica | alvo |
|---|---|
| flask idle | baixo uso de cpu, ideal `< 5%` |
| memória app | ideal `< 120 mb` sem vnc |
| sessão vnc | ideal `< 180 mb` somando viewer |
| temperatura | manter abaixo de `75°c` |
| conexão vnc | abrir em até `3s` após clique |
| idle screen | animações sem travar e sem aquecer |

ver também: [`PERFORMANCE.md`](./PERFORMANCE.md)

---

## comandos úteis

```bash
# sintaxe python
python3 -m py_compile app/app.py

# status dev
curl -s http://127.0.0.1:5000/api/v1/status | python3 -m json.tool

# reset dev
curl -s -X POST http://127.0.0.1:5000/api/dev/reset | python3 -m json.tool

# produção: status serviço
ssh caraprojetada 'systemctl status projetor --no-pager'

# produção: logs
ssh caraprojetada 'tail -f /var/log/projetor-acessos.log'

# produção: recursos
ssh caraprojetada 'free -h; uptime; df -h /; cat /sys/class/thermal/thermal_zone0/temp'
```

---

## roadmap imediato

- [x] modo dev local
- [x] auth mock dev
- [x] vnc simulado dev
- [x] emulação visual vnc
- [x] idle screen `/projetor`
- [x] remover retângulo roxo `sp`
- [x] scripts openbox/wm-agnósticos
- [ ] amanhã: lapidar telas e menus
- [ ] amanhã: testar na rede 172 com hardware real
- [ ] migrar gradualmente da branch `dev` para `main`
- [ ] medir impacto da tela `/projetor` na cpu/temperatura real

---

## notas importantes

- `main` deve permanecer segura para produção.
- `dev` pode conter emulação e telas experimentais.
- não misturar credenciais reais em commits públicos.
- repo deve permanecer privado por conter contexto de rede/dispositivo.
- antes de migrar para `main`, testar na rede ufrb com notebook real + servidor vnc ativo.
