# instruções locais para agentes — caraprojetada (branch main)

este arquivo vale para agentes trabalhando na branch `main` do repositório.

## papel da branch main

- `main` é a linha estável/produção.
- não trazer experimentos da `dev` sem validação no hardware real.
- mudanças na `main` devem ser pequenas, testáveis e reversíveis.
- preservar comportamento de produção: ad/ldap real e vnc real.

## idioma e estilo

- responder em pt-br.
- usar cli first.
- preferir comandos simples e auditáveis.
- documentar qualquer decisão que afete produção.

## contexto técnico

- hardware alvo: rockchip rk3229, armv7 32-bit, ~1 gb ram.
- sistema: armbian bullseye, kernel 4.4 legacy.
- serviço principal: flask porta 80.
- display: xorg `:0`, lightdm e window manager leve.
- vnc: box é cliente; notebook do usuário é servidor.
- autenticação: ad/ldap institucional.

## arquivos críticos

- `app/app.py`: aplicação flask, autenticação, painel e controle vnc.
- `systemd/projetor.service`: serviço principal.
- `scripts/totem_guardian.sh`: recuperação frequente.
- `scripts/totem_watchdog.sh`: watchdog periódico.
- `scripts/totem_reset.sh`: reset gráfico emergencial.
- `DEVICE_CONTEXT.md`: dados sensíveis do dispositivo real.
- `SPEC.md`: especificação técnica.
- `PERFORMANCE.md`: métricas e checklist de desempenho.

## segurança

- não publicar credenciais ou ip interno em locais externos.
- manter repo privado.
- não trocar defaults de produção sem motivo.
- não ativar modo dev por padrão na `main`.
- não remover autenticação ad/ldap.
- não executar comandos destrutivos no hardware real sem confirmação explícita.

## performance

atenção: o alvo tem recursos limitados.

- evitar ui pesada.
- evitar dependências novas sem necessidade.
- evitar polling agressivo.
- evitar logs verbosos permanentes.
- medir cpu, ram e temperatura antes de promover mudanças da `dev`.

metas:

- cpu idle `< 5%`.
- app sem vnc `< 120 mb`.
- vnc ativo com uso aceitável e sem swap excessiva.
- temperatura ideal `< 75°c`.
- conexão vnc `< 3s` após clique.

## validação mínima antes de commit na main

```bash
python3 -m py_compile app/app.py
```

se estiver na rede/hardware real:

```bash
ssh caraprojetada 'systemctl status projetor --no-pager'
ssh caraprojetada 'uptime; free -h; df -h /; cat /sys/class/thermal/thermal_zone0/temp'
curl -s http://172.17.28.179/api/v1/status | python3 -m json.tool
```

## migração da dev para main

- migrar aos poucos.
- preferir cherry-pick seletivo em vez de merge grande.
- validar login ad/ldap real.
- validar vnc real com notebook na rede.
- validar impacto visual e térmico antes de promover telas novas.
