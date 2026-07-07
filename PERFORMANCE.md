# desempenho e observabilidade — produção

este documento lista o que observar antes de promover mudanças para a `main` e durante testes no rk3229.

## orçamento de recursos

| métrica | alvo inicial |
|---|---|
| cpu idle | `< 5%` |
| memória do app | `< 120 mb` |
| memória com vnc | observar, ideal sem swap pesada |
| temperatura | ideal `< 75°c` |
| tempo até conectar vnc | `< 3s` |
| espaço livre `/` | `> 1 gb` |

## riscos principais

1. ui animada demais pode aquecer a box.
2. vnc pode consumir cpu alto em rede ruim.
3. logs em zram podem saturar `/var/log`.
4. chromium/kiosk pode pesar mais que o necessário.
5. kernel 4.4 legacy limita drivers e estabilidade.

## comandos de medição

```bash
ssh caraprojetada 'uptime; free -h; df -h /; cat /sys/class/thermal/thermal_zone0/temp'
ssh caraprojetada 'ps -eo pid,ppid,comm,%cpu,%mem,rss --sort=-%mem | head -20'
ssh caraprojetada 'pgrep -a "Xorg|lightdm|xfwm4|openbox|chromium|xtightvncviewer"'
ssh caraprojetada 'tail -n 100 /var/log/projetor-acessos.log'
```

## checklist para amanhã na rede

- [ ] abrir painel na rede 172.
- [ ] autenticar com ad/ldap real.
- [ ] conectar notebook real com servidor vnc ativo.
- [ ] medir tempo de conexão.
- [ ] medir cpu/ram antes, durante e depois da conexão.
- [ ] medir temperatura após 15 minutos.
- [ ] testar desconectar e reconectar.
- [ ] decidir quais commits da `dev` entram na `main`.
