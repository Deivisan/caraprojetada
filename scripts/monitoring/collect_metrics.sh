#!/bin/bash
set -u
export LC_ALL=C

base="/home/carapreta/monitoring"
data="$base/data/metrics.csv"
state="$base/state"
alerts="$base/data/alerts.log"
mkdir -p "$base/data" "$base/state" "$base/reports"

if [ ! -f "$data" ]; then
  echo "ts,epoch,uptime_s,load1,load5,load15,temp_c,mem_total_kb,mem_used_kb,mem_avail_kb,swap_used_kb,root_used_pct,root_avail_kb,varlog_used_pct,tmp_used_pct,home_cara_kb,tmp_chromium_kb,log_total_kb,app_log_kb,guardian_log_kb,watchdog_log_kb,access_log_kb,proj_http,services_ok,xorg,openbox,chromium_pid,chromium_count,chromium_rss_kb,chromium_cpu_sum,python_pid,python_rss_kb,python_cpu,active_session,user_ip,chromium_restarts,notes" > "$data"
fi

ts=$(date "+%Y-%m-%d %H:%M:%S")
epoch=$(date +%s)
uptime_s=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)
read load1 load5 load15 _ < /proc/loadavg

temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)
temp_c=$(awk "BEGIN {printf \"%.1f\", $temp_raw/1000}")

mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
mem_avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
mem_used=$((mem_total - mem_avail))
swap_used=$(awk '/SwapTotal/ {t=$2} /SwapFree/ {f=$2} END {print t-f}' /proc/meminfo)

root_used=$(df -P / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
root_avail=$(df -P / | awk 'NR==2 {print $4}')
varlog_used=$(df -P /var/log 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
varlog_used=${varlog_used:-0}
tmp_used=$(df -P /tmp 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
tmp_used=${tmp_used:-0}

home_cara=$(du -sk /home/carapreta 2>/dev/null | awk '{print $1}')
tmp_chromium=$(du -sk /tmp/chromium-kiosk 2>/dev/null | awk '{print $1}')
tmp_chromium=${tmp_chromium:-0}
app_log=$(du -sk /home/carapreta/app.log 2>/dev/null | awk '{print $1}')
app_log=${app_log:-0}
guardian_log=$(du -sk /home/carapreta/totem_guardian.log 2>/dev/null | awk '{print $1}')
guardian_log=${guardian_log:-0}
watchdog_log=$(du -sk /home/carapreta/watchdog.log 2>/dev/null | awk '{print $1}')
watchdog_log=${watchdog_log:-0}
access_log=$(du -sk /home/carapreta/projetor-acessos.log 2>/dev/null | awk '{print $1}')
access_log=${access_log:-0}
log_total=$((app_log + guardian_log + watchdog_log + access_log))

proj_http=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost/projetor 2>/dev/null || echo 000)
s_proj=$(systemctl is-active projetor 2>/dev/null || echo inactive)
s_light=$(systemctl is-active lightdm 2>/dev/null || echo inactive)
s_cron=$(systemctl is-active cron 2>/dev/null || echo inactive)
services_ok=0
[ "$s_proj" = active ] && [ "$s_light" = active ] && [ "$s_cron" = active ] && services_ok=1

xorg=$(pgrep -x Xorg >/dev/null && echo 1 || echo 0)
openbox=$(pgrep -x openbox >/dev/null && echo 1 || echo 0)
chromium_pid=$(pgrep -f "chromium.*--kiosk" | head -1 || true)
chromium_pid=${chromium_pid:-0}
chromium_count=$(pgrep -fc chromium)
chromium_rss=$(ps -C chromium -o rss= 2>/dev/null | awk '{s+=$1} END {print s+0}')
chromium_cpu=$(ps -C chromium -o pcpu= 2>/dev/null | awk '{s+=$1} END {printf "%.1f", s+0}')
python_pid=$(pgrep -f "/home/carapreta/app.py" | head -1 || true)
python_pid=${python_pid:-0}
python_rss=$(ps -p "$python_pid" -o rss= 2>/dev/null | awk '{print $1+0}')
python_rss=${python_rss:-0}
python_cpu=$(ps -p "$python_pid" -o pcpu= 2>/dev/null | awk '{printf "%.1f", $1+0}')
python_cpu=${python_cpu:-0.0}

status_json=$(curl -s --max-time 5 http://localhost/api/v1/status 2>/dev/null || echo "{}")
active_session=$(printf "%s" "$status_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(str(d.get("active_session", False)).lower())' 2>/dev/null || echo unknown)
user_ip=$(printf "%s" "$status_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("user_ip") or "")' 2>/dev/null || echo "")

last_pid_file="$state/last_chromium_pid"
restarts_file="$state/chromium_restarts"
[ -f "$restarts_file" ] || echo 0 > "$restarts_file"
last_pid=$(cat "$last_pid_file" 2>/dev/null || echo 0)
restarts=$(cat "$restarts_file" 2>/dev/null || echo 0)
if [ "$chromium_pid" != "0" ] && [ "$last_pid" != "0" ] && [ "$chromium_pid" != "$last_pid" ]; then
  restarts=$((restarts + 1))
  echo "$restarts" > "$restarts_file"
  echo "$ts ALERT chromium_pid_changed old=$last_pid new=$chromium_pid" >> "$alerts"
fi
[ "$chromium_pid" != "0" ] && echo "$chromium_pid" > "$last_pid_file"

notes="ok"
if awk "BEGIN {exit !($temp_c >= 80)}"; then
  echo "$ts ALERT temp_high temp_c=$temp_c" >> "$alerts"
  notes="temp_high"
fi
if [ "$root_used" -ge 85 ]; then
  echo "$ts ALERT root_disk_high pct=$root_used" >> "$alerts"
  notes="disk_high"
fi
if [ "$proj_http" != "200" ]; then
  echo "$ts ALERT projector_http code=$proj_http" >> "$alerts"
  notes="http_$proj_http"
fi
if [ "$services_ok" -ne 1 ]; then
  echo "$ts ALERT service_state projetor=$s_proj lightdm=$s_light cron=$s_cron" >> "$alerts"
  notes="service_bad"
fi

echo "$ts,$epoch,$uptime_s,$load1,$load5,$load15,$temp_c,$mem_total,$mem_used,$mem_avail,$swap_used,$root_used,$root_avail,$varlog_used,$tmp_used,$home_cara,$tmp_chromium,$log_total,$app_log,$guardian_log,$watchdog_log,$access_log,$proj_http,$services_ok,$xorg,$openbox,$chromium_pid,$chromium_count,$chromium_rss,$chromium_cpu,$python_pid,$python_rss,$python_cpu,$active_session,$user_ip,$restarts,$notes" >> "$data"
