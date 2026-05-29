# desempenho e observabilidade — caraprojetada

este documento registra os pontos que precisamos acompanhar para manter o sistema leve no rk3229.

## contexto do hardware alvo

| item | valor |
|---|---|
| soc | rockchip rk3229 |
| cpu | 4× cortex-a7, armv7 32-bit |
| ram | ~1 gb |
| storage | emmc ~8 gb |
| vídeo | hdmi, resolução real observada 1360×768 |
| sistema | armbian bullseye, kernel 4.4 legacy |

## orçamento de recursos

| componente | meta inicial |
|---|---|
| flask app idle | `< 120 mb` rss |
| flask + sessão vnc | `< 180 mb` total adicional |
| cpu idle geral | `< 5%` |
| cpu com idle screen | `< 10%` |
| cpu com vnc ativo | aceitável até `30%`, observar picos |
| temperatura | ideal `< 75°c`, investigar acima disso |
| espaço livre `/` | manter `> 1 gb` |
| logs zram | não saturar `/var/log` |

## pontos sensíveis

### 1. tela `/projetor`

- fica 24/7 no hdmi.
- tem animações css e partículas.
- precisa ser visual, mas não pode aquecer a box.
- se cpu subir demais no hardware real, reduzir partículas, sombras, blur e polling.

### 2. vnc viewer

- `xtightvncviewer` consome ram/cpu enquanto ativo.
- depende da qualidade da rede e do servidor vnc no notebook.
- prioridade: conexão rápida e estabilidade, não efeitos visuais.

### 3. window manager

- openbox é preferível por ser mais leve que xfwm4.
- scripts atuais são wm-agnósticos para não quebrar fallback.
- medir ganho real após migração no hardware.

### 4. logs

- `/var/log` está em zram pequena.
- evitar logs verbosos permanentes.
- logs de auditoria devem ser úteis e curtos.

## comandos para medir no hardware real

```bash
# panorama rápido
ssh caraprojetada 'uptime; free -h; df -h /; cat /sys/class/thermal/thermal_zone0/temp'

# processos pesados
ssh caraprojetada 'ps -eo pid,ppid,comm,%cpu,%mem,rss --sort=-%mem | head -20'

# flask/projetor
ssh caraprojetada 'systemctl status projetor --no-pager'

# processos gráficos/vnc
ssh caraprojetada 'pgrep -a "Xorg|openbox|xfwm4|chromium|xtightvncviewer"'

# logs recentes
ssh caraprojetada 'tail -n 100 /var/log/projetor-acessos.log'
```

## validação amanhã na rede

checklist para quando estiver na rede 172:

- [ ] abrir `http://172.17.28.179/`.
- [ ] validar login ad/ldap real.
- [ ] abrir `/projetor` no hdmi da box.
- [ ] medir cpu com `/projetor` parado por 5 minutos.
- [ ] conectar notebook real via vnc.
- [ ] medir tempo até aparecer a tela no projetor.
- [ ] desconectar e confirmar volta para idle screen.
- [ ] medir temperatura após 15 minutos.
- [ ] testar guardian/watchdog sem interromper usuário.
- [ ] decidir quais commits da `dev` migram para `main`.

## decisões de otimização pendentes

- reduzir ou manter partículas da idle screen.
- mover templates inline para arquivos separados quando estabilizar ui.
- decidir se flask puro basta em produção ou se vale usar gunicorn leve.
- revisar intervalo de polling da tela `/projetor`.
- confirmar openbox como padrão definitivo.
- manter kernel 4.4 por enquanto; kernel 6.6/caraazul fica fora do escopo imediato.
