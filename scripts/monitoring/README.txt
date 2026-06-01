monitoramento de estabilidade caraprojetada

objetivo: rodar 24/7 por 4-5 dias e medir temperatura, memoria, disco, logs,
servicos, chromium, flask e reinicios da tela.

arquivos na box:
- /home/carapreta/monitoring/data/metrics.csv: serie temporal, 1 linha a cada 5 min
- /home/carapreta/monitoring/data/alerts.log: alertas de temperatura/disco/http/servico/restart chromium
- /home/carapreta/monitoring/reports/latest_report.txt: resumo mais recente
- /home/carapreta/monitoring/reports/report_*.txt: historico de relatorios
- /home/carapreta/monitoring/reports/latest_new_files.txt: arquivos novos desde o baseline

comandos na box:
- coletar agora: /home/carapreta/monitoring/bin/collect_metrics.sh
- gerar relatorio: /home/carapreta/monitoring/bin/generate_report.sh
- gerar inventario: /home/carapreta/monitoring/bin/inventory_files.sh
- empacotar tudo: /home/carapreta/monitoring/bin/package_reports.sh

coleta na segunda-feira:
1. ssh caraprojetada '/home/carapreta/monitoring/bin/package_reports.sh'
2. copiar o caminho retornado com scp, exemplo:
   scp caraprojetada:/home/carapreta/monitoring/reports/caraprojetada_monitoring_YYYYMMDD_HHMMSS.tar.gz .
- ver ultimo relatorio: cat /home/carapreta/monitoring/reports/latest_report.txt

limites iniciais:
- temperatura atencao >= 80c, critica >= 85c
- disco / atencao >= 85%, critico >= 90%
- qualquer http != 200 vira alerta
- qualquer mudanca de pid do chromium vira contador/alerta
