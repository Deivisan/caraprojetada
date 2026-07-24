#!/bin/bash
# CaraProjetada - Setup rede VM para acesso direto
# Muda de 'user' (NAT) para rede bridge

VM_NAME="win11-ufrb"

echo "=== CaraProjetada - Network Setup ==="

# Opção 1: Redirecionar porta VNC via socat
echo "[1] Configurando redirecionamento de porta VNC..."

# Instalar socat se necessário
if ! command -v socat &> /dev/null; then
    echo "Instale socat: sudo pacman -S socat"
    exit 1
fi

# Parar VM
sudo virsh destroy "$VM_NAME" 2>/dev/null || true
sleep 2

# Criar nova interface de rede com redirecionamento
# Adicionar port redirection no QEMU
echo "[2] VM precisa ser reconfigurada para rede bridge"
echo ""
echo "Recomendado: shutdown VM e editar XML:"
echo "sudo virsh edit $VM_NAME"
echo ""
echo "Mudar:"
echo '  <interface type="user">'
echo "Para:"
echo '  <interface type="bridge">'
echo '    <source bridge="virbr0"/>'
echo '  </interface>'
echo ""
echo "Ou usar redirecionamento via libvirt:"

# Mostrar XML de exemplo
cat << 'XML'
<!-- Adicionar em <devices> -->
<redirec<output cut>
```

XML exemplo para adicionar ao XML da VM: