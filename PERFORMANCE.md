# desempenho e observabilidade — caraprojetada

este documento registra os pontos que precisamos acompanhar para manter o sistema leve no rk3229.

## contexto do hardware alvo

| item | valor |
|---|---|
| soc | rockchip rk3229 |
| cpu | 4× cortex-a7, armv7 32-bit |
| ram | ~1 gb |
| storage | emmc ~8 gb |
| vídeo | hdmi, resolução real observada 1360×768 (script força 1440×900) |
| sistema | armbian bullseye, kernel 4.4 legacy |

## orçamento de recursos

| componente | meta inicial |
|---|---|
| flask app idle | `< 120 mb` rss |
| flask + webrtc ativo | `< 180 mb` total adicional |
| cpu idle geral | `< 5%` |
| cpu com display / display room | `< 10%` |
| cpu com webrtc ativo | aceitável até `30%`, observar picos |
| temperatura | ideal `< 75°c`, investigar acima disso |
| espaço livre `/` | manter `> 1 gb` |
| logs zram | não saturar `/var/log` |

## pontos sensíveis

### 1. tela `/display`

- fica 24/7 no hdmi.
- fundo gradiente + svg ufrb + dot pulsante.
- sem animações css pesadas (sem partículas, sem blur).
- relógio atualiza a cada 60s (setinterval leve).
- quando ocioso, só o background estático + svg + relógio.
- quando ativo, video element + webrtc pc.
- se cpu subir demais no hardware real, reduzir gradiente para cor sólida.

### 2. webrtc

- `rtcpeerconnection` consome ram/cpu enquanto ativo.
- frame rate ideal 15fps (não 30) no `getDisplayMedia`.
- resolução ideal 1920×1080 (downscale se necessário).
- dependência crítica: stun server (google stun público).
- sem turn server — só funciona na mesma rede (172.17.x.x).
- prioridade: conexão rápida e estabilidade, não qualidade máxima.

### 3. window manager

- openbox é preferível por ser mais leve que xfwm4.
- scripts atuais são wm-agnósticos para não quebrar fallback.
- sem compositor (--compositor=off no openbox) para economizar gpu.

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

# processos gráficos
ssh caraprojetada 'pgrep -a "Xorg|openbox|chromium"'

# logs recentes
ssh caraprojetada 'tail -n 100 /var/log/projetor-acessos.log'
```

## validação na rede 172

checklist para quando estiver na rede 172:

- [ ] abrir `http://172.17.28.179/`.
- [ ] validar login ad/ldap real.
- [ ] abrir `/display` no hdmi da box.
- [ ] medir cpu com `/display` parado por 5 minutos.
- [ ] conectar notebook real via webrtc (compartilhar tela).
- [ ] medir tempo até aparecer o vídeo no projetor.
- [ ] desconectar e confirmar volta para idle screen.
- [ ] medir temperatura após 15 minutos de transmissão.
- [ ] testar guardian/watchdog sem interromper usuário.
- [ ] decidir quais commits da `dev` migram para `main`.

## decisões de otimização pendentes

- confirmar se gradiente no `/display` impacta cpu no rk3229 (testar cor sólida).
- reduzir resolução de captura se cpu do display ficar alta.
- revisar necessidade de stun/turn para跨 rede.
- confirmar openbox como padrão definitivo (vs xfwm4).
- manter kernel 4.4 por enquanto; kernel 6.6/caraazul fica fora do escopo imediato.