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
- função: projetor institucional controlado por flask + **webrtc** (socket.io) + autenticação ad/ldap.
- arquitetura atual: WebRTC via socket.io — **não usa mais VNC reverso**.

## regras de segurança

- não expor ip, senha, ad ou dados sensíveis fora do repositório privado.
- não transformar `CARAPROJETADA_ENV=dev` em padrão de produção.
- `CARAPROJETADA_ENV` padrão deve continuar `prod`.
- não executar comandos destrutivos no dispositivo real sem confirmação explícita.

## modo dev

ativar com:

```bash
CARAPROJETADA_ENV=dev
```

efeitos:

- login mock: `admin/admin`, qualquer usuário com senha `dev`, ou usuário=senha.
- `ldap3` é opcional.
- socket.io roda em modo debug.

rodar local:

```bash
cd app
CARAPROJETADA_ENV=dev flask --app app:app run --host 127.0.0.1 --port 5000
```

fluxo mínimo de teste:

1. abrir `http://127.0.0.1:5000/`.
2. login `admin/admin`.
3. confirmar dashboard com salas e botão "Compartilhar Tela".
4. clicar em "Compartilhar Tela" e autorizar captura de tela do navegador.
5. abrir `/display` em outra aba (simula o projetor).
6. confirmar que o vídeo aparece na tela `/display`.
7. clicar "Parar Compartilhamento" e confirmar que a tela `/display` volta ao estado ocioso.
8. chamar `/api/v1/status` para validar sessão (se endpoint existir).

## arquivos críticos

- `app/app.py`: core flask + socket.io + webrtc (rotas web + eventos socket).
- `app/templates/login.html`: tela de login institucional.
- `app/templates/dashboard.html`: painel do professor com webrtc.
- `app/templates/display.html`: tela do projetor (chromium kiosk).
- `app/requirements.txt`: dependências python.
- `DEVICE_CONTEXT.md`: contexto real da box, tratar como sensível.
- `SPEC.md`: especificação técnica.
- `PERFORMANCE.md`: observabilidade e metas de desempenho.

## cuidado com `app/app.py`

- mantém rotas web + eventos socket.io no mesmo arquivo (~535 linhas).
- `active_sessions` é o estado global de sessões ativas.
- `last_offer` guarda a última SDP offer para reconexão do display.
- `heartbeats` rastreia display vivo.
- `_cleanup_loop` thread limpa sessões órfãs.
- eventos principais: `join`, `offer`, `answer`, `ice-candidate`, `session-start`, `session-end`.
- ao alterar eventos socket, manter compatibilidade com o template `display.html`.

## desempenho

atenção especial porque o alvo tem poucos recursos.

- evitar javascript pesado na tela `/display` (projetor).
- animações devem ser leves e testadas no rk3229 real.
- webrtc: frameRate ideal 15fps, max 30fps no dashboard.
- evitar dependências python pesadas.
- evitar threads/processos permanentes extras.
- em produção, medir cpu, ram, temperatura.

metas iniciais:

- flask idle: cpu baixa, ideal `< 5%`.
- memória sem stream: ideal `< 120 mb`.
- memória com stream webrtc: ideal `< 180 mb`.
- temperatura: ideal `< 75°c`.
- conexão webrtc: ideal `< 5s` para estabelecer.

## comandos de verificação

```bash
python3 -m py_compile app/app.py
curl -s http://127.0.0.1:5000/api/v1/status | python3 -m json.tool
```

## estratégia de branch

- desenvolver e experimentar na `dev`.
- testar no hardware real antes de migrar para `main`.
- migrar para `main` aos poucos, commit por commit ou por blocos pequenos.
- antes de mergear para `main`, validar login ad/ldap real, webrtc real e tela idle no hdmi.
