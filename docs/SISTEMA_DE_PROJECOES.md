# sistema de projeções — caraprojetada

> documento autoritativo da arquitetura atual.  
> **caraazul foi descontinuado. caraprojetada segue ativo e funcional.**

## 1. visão executiva

o `caraprojetada` transforma uma tv box rockchip rk3229 em um ponto de projeção institucional: a box fica ligada ao projetor via hdmi, exibe uma tela de instruções 24/7 e permite que usuários da rede institucional conectem a tela do notebook por vnc reverso, autenticando via ad/ldap.

o modelo atual é **descentralizado por box**: cada projetor possui sua própria interface flask na porta 80, seu próprio chromium em kiosk no hdmi e seu próprio guardian local.

```text
notebook do usuário
  └─ navegador acessa http://<ip-da-box>
      └─ flask autentica no ad/ldap
          └─ usuário clica conectar
              └─ box executa xtightvncviewer contra o ip do usuário
                  └─ imagem aparece no hdmi/projetor
```

## 2. status do projeto

| item | estado |
|---|---|
| projeto vivo | ✅ `caraprojetada` |
| projeto descontinuado | ❌ `caraazul` |
| box real em teste | ✅ `caraprojetada` / `carapreta-box` |
| ip atual da box | `172.17.28.179` |
| modo padrão | produção |
| branch de trabalho | `dev` |
| branch estável | `main` |

## 3. hardware alvo

| componente | valor |
|---|---|
| soc | rockchip rk3229/rk322x |
| arquitetura | armv7 32-bit / armhf |
| ram | ~1 gb |
| armazenamento | emmc ~8 gb |
| os | armbian bullseye |
| kernel | 4.4 legacy rk322x |
| vídeo | hdmi |
| display stack | lightdm + xorg + openbox + chromium kiosk |

## 4. componentes em produção

| componente | função |
|---|---|
| `projetor.service` | serviço systemd que sobe o flask em `/home/carapreta/app.py` na porta 80 |
| `app/app.py` | aplicação flask principal com templates inline |
| `/projetor` | tela idle 24/7 exibida no hdmi pelo chromium |
| `/api/v1/status` | status json para observabilidade e tela idle |
| `/conectar` | aciona conexão vnc reversa |
| `xtightvncviewer` | cliente vnc executado pela box contra o notebook do usuário |
| lightdm | gerenciador gráfico com auto-login |
| openbox | window manager leve sem compositor |
| chromium kiosk | navegador fullscreen apontado para `/projetor` |
| cron | agenda guardian, watchdog e monitoramento |
| `totem_guardian.sh` | garante xorg/openbox/chromium, sem matar chromium se já estiver rodando |
| `totem_watchdog.sh` | verificação periódica leve |
| `monitoring/` | coleta de estabilidade 24/7 |

## 5. fluxo operacional

### 5.1 boot da box

```text
energia ligada
  └─ systemd → graphical.target
      ├─ lightdm active
      │   └─ auto-login usuário carapreta
      │       └─ openbox
      ├─ projetor.service → flask :80
      └─ cron
          └─ totem_guardian.sh
              └─ chromium --kiosk http://localhost/projetor
```

### 5.2 tela hdmi em repouso

o chromium abre:

```text
http://localhost/projetor
```

mas a tela mostra ao usuário o ip real da box:

```text
http://172.17.28.179
```

a tela informa:

1. endereço para acessar;
2. autenticação com siape/senha institucional;
3. botão de conectar tela;
4. status livre/ocupado;
5. relógio.

o status é atualizado via `fetch('/api/v1/status')` a cada 30 segundos **sem recarregar a página**. o antigo `location.reload()` foi removido porque causava tela preta/branca/flicker.

### 5.3 conexão vnc reversa

1. usuário acessa `http://<ip-da-box>` no navegador;
2. faz login via ad/ldap;
3. painel detecta ip do usuário;
4. usuário clica em conectar;
5. box registra a sessão atual antes de executar o viewer;
6. box executa `xtightvncviewer` no display `:0`;
7. tela do notebook aparece no hdmi.

comando atual otimizado:

```bash
echo "123456" | DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0 \
  /usr/bin/xtightvncviewer <ip_usuario>:<display> \
  -autopass -quality 6 -compresslevel 9
```

## 6. rotas principais

| rota | método | função |
|---|---|---|
| `/` | get | login ou painel de controle |
| `/login` | post | autenticação ad/ldap |
| `/logout` | post | encerra sessão web |
| `/conectar` | post | inicia conexão vnc reversa |
| `/desconectar` | post | encerra viewer e libera projetor |
| `/projetor` | get | tela idle 24/7 no hdmi |
| `/api/v1/status` | get | status json de sessão/saúde |

rotas dev/emulação foram removidas da produção. `CARAPROJETADA_ENV` padrão deve continuar sendo `prod`.

## 7. decisões técnicas consolidadas

### 7.1 openbox em vez de xfce/xfwm4

motivo: menor consumo, sem compositor e menos travamentos na box rk3229.

### 7.2 tightvnc no windows

o caminho atual para cliente windows é tightvnc, não ultravnc. existe script de instalação em `windows-client/definitive-tightvnc.bat`.

### 7.3 chromium com perfil temporário

o kiosk usa:

```bash
--user-data-dir=/tmp/chromium-kiosk
```

isso evita restauração de sessão antiga, cache permanente e retorno da página uol do totem antigo.

### 7.4 kiosk antigo removido

o antigo `kiosk.sh` e o autostart `totem-kiosk.desktop` foram removidos/desativados. eles reiniciavam chromium com uol e sabotavam a tela do projetor.

### 7.5 guardian não mata chromium se já está rodando

bug corrigido: o guardian tinha `pkill -9 -f chrom` e reiniciava o chromium a cada minuto, gerando tela preta/branca. agora apenas inicia se não encontrar chromium kiosk rodando.

## 8. observabilidade e teste 24/7

a box possui monitoramento local em:

```text
/home/carapreta/monitoring/
```

coleta:

```cron
*/5 * * * * /home/carapreta/monitoring/bin/collect_metrics.sh >/dev/null 2>&1
7 */6 * * * /home/carapreta/monitoring/bin/generate_report.sh >/dev/null 2>&1
11 */6 * * * /home/carapreta/monitoring/bin/inventory_files.sh >/dev/null 2>&1
```

arquivos importantes:

| arquivo | função |
|---|---|
| `data/metrics.csv` | série temporal a cada 5 min |
| `data/alerts.log` | alertas de temperatura/disco/http/serviços/restart chromium |
| `reports/latest_report.txt` | relatório consolidado mais recente |
| `reports/latest_new_files.txt` | arquivos novos desde baseline |

resultado do primeiro teste de fim de semana:

| métrica | resultado |
|---|---|
| período | 29/05/2026 16:57 → 01/06/2026 09:02 |
| uptime | 2 dias, 19h43 |
| amostras | 773 |
| http `/projetor` | 0 falhas |
| serviços | 0 falhas |
| chromium restarts | 0 |
| disco `/` | estável em 70% |
| swap | praticamente zero |
| crescimento logs | +1.4 mb |
| crescimento `/home/carapreta` | +2.2 mb |
| temperatura média | 79.2 °c |
| temperatura máxima | 83.0 °c |
| amostras >=80 °c | 335 / 43.3% |

conclusão: **software estável; ponto de atenção é temperatura**.

## 9. riscos e próximos cuidados

| risco | nível | mitigação |
|---|---|---|
| temperatura alta | médio/alto | melhorar ventilação, dissipador, elevar box, reduzir animações |
| chromium pesado | médio | simplificar tela `/projetor`, reduzir animações/efeitos |
| disco 70% | médio | limpar pacotes/cache antigos antes de produção longa |
| dependência ad/ldap | operacional | validar em rede real antes de levar para sala |
| cliente windows | operacional | padronizar tightvnc e script de instalação |

## 10. comandos úteis

### estado atual

```bash
ssh caraprojetada 'systemctl is-active projetor lightdm cron; uptime; free -h; df -h / /var/log /tmp'
```

### relatório 24/7

```bash
ssh caraprojetada '/home/carapreta/monitoring/bin/package_reports.sh'
```

### copiar relatório

```bash
scp caraprojetada:/home/carapreta/monitoring/reports/caraprojetada_monitoring_*.tar.gz .
```

### reiniciar app flask

```bash
ssh caraprojetada 'sudo systemctl restart projetor'
```

### verificar janela no hdmi

```bash
ssh caraprojetada 'DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0 wmctrl -l'
```

## 11. regra de continuidade

o repositório `caraprojetada` é o projeto ativo para o sistema de projeções. qualquer migração futura para outro nome/repo deve preservar esta arquitetura, scripts e histórico operacional.

`caraazul` não deve ser usado como base desta solução.
