# instruções locais para agentes — caraprojetada (branch dev)

este arquivo orienta agentes trabalhando dentro deste repositório. vale para a branch `dev`.

## idioma e estilo

- responder em pt-br.
- usar minúsculas em paths e comandos quando possível.
- preferir cli first.
- preferir bun quando existir js, mas este projeto é principalmente python/flask.
- ser autônomo: executar, testar, documentar e commitar quando solicitado.

## contexto do projeto

- projeto: `caraprojetada`.
- branch de desenvolvimento: `dev`.
- branch estável/prod: `main`.
- hardware alvo: tv box rockchip rk3229, armv7 32-bit, ~1 gb ram.
- sistema alvo: armbian bullseye, kernel 4.4 legacy por enquanto.
- função: projetor institucional controlado por flask + vnc reverso + autenticação ad/ldap.

## regras de segurança

- não expor ip, senha, ad ou dados sensíveis fora do repositório privado.
- não transformar `CARAPROJETADA_ENV=dev` em padrão de produção.
- `CARAPROJETADA_ENV` padrão deve continuar `prod`.
- rotas dev devem ficar indisponíveis em produção quando aplicável.
- não executar comandos destrutivos no dispositivo real sem confirmação explícita.

## modo dev

ativar com:

```bash
CARAPROJETADA_ENV=dev
```

efeitos:

- login mock: `admin/admin`, qualquer usuário com senha `dev`, ou usuário=senha.
- `ldap3` é opcional.
- vnc não executa viewer real; registra o comando e mostra emulação.
- `/api/dev/reset` fica disponível.
- `/vnc-view` fica disponível.

rodar local:

```bash
cd app
CARAPROJETADA_ENV=dev flask --app app:app run --host 127.0.0.1 --port 5000
```

fluxo mínimo de teste:

1. abrir `http://127.0.0.1:5000/`.
2. login `admin/admin`.
3. confirmar painel sem retângulo roxo `sp`.
4. clicar em conectar.
5. confirmar redirect para `/vnc-view`.
6. abrir `/projetor` e validar idle screen.
7. chamar `/api/v1/status`.
8. desconectar e confirmar status livre.

## arquivos críticos

- `app/app.py`: core flask; contém templates inline grandes.
- `scripts/switch_to_openbox.sh`: migração xfwm4 → openbox com `--revert`.
- `scripts/totem_guardian.sh`: watchdog frequente, wm-agnóstico.
- `scripts/totem_watchdog.sh`: watchdog periódico, wm-agnóstico.
- `scripts/totem_reset.sh`: reset gráfico emergencial.
- `DEVICE_CONTEXT.md`: contexto real da box, tratar como sensível.
- `SPEC.md`: especificação técnica.
- `PERFORMANCE.md`: observabilidade e metas de desempenho.

## cuidado com `app/app.py`

- `LOGIN_HTML`, `CONTROL_HTML`, `PROJECTOR_IDLE_HTML` e `VNC_VIEWER_HTML` são strings inline.
- evitar edições grandes sem rodar `python3 -m py_compile app/app.py`.
- cuidado com indentação python e aspas dentro dos templates.
- não remover templates acidentalmente.
- ao alterar `/conectar`, preservar atualização de `current_session` antes de qualquer redirect.

## desempenho

atenção especial porque o alvo tem poucos recursos.

- evitar javascript pesado na tela `/projetor`.
- animações devem ser leves e testadas no rk3229 real.
- evitar polling agressivo; hoje `/projetor` usa 30s.
- evitar dependências python pesadas.
- evitar threads/processos permanentes extras.
- em produção, medir cpu, ram, temperatura e tempo de conexão vnc.

metas iniciais:

- flask idle: cpu baixa, ideal `< 5%`.
- memória sem vnc: ideal `< 120 mb`.
- memória com vnc: ideal `< 180 mb` somando viewer.
- temperatura: ideal `< 75°c`.
- conexão vnc: ideal `< 3s`.

## comandos de verificação

```bash
python3 -m py_compile app/app.py
curl -s http://127.0.0.1:5000/api/v1/status | python3 -m json.tool
curl -s -X POST http://127.0.0.1:5000/api/dev/reset | python3 -m json.tool
```

## estratégia de branch

- desenvolver e experimentar na `dev`.
- amanhã, na rede 172, testar no hardware real.
- migrar para `main` aos poucos, commit por commit ou por blocos pequenos.
- antes de mergear para `main`, validar login ad/ldap real, vnc real e tela idle no hdmi.
