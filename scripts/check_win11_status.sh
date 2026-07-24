#!/bin/bash
# CaraProjetada - Verificação de Status Windows 11 + VNC

VM_NAME="win11-ufrb"

echo "=== CaraProjetada Status Check ==="

# 1. Estado da VM
STATE=$(sudo virsh domstate "$VM_NAME" 2>/dev/null)
echo "VM State: $STATE"

if [ "$STATE" == "running" ]; then
    # 2. Porta VNC do QEMU
    if ss -tlnp | rg ":5900" > /dev/null; then
        echo "QEMU VNC Port: OPEN (localhost:5900)"
    else
        echo "QEMU VNC Port: CLOSED"
    fi
    
    # 3. Tentar detectar IP do Windows (via ARP)
    echo ""
    echo "Possíveis IPs na rede:"
    arp -a 2>/dev/null | rg -i "172\.17\." || echo "  (nenhum IP detectado)"
fi

echo ""
echo "=== API Status ==="
python3 -c "
import sys
sys.path.insert(0, 'app')
from app import app
with app.test_client() as c:
    r = c.get('/api/v1/status')
    print('Connected:', r.json.get('connected'))
    print('Sessions:', len(r.json.get('active_sessions', [])))
" 2>/dev/null

echo ""
echo "=== Próximos passos ==="
echo "1. Conectar via: remote-viewer vnc://localhost:5900"
echo "2. Instalar UltraVNC no Windows (ver WIN11_AUTOMATION.md)"
echo "3. Verificar: netstat -an | findstr 5900"