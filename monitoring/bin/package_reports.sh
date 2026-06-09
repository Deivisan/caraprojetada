#!/bin/bash
set -u
export LC_ALL=C

base="/home/carapreta/monitoring"
out="$base/reports/caraprojetada_monitoring_$(date +%Y%m%d_%H%M%S).tar.gz"

"$base/bin/collect_metrics.sh" >/dev/null 2>&1 || true
"$base/bin/inventory_files.sh" >/dev/null 2>&1 || true
"$base/bin/generate_report.sh" >/dev/null 2>&1 || true

tar -czf "$out" \
  -C "$base" README.txt data state reports/latest_report.txt reports/latest_new_files.txt 2>/dev/null

echo "$out"
