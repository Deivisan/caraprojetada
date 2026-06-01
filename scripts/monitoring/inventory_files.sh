#!/bin/bash
set -u
export LC_ALL=C

base="/home/carapreta/monitoring"
inv="$base/data/file_inventory_current.tsv"
baseline="$base/state/file_inventory_baseline.tsv"
new_files="$base/reports/latest_new_files.txt"
mkdir -p "$base/data" "$base/state" "$base/reports"

tmp=$(mktemp)
{
  find /home/carapreta -xdev \
    -path /home/carapreta/monitoring/data -prune -o \
    -path /home/carapreta/monitoring/reports -prune -o \
    -type f -printf '%p\t%s\t%TY-%Tm-%Td %TH:%TM\n' 2>/dev/null
  find /tmp/chromium-kiosk -xdev -type f -printf '%p\t%s\t%TY-%Tm-%Td %TH:%TM\n' 2>/dev/null
  find /var/log -xdev -type f -printf '%p\t%s\t%TY-%Tm-%Td %TH:%TM\n' 2>/dev/null
} | sort > "$tmp"

mv "$tmp" "$inv"

if [ ! -f "$baseline" ]; then
  cp "$inv" "$baseline"
fi

awk -F '\t' 'NR==FNR {seen[$1]=1; next} !seen[$1] {print}' "$baseline" "$inv" > "$new_files"

echo "inventario_atual=$inv"
echo "baseline=$baseline"
echo "novos=$(wc -l < "$new_files")"
