#!/bin/bash
#
# Script de backup da imagem do sistema para exportação
# UFRB - CETENS - Sistema de Projeções
#
# Uso: sudo ./backup_imagem.sh
#

set -e

DATA=$(date +%Y%m%d_%H%M)
DESTINO="/home/carapreta/backup_${DATA}"
DISCO_ORIGEM="/dev/mmcblk2"
ARQUIVO_IMG="carapreta-box_${DATA}.img"
ARQUIVO_GZ="${ARQUIVO_IMG}.gz"

echo "═══════════════════════════════════════════"
echo "  BACKUP DO SISTEMA - CARAPRETA-BOX"
echo "  UFRB · CETENS · Sistema de Projeções"
echo "═══════════════════════════════════════════"
echo ""
echo "📋 Informações do sistema:"
echo "   Data:     $(date)"
echo "   Hostname: $(hostname)"
echo "   Kernel:   $(uname -r)"
echo "   Disco:    $(df -h / | awk 'NR==2 {print $2}')"
echo "   Usado:    $(df -h / | awk 'NR==2 {print $3" ("$5")"}')"
echo ""

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Execute como root: sudo $0"
  exit 1
fi

# Verificar espaço
ESPACO_NECESSARIO=$(df / | awk 'NR==2 {print $3+$4}')
ESPACO_LIVRE=$(df /home | awk 'NR==2 {print $4}' 2>/dev/null || df / | awk 'NR==2 {print $4}')
echo "📊 Espaço necessário para backup: ~$((${ESPACO_NECESSARIO} / 1024)) MB"
echo "   Espaço disponível:             ~$((${ESPACO_LIVRE} / 1024)) MB"
echo ""

if [ "${ESPACO_LIVRE}" -lt "${ESPACO_NECESSARIO}" ]; then
  echo "⚠️  Espaço insuficiente para backup completo."
  echo "   Conecte um HD externo ou pendrive."
  echo ""
  echo "   Para montar um dispositivo externo:"
  echo "   sudo mount /dev/sda1 /mnt"
  echo "   sudo dd if=${DISCO_ORIGEM} of=/mnt/${ARQUIVO_IMG} bs=4M status=progress"
  echo "   sudo gzip /mnt/${ARQUIVO_IMG}"
  exit 1
fi

echo "✅ Espaço suficiente. Iniciando backup..."
echo ""

# Backup com dd + gzip
echo "⏳ Copiando imagem do disco (isso pode levar vários minutos)..."
dd if=${DISCO_ORIGEM} of=/home/carapreta/${ARQUIVO_IMG} bs=4M status=progress

echo ""
echo "⏳ Compactando (gzip)..."
gzip -f /home/carapreta/${ARQUIVO_IMG}

echo ""
echo "═══════════════════════════════════════════"
echo "  ✅ BACKUP CONCLUÍDO!"
echo "═══════════════════════════════════════════"
echo ""
echo "   Arquivo: /home/carapreta/${ARQUIVO_GZ}"
echo "   Tamanho: $(ls -lh /home/carapreta/${ARQUIVO_GZ} | awk '{print $5}')"
echo ""
echo "   Para restaurar em outro cartão SD:"
echo "   gunzip -c ${ARQUIVO_GZ} | sudo dd of=/dev/sdX bs=4M status=progress"
echo ""

# Salvar informações do sistema
cat > /home/carapreta/backup_${DATA}_info.txt << INFO
Backup: ${DATA}
Hostname: $(hostname)
Kernel: $(uname -r)
Armbian: $(cat /etc/armbian-release | grep VERSION | cut -d= -f2)
Pacotes instalados: $(dpkg-query -Wf '.\n' | wc -l)
Disco total: $(df -h / | awk 'NR==2 {print $2}')
Disco usado: $(df -h / | awk 'NR==2 {print $3" ("$5")"}')
IP: $(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
Serviços ativos: projetor, lightdm, ssh, cron, stream-cam
INFO

echo "   Info salvo em: backup_${DATA}_info.txt"
echo ""
