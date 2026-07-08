# caraprojetada — app android

app flutter que transforma qualquer celular android em um servidor vnc
reverso, permitindo espelhar a tela do celular no projetor da sala de aula
sem depender de notebook.

## arquitetura

```
┌─────────────────────────────────────────────┐
│               app flutter                     │
│  ┌─────────────────────────────────────────┐ │
│  │  onboarding (1x)                        │ │
│  │  - selecionar modo                      │ │
│  │    (reuniao / aula / apresentacao)      │ │
│  │  - escolher rede wifi                   │ │
│  │  - digitar PIN do projetor              │ │
│  │  - ler QR code da tela do totem         │ │
│  └──────────┬──────────────────────────────┘ │
│             ↓                                │
│  ┌─────────────────────────────────────────┐ │
│  │  engine vnc reverso                     │ │
│  │  (droidVNC-NG / rustVNC embutido)      │ │
│  │                                         │ │
│  │  - inicia servidor VNC local na         │ │
│  │    porta 5900 (qualquer disponivel)     │ │
│  │  - captura tela via MediaProjection     │ │
│  │    (android 5+)                         │ │
│  │  - envia frames pra box do projetor     │ │
│  │    como se fosse um notebook            │ │
│  └─────────────────────────────────────────┘ │
│                                             │
│  ┌─────────────────────────────────────────┐ │
│  │  adaptacao de tela                      │ │
│  │                                         │ │
│  │  - celular em modo retrato (vertical)   │ │
│  │  - projetor em modo paisagem            │ │
│  │    (horizontal)                         │ │
│  │  - letterbox / pillarbox ou escala      │ │
│  │    configurável                         │ │
│  │  - orientacao forçada landscape para    │ │
│  │    espelhamento sem borda               │ │
│  └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

## porque flutter e nao kotlin nativo

| criterio              | flutter     | kotlin      |
|-----------------------|-------------|-------------|
| prototipagem rapida   | alto        | medio       |
| codigo compartilhado  | ios+android | android so  |
| comunidade vnc        | pacotes     | nativo      |
| facilidade de mudar   | hot reload  | build lento |
| experiencia da equipe | ja existe   | aprender    |

a engine vnc reverso em si precisa ser nativa (droidVNC-NG usa c++/java),
mas o app como um todo (ui, onboarding, conexao) fica em flutter com
platform channels para invocar o servidor vnc nativo.

## fluxo de conexao

1. usuario abre o app, ve onboarding (primeira vez)
2. seleciona modo de uso
3. conecta-se a mesma rede do projetor (ou via qr code)
4. app inicia servidor vnc reverso local
5. app contacta api do totem (flask, porta 80) e informa:
   - ip do celular
   - porta vnc
   - resolucao atual
6. totem conecta no celular via xtightvncviewer (vnc reverso)
7. tela do celular aparece no projetor

## requisitos minimos

- android 8.0+
- camera (para ler qr code)
- wifi
- 50mb de armazenamento
- 256mb ram livre

## pacotes sugeridos (flutter)

| pacote                        | uso                         |
|-------------------------------|-----------------------------|
| `mobile_scanner`              | leitura de qr code          |
| `shared_preferences`          | persistir config            |
| `http`                        | chamar api do totem         |
| `flutter_background_service`  | manter servidor vnc ativo   |
| `wakelock_plus`               | nao deixar tela apagar      |
| `sensors_plus`                | detectar orientacao         |

## estrutura de diretorios (sugerida)

```
android/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── screens/
│   │   ├── onboarding/
│   │   │   ├── onboarding_screen.dart
│   │   │   └── step_*.dart
│   │   ├── home/
│   │   │   ├── home_screen.dart
│   │   │   └── connection_status.dart
│   │   └── settings/
│   │       └── settings_screen.dart
│   ├── services/
│   │   ├── vnc_server.dart       # platform channel
│   │   ├── totem_api.dart        # http client
│   │   └── screen_capture.dart   # MediaProjection
│   └── models/
│       ├── connection_info.dart
│       └── user_prefs.dart
├── android/
│   └── app/src/main/java/
│       └── .../vnc/              # engine nativa
│           ├── VncService.java
│           └── ScreenCapture.java
└── pubspec.yaml
```

## engine vnc nativa

o coracao do app e um servidor vnc embutido no apk.
duas opcoes:

- **droidVNC-NG** (recomendado): maduro, otimizado, usa MediaProjection,
  suporta rotação e múltiplas conexoes. licenca gplv3.
  - adaptar para rodar como servico interno em vez de app independente.
  - extrair biblioteca .so (libandroid_rfb.so) e integrar via jni.

- **rustVNC**: mais leve, menos testado, promissor para baixa latencia.
  - escrever bindings jni para rust -> kotlin -> flutter platform channel.

decisao final: usar droidVNC-NG como base inicial e migrar para rustVNC
se latencia for problema.
