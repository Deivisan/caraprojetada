# 🎯 caraprojetada

subsistema embarcado para transformar uma tv box rk3229 em um ponto de projeção institucional: login ad/ldap, controle web, vnc reverso e exibição da tela do usuário no projetor hdmi.

> branch atual: `main`  
> estado: base estável de produção. mudanças experimentais ficam na `dev` e devem migrar aos poucos após teste na rede/hardware real.

---

## visão rápida

| área | produção atual |
|---|---|
| hardware | rockchip rk3229, armv7, ~1 gb ram |
| sistema | armbian bullseye, kernel 4.4 legacy |
| app | flask em `app/app.py` |
| porta | `80` |
| autenticação | ad/ldap institucional |
| projeção | vnc reverso com `xtightvncviewer` |
| display | xorg `:0` + lightdm + wm leve |
| watchdog | scripts de guardian/watchdog/reset |

---

## arquitetura de produção

```text
notebook do usuário
  ├─ servidor vnc local ativo
  ├─ navegador acessa http://<ip-da-box>/
  └─ login com credenciais institucionais
              │
              ▼
carapreta-box / rk3229
  ├─ flask :80
  ├─ /              login ou painel
  ├─ /login         autenticação ad/ldap
  ├─ /conectar      inicia xtightvncviewer
  ├─ /desconectar   encerra viewer
  ├─ /api/v1/status status json
  ├─ xorg :0 + lightdm
  ├─ wm gráfico
  └─ watchdog/guardian
              │
              ▼
projetor hdmi
  └─ mostra o viewer vnc em tela cheia
```

---

## fluxo de uso

1. usuário acessa `http://<ip-da-box>/`.
2. informa siape/usuário e senha institucional.
3. sistema autentica via ad/ldap.
4. painel detecta ip e sistema operacional pelo user-agent.
5. usuário clica em conectar tela.
6. box mata viewer antigo, se houver.
7. box executa `xtightvncviewer <ip-do-usuario>:<display>` no display hdmi.
8. ao terminar, usuário desconecta pelo painel.

---

## endpoints atuais

| método | rota | descrição |
|---|---|---|
| `GET` | `/` | login ou painel |
| `POST` | `/login` | autenticação ad/ldap |
| `POST` | `/logout` | encerra sessão web |
| `POST` | `/conectar` | inicia conexão vnc reversa |
| `POST` | `/desconectar` | encerra viewer e libera projetor |
| `GET` | `/api/v1/status` | status json do projetor |
| `POST` | `/api/v1/force-disconnect` | força liberação via api |

> recursos experimentais da `dev`, como tela `/projetor` e emulação `/vnc-view`, devem migrar para `main` apenas depois de validação no hardware real.

---

## hardware alvo

| componente | especificação |
|---|---|
| soc | rockchip rk3229 |
| cpu | 4× cortex-a7 @ até 1.5 ghz |
| gpu | mali-400 mp2 |
| ram | ~1 gb ddr3 |
| storage | emmc ~8 gb |
| rede | ethernet 10/100 + wi-fi esp8089 |
| vídeo | hdmi |
| arquitetura | armv7 32-bit |

limitação central: o hardware é útil para tarefa dedicada, mas não tolera excesso de processos, ui pesada ou logs verbosos.

---

## estrutura do projeto

```text
caraprojetada/
├── app/
│   ├── app.py              # flask, ad/ldap, controle vnc
│   └── requirements.txt    # flask + ldap3
├── scripts/
│   ├── kiosk.sh            # chromium fullscreen opcional
│   ├── totem_guardian.sh   # health check frequente
│   ├── totem_watchdog.sh   # watchdog periódico
│   ├── totem_reset.sh      # reset emergencial gráfico
│   └── start_rtsp.sh       # rtsp opcional
├── systemd/
│   ├── projetor.service    # serviço flask porta 80
│   └── stream-cam.service  # serviço rtsp opcional
├── docs/                   # documentação html
├── assets/                 # imagens e logos
├── DEVICE_CONTEXT.md       # snapshot real da box
├── SPEC.md                 # especificação técnica
├── PERFORMANCE.md          # desempenho/observabilidade
├── AGENTS.md               # instruções locais para agentes
└── README.md
```

---

## deploy/execução

instalar dependências no alvo:

```bash
sudo apt update
sudo apt install -y python3 python3-flask python3-ldap3 xtightvncviewer xserver-xorg-core lightdm x11-utils
```

serviço esperado:

```bash
sudo systemctl status projetor --no-pager
sudo systemctl restart projetor
```

comando vnc usado pela aplicação:

```bash
echo "123456" | DISPLAY=:0 sudo /usr/bin/xtightvncviewer <ip-do-usuario>:<display> -autopass
```

---

## desempenho: pontos de atenção

metas iniciais para produção:

| métrica | alvo |
|---|---|
| cpu idle | `< 5%` |
| ram app sem vnc | `< 120 mb` |
| ram com vnc ativo | `< 180 mb` adicional, observar caso real |
| temperatura | ideal `< 75°c` |
| tempo de conexão | `< 3s` após clique |
| espaço livre em `/` | manter `> 1 gb` |

ver [`PERFORMANCE.md`](./PERFORMANCE.md) para checklist de validação.

---

## comandos úteis

```bash
# ssh
ssh caraprojetada

# status serviço
ssh caraprojetada 'systemctl status projetor --no-pager'

# logs do sistema/app
ssh caraprojetada 'tail -f /var/log/projetor-acessos.log'

# recursos
ssh caraprojetada 'uptime; free -h; df -h /; cat /sys/class/thermal/thermal_zone0/temp'

# processos gráficos
ssh caraprojetada 'pgrep -a "Xorg|lightdm|xfwm4|openbox|chromium|xtightvncviewer"'

# api status
curl -s http://172.17.28.179/api/v1/status | python3 -m json.tool
```

---

## estratégia de branches

- `main`: produção/estável.
- `dev`: experimentos, modo dev, telas novas, emulação e migração openbox.
- amanhã, na rede 172, validar a `dev` no hardware real.
- migrar para `main` aos poucos, preferindo commits pequenos e testáveis.
- não subir para `main` recursos visuais sem medir cpu/ram/temperatura na box.

---

## roadmap próximo

- [ ] validar no hardware real dentro da rede ufrb.
- [ ] medir desempenho da tela idle antes de migrar para `main`.
- [ ] melhorar telas e menus.
- [ ] migrar openbox gradualmente.
- [ ] revisar logs e auditoria.
- [ ] manter kernel 6.6/caraazul fora do escopo imediato.
