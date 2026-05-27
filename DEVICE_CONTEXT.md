# CaraProjetada - VNC Projector Control System

## Device Context

- **Hostname**: `carapreta-box`
- **IP**: `172.17.28.179`
- **OS**: `Armbian 21.08.8`
- **Kernel**: `4.4.194-rk322x`
- **Arch**: `ARMv7 (armhf)`
- **RAM**: `962MB`
- **User**: `carapreta`
- **Password**: `carapreta123`

## Services Running

| Service | Port | Description |
|---------|------|-------------|
| Flask (projetor) | 80 | Web control + VNC auth |
| SSH | 22 | Remote access |
| RTSP (camera) | 8554 | Camera streaming |
| LightDM | - | Display manager |

## Network

- Wi-Fi: `wlan0` (DHCP)
- Ethernet: Disponivel mas nao usado como primario
- Gateway: `172.17.28.1`

## Cron Jobs

```cron
* * * * * /home/carapreta/totem_guardian.sh
* * * * * sleep 30 && /home/carapreta/totem_watchdog.sh
*/30 * * * * /home/carapreta/totem_watchdog.sh
```

## Active Directory

- Server: `10.198.1.2`
- Domain: `intranet.ufrb.edu.br`
- Auth: LDAP (porta 389)

## Storage

- Root: `/dev/mmcblk2p1`
- SD card: `/dev/mmcblk0` (Multitool)
- Used: `70% of 6.9G`
