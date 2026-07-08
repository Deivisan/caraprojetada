# CaraProjetada — Contexto do Dispositivo

## Identificação

| Campo | Valor |
|-------|-------|
| **Hostname** | `carapreta-box` |
| **IP** | `172.17.28.179/16` |
| **Usuário** | `carapreta` |
| **Senha** | `carapreta123` |
| **SSH** | Porta 22, key-based auth |
| **Alias** | `ssh caraprojetada` |

## Hardware

```
SoC:      Rockchip RK3229 (28nm, 4× Cortex-A7 @ 1.5GHz)
GPU:      Mali-400 MP2
RAM:      962 MB DDR3 (1 GB nominal)
Storage:  7.3 GB eMMC (8 GB nominal)
Wi-Fi:    Espressif ESP8089 (802.11 b/g/n)
Ethernet: 10/100 Fast Ethernet
USB:      3× USB 2.0 + 1× USB OTG
HDMI:     HDMI 2.0 (4K@60fps)
SD:       Micro SD slot
Alimentação: DC 5V/2A
```

> **Fabricante original**: Provavelmente MXQ ou similar chinês  
> **Sistema original**: Android 4.4/5.1/8.1 (removido)  
> **Sistema atual**: Armbian 21.08.8 (Debian Bullseye)

## Sistema

```
OS:           Armbian 21.08.8 (Bullseye)
Kernel:       4.4.194-rk322x #2 SMP Wed Aug 25 20:09:42 UTC 2021
Arquitetura:  armv7l (ARMv7 32-bit)
Uptime:       2h37min (último boot)
Temp. CPU:    ~66°C
Carga:        0.13 / 0.13 / 0.05
```

## Armazenamento

```
/dev/mmcblk2 (7.3G)
└── /dev/mmcblk2p1 (7.1G) → / (4.7G usado, 2.1G livre)

Bootloaders:
  /dev/mmcblk2boot0 (2M)
  /dev/mmcblk2boot1 (2M)
  /dev/mmcblk2rpmb (128K)
```

## Rede

```
wlan0: 172.17.28.179/16 (DHCP)
Gateway: 172.17.0.1
eth0: DOWN (não conectado)
```

## Serviços Rodando (27/05/2026)

| Serviço | Porta | PID | Descrição |
|---------|-------|-----|-----------|
| projetor | 80 | 1582 | Flask: VNC + AD auth |
| sshd | 22 | — | OpenSSH server |
| lightdm | — | — | X display manager |
| Xorg | :0 | 1679 | X server |
| stream-cam | 8554 | — | RTSP streaming |

## Cron Ativo

```
0,30 * * * * /home/carapreta/totem_watchdog.sh
* * * * * sleep 30 && /home/carapreta/totem_watchdog.sh
* * * * * /home/carapreta/totem_guardian.sh
```

## Resolução de Vídeo

```
HDMI-1: 1360×768 @ 60Hz (nativa)
Suporta também: 1920×1080i, 1280×720, 1024×768
```

O guardian tenta forçar 1920×1080 mas a resolução nativa do display conectado é 1360×768.

## Faixa de IP de Produção (definida 08/07/2026)

```
faixa padrao: 172.17.7.50+
exemplo atual: 172.17.7.51 (carapreta-box em teste de pre-producao)
```

> As boxes de produção ficarão na faixa **172.17.7.50+** (rede UFRB/CETENS).
> O binário do cliente VNC é servido por cada box em `/download/vnc`
> (arquivo em `/home/carapreta/caraprojetada-vnc.exe`).

## Notas Técnicas

- O watchdog detectou que `xfwm4` é crítico — sem ele, o cursor vira um "X"
- A resolução real do display conectado é **1360×768**, não 1920×1080
- O Wi-Fi usa driver `ssv6x5x` (ESP8089)
- O áudio usa `snd_soc_rk3228` (DAC integrado no RK3229)
- O kernel 4.4.194 é o `legacy` branch do Armbian — não há suporte a kernel mais novo via repositório
- O arquivo `/var/log` está em zram (50 MB) para reduzir desgaste da eMMC
- Para upgrade de kernel, ver o projeto [CaraAzul](https://github.com/deivisan/caraazul)
