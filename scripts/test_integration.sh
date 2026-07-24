#!/bin/bash
# CaraProjetada - Script de Teste de Integração
# Verifica conectividade entre Windows 11 (QEMU) e Projetor

set -e

VM_NAME="win11-ufrb"
VNC_PORT=5900

echo "========================================"
echo "CaraProjetada - Teste de Integração"
echo "========================================"

# 1. Verificar VM
echo ""
echo "[1/5] Verificando VM Windows 11..."
VM_STATE=$(sudo virsh domstate "$VM_NAME" 2>/dev/null || echo "not-found")
echo "   Estado da VM: $VM_STATE"

if [ "$VM_STATE" == "shut off" ]; then
    echo "   Iniciando VM..."
    sudo virsh start "$VM_NAME"
    sleep 3
fi

# 2. Verificar porta VNC
echo ""
echo "[2/5] Verificando porta VNC ($VNC_PORT)..."
if ss -tlnp | rg ":$VNC_PORT" > /dev/null; then
    echo "   ✅ Porta $VNC_PORT está escutando"
else
    echo "   ⚠️ Porta $VNC_PORT não encontrada - o VNC do QEMU está ativo?"
fi

# 3. Testar endpoint da API
echo ""
echo "[3/5] Testando API Flask..."
if [ -f app/app.py ]; then
    python3 -c "
import sys
sys.path.insert(0, 'app')
from app import app
with app.test_client() as c:
    r = c.get('/api/v1/status')
    print('   Status:', r.json.get('connected', False))
    r = c.post('/api/v1/tab', json={'url': 'https://test.com', 'title': 'Teste'})
    print('   Tab API:', r.json.get('success', False))
" 2>/dev/null && echo "   ✅ API respondendo" || echo "   ⚠️ Falha ao testar API"
else
    echo "   ⚠️ app/app.py não encontrado"
fi

# 4. Verificar arquivos da extensão
echo ""
echo "[4/5] Verificando extensão do navegador..."
if [ -f browser-extension/manifest.json ]; then
    echo "   ✅ Manifest encontrado"
    ls -la browser-extension/
else
    echo "   ⚠️ Extensão não encontrada"
fi

# 5. Verificar cliente Windows
echo ""
echo "[5/5] Verificando cliente Windows..."
if [ -f windows-client/main.py ]; then
    echo "   ✅ Cliente Python encontrado"
    if [ -f windows-client/install_vnc.ps1 ]; then
        echo "   ✅ Script PowerShell encontrado"
    fi
else
    echo "   ⚠️ Cliente Windows não encontrado"
fi

echo ""
echo "========================================"
echo "Próximos passos:"
echo "1. Conectar na VM: remote-viewer vnc://localhost:5900"
echo "2. Instalar UltraVNC no Windows (script .ps1)"
echo "3. Testar extensão Chrome: chrome://extensions"
echo "========================================"