# metodologia — xbox app, linux e separação de contas

> estudo operacional. **não salvar e-mail, senha, token, recovery code ou cookie de conta microsoft neste repositório**, mesmo privado.

## 1. objetivo

queremos entender como usar no linux uma experiência próxima ao app xbox/windows, com duas ideias separadas:

1. **conta proprietária / store**: conta que possui assinatura, compra, game pass ou licença.
2. **conta de jogo / perfil pessoal**: conta usada para jogar, gamepad, conquistas, saves e presença.

o objetivo é evitar jogar diretamente na conta proprietária quando ela for apenas a conta que comprou/possui os jogos.

## 2. conclusão técnica inicial

o **app xbox de pc é nativo de windows 10/11** e depende de componentes do windows/microsoft store/gaming services. no linux puro, não há instalação equivalente funcional do app xbox pc com suporte completo a:

- microsoft store backend;
- gaming services;
- download/instalação de jogos game pass pc;
- msix/uwp/appx do xbox app;
- integração nativa de identidade microsoft store + xbox app.

portanto, empacotar em **electron** no linux só resolve a parte web/cloud (`xbox.com/play`), não o app xbox pc nativo nem o microsoft store backend.

## 3. caminhos possíveis

### opção a — xbox cloud gaming via web/electron/pwa

| item | avaliação |
|---|---|
| funciona no linux | ✅ sim |
| usa navegador/electron | ✅ sim |
| suporta controle/gamepad | ✅ sim, via browser |
| instala jogos localmente | ❌ não |
| microsoft store backend | ❌ não |
| melhor uso | cloud gaming, teste rápido, biblioteca cloud |

arquitetura:

```text
linux
  └─ edge/chromium/electron wrapper
      └─ https://www.xbox.com/play
          └─ login microsoft da conta desejada
              └─ streaming cloud
```

vantagem: simples, controlável e linux-native na prática.  
limite: não instala jogos pc game pass localmente.

### opção b — windows vm com gpu passthrough

| item | avaliação |
|---|---|
| app xbox nativo | ✅ sim |
| microsoft store backend | ✅ sim |
| separação store/xbox app | ✅ possível, mas depende do jogo/app |
| performance | ✅ boa se gpu passthrough estiver correto |
| complexidade | alta |

arquitetura:

```text
linux host
  └─ kvm/qemu windows 11
      ├─ microsoft store logada na conta proprietária
      ├─ xbox app logado na conta de jogo/pessoal
      └─ jogos instalados/rodando nativamente no windows
```

é a opção mais correta se a exigência for app xbox pc real + store real.

### opção c — dual boot windows/linux

mais simples que vm passthrough. melhor compatibilidade. menos elegante.

### opção d — pc windows remoto + streaming

usar uma máquina windows real com xbox app instalado e transmitir para linux via parsec/moonlight/steam remote play. boa opção se existir hardware windows disponível.

### opção e — wine/bottles/proton

não é recomendado para o app xbox pc/microsoft store. wine/proton pode rodar muitos jogos win32, mas não substitui microsoft store/gaming services de forma confiável.

## 4. separação de contas microsoft/store/xbox

no windows, existe historicamente a ideia de usar:

- microsoft store com a conta que possui licença/assinatura;
- xbox app ou perfil xbox com outra conta.

mas isso **não é garantia universal**. alguns jogos exigem a mesma conta na store e no xbox app; outros permitem alternar. políticas mudam com versões do xbox app, microsoft store e gaming services.

metodologia correta:

1. criar uma matriz de jogos-alvo;
2. testar cada jogo com store na conta proprietária;
3. testar xbox app/perfil com conta pessoal;
4. registrar se abre, se salva, se libera multiplayer, se mantém conquistas e se exige mesma conta.

modelo de tabela:

| jogo | store/proprietária | xbox/perfil pessoal | instala | abre | saves | multiplayer | exige mesma conta | observações |
|---|---|---|---|---|---|---|---|---|
| exemplo | conta proprietária | conta pessoal | ? | ? | ? | ? | ? | ? |

## 5. como empacotar a opção web no linux

se a decisão for cloud gaming, criar um wrapper electron ou pwa com perfil isolado.

### requisitos

- chromium/edge ou electron;
- suporte a gamepad via navegador;
- perfil de usuário separado para não misturar cookies microsoft;
- sem salvar cookies no git.

### modelo de execução com chromium

```bash
chromium \
  --user-data-dir="$HOME/.local/share/deivibox/xbox-cloud-profile" \
  --app="https://www.xbox.com/play" \
  --enable-features=VaapiVideoDecodeLinuxGL \
  --ozone-platform=x11
```

### modelo electron

```text
deivibox-xbox-cloud/
  package.json
  main.js
  preload.js
  assets/
```

o `main.js` abre `https://www.xbox.com/play` com sessão persistente local no diretório do usuário, nunca dentro do repo.

## 6. armazenamento seguro das contas

não salvar segredos no repo. usar:

- password manager;
- `pass`/gopass;
- keepassxc;
- secret service/libsecret;
- arquivo local ignorado por git, se inevitável.

modelo permitido no repo:

```text
conta proprietária: [registrar no password manager]
conta pessoal/jogo: [registrar no password manager]
2fa: [registrar método, não o código]
recovery codes: [fora do git]
```

## 7. plano recomendado

### fase 1 — web/cloud no linux

1. criar wrapper chromium/electron isolado;
2. validar gamepad;
3. validar login/logout de contas;
4. medir latência e qualidade;
5. decidir se cloud atende.

### fase 2 — windows real/virtual para app xbox nativo

1. instalar windows 11 em vm ou máquina dedicada;
2. instalar app xbox e gaming services;
3. login microsoft store com conta proprietária;
4. login xbox app/perfil com conta pessoal;
5. testar matriz de jogos.

### fase 3 — integração de experiência

1. se cloud for suficiente: empacotar electron/pwa;
2. se app nativo for obrigatório: manter windows vm/dual boot/streaming;
3. documentar por jogo o comportamento de contas.

## 8. decisão atual

- para linux puro: **usar web/cloud via pwa/electron**.
- para xbox app completo + store backend: **usar windows real ou vm windows**.
- não tentar instalar microsoft store/xbox app nativo direto no linux via wine como solução principal.
