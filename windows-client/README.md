# 🪟 Cliente Windows — caraprojetada

cliente windows para o sistema de projeção institucional (ufrb/cetens).

## abordagem atual (portátil)

não instalamos mais nada e não baixamos nada. usamos o binário
**`tvnserver.exe`** (tightvnc server+client 2.8.88, portátil) que já
acompanha este cliente.

### como funciona

1. o usuário roda `start-tvnserver.cmd` (ou direto o `tvnserver.exe`).
2. abre a janela do tightvnc server.
3. em **administration** o usuário define a **senha do vnc**.
4. essa senha é exatamente o **PIN** que ele digita no painel do projetor.
5. mantenha a janela aberta durante a projeção.

### comando

```batch
start-tvnserver.cmd
```

o launcher apenas executa o `tvnserver.exe` ao lado — sem instalação,
sem registro, sem serviço, sem download.

### fluxo no projetor

- a box roda `xtightvncviewer` e passa o PIN como senha (`-autopass`).
- o PIN precisa bater com a senha definida na GUI do tightvnc.
- display padrão windows: `0` (porta 5900).

---

## arquivos

| arquivo | descrição |
|---------|-----------|
| `caraprojetada-vnc.exe` | tightvnc server+client portátil (2.8.88) — nome fixo |
| `start-tvnserver.cmd` | launcher que roda o exe acima |
| `main.py` | cliente python que se registra no projetor |

## download (link fixo e permanente)

o binário está em um **release fixo** do github. o nome do asset nunca muda,
então o link abaixo **sempre** aponta para a versão mais recente:

```
https://github.com/Deivisan/caraprojetada/releases/latest/download/caraprojetada-vnc.exe
```

para atualizar o binário: basta subir um novo asset com o mesmo nome
`caraprojetada-vnc.exe` no release mais recente. o link não precisa mudar.

esse link é exibido na própria interface web do projetor (antes do login),
para o usuário baixar em um clique.

---

## legado (obsoleto)

os scripts abaixo eram da abordagem antiga (instalar tightvnc via msi /
ultravnc). **não são mais usados** com a abordagem portátil:

- `definitive-tightvnc.bat` (removido)
- `install_vnc.ps1`
- `quick_setup_ultravnc.ps1`
- `WINDOWS_VNC_SETUP.md`, `WIN11_COMMANDS.txt`, `WIN11_ONE_CLICK_SETUP.txt`
- `provisioning/` (ultravnc)

mantidos apenas como referência histórica.

---

## compatibilidade

servidor vnc precisa estar **ativo** no notebook antes de clicar em
"conectar" no painel. testado no windows 11.
