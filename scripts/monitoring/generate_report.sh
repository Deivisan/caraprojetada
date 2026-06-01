#!/bin/bash
set -u
export LC_ALL=C

base="/home/carapreta/monitoring"
data="$base/data/metrics.csv"
report="$base/reports/report_$(date +%Y%m%d_%H%M%S).txt"
latest="$base/reports/latest_report.txt"
mkdir -p "$base/reports"

if [ ! -f "$data" ]; then
  echo "sem metrics.csv ainda" | tee "$report"
  exit 1
fi

awk -F, '
NR==1 { next }
{
  n++
  first=(first=="" ? $1 : first); last=$1
  temp_sum+=$7; if ($7>temp_max) temp_max=$7; if (temp_min==0 || $7<temp_min) temp_min=$7
  mem_sum+=$9; if ($9>mem_max) mem_max=$9
  if (avail_min==0 || $10<avail_min) avail_min=$10
  if ($11>swap_max) swap_max=$11
  root_first=(root_first=="" ? $12 : root_first); root_last=$12; if ($12>root_max) root_max=$12
  if ($14>varlog_max) varlog_max=$14
  if ($15>tmp_max) tmp_max=$15
  home_first=(home_first=="" ? $16 : home_first); home_last=$16
  tmpchrom_first=(tmpchrom_first=="" ? $17 : tmpchrom_first); tmpchrom_last=$17
  log_first=(log_first=="" ? $18 : log_first); log_last=$18
  if ($23!=200) http_bad++
  if ($24!=1) services_bad++
  if ($25!=1) xorg_bad++
  if ($26!=1) openbox_bad++
  if ($27==0) chromium_missing++
  chromium_rss_sum+=$29; if ($29>chromium_rss_max) chromium_rss_max=$29
  chromium_cpu_sum+=$30; if ($30>chromium_cpu_max) chromium_cpu_max=$30
  py_rss_sum+=$32; if ($32>py_rss_max) py_rss_max=$32
  py_cpu_sum+=$33; if ($33>py_cpu_max) py_cpu_max=$33
  restarts=$36
}
END {
  print "relatorio caraprojetada"
  printf "periodo: %s -> %s\n", first, last
  printf "amostras: %d (intervalo esperado 5 min)\n\n", n
  if (n==0) exit
  printf "temperatura: media %.1f c | min %.1f | max %.1f\n", temp_sum/n, temp_min, temp_max
  printf "memoria usada: media %.0f mb | max %.0f mb | menor disponivel %.0f mb\n", (mem_sum/n)/1024, mem_max/1024, avail_min/1024
  printf "swap max: %.0f mb\n", swap_max/1024
  printf "disco /: inicio %s%% | fim %s%% | max %s%%\n", root_first, root_last, root_max
  printf "crescimento /home/carapreta: %.1f mb\n", (home_last-home_first)/1024
  printf "crescimento logs principais: %.1f mb\n", (log_last-log_first)/1024
  printf "crescimento /tmp/chromium-kiosk: %.1f mb\n\n", (tmpchrom_last-tmpchrom_first)/1024
  printf "chromium rss: media %.0f mb | max %.0f mb | cpu max amostrado %.1f%%\n", (chromium_rss_sum/n)/1024, chromium_rss_max/1024, chromium_cpu_max
  printf "flask rss: media %.0f mb | max %.0f mb | cpu max %.1f%%\n", (py_rss_sum/n)/1024, py_rss_max/1024, py_cpu_max
  printf "chromium restarts detectados: %s\n\n", restarts
  printf "falhas: http_bad=%d services_bad=%d xorg_bad=%d openbox_bad=%d chromium_missing=%d\n", http_bad, services_bad, xorg_bad, openbox_bad, chromium_missing
  printf "status: %s\n", (temp_max>=85 || root_max>=90 || http_bad>0 || services_bad>0 || chromium_missing>2 ? "ATENCAO" : "OK")
}' "$data" | tee "$report" > "$latest"

{
  echo ""
  echo "alertas recentes:"
  tail -20 "$base/data/alerts.log" 2>/dev/null || echo "sem alertas"
  echo ""
  echo "novos arquivos desde baseline:"
  if [ -f "$base/reports/latest_new_files.txt" ]; then
    wc -l "$base/reports/latest_new_files.txt"
    tail -20 "$base/reports/latest_new_files.txt"
  else
    echo "sem inventario ainda"
  fi
  echo ""
  echo "ultimas amostras:"
  tail -5 "$data"
} >> "$report"

cp "$report" "$latest"
echo "$report"
