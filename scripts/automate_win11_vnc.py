#!/usr/bin/env python3
"""
CaraProjetada - Automatização Windows 11 VNC Setup
Usa QEMU guest agent ou spice para automação
"""

import subprocess
import time
import os

VM_NAME = "win11-ufrb"

def execute_in_vm(command: str):
    """Tenta executar comando na VM via QEMU guest agent"""
    try:
        result = subprocess.run(
            ['sudo', 'virsh', 'qemu-agent-command', VM_NAME, 
             f'{{"execute":"guest-exec", "arguments":{{"path":"{command}", "args":[], "capture-output":true}}}}'],
            capture_output=True, text=True, timeout=10
        )
        return result.stdout
    except Exception as e:
        return f"Error: {e}"

def setup_vnc_automatically():
    """Configura VNC na VM automaticamente"""
    print("=== CaraProjetada VNC Setup ===")
    
    # Script PowerShell inline para provisionar
    ps_script = '''
# Habilitar scripts
Set-ExecutionPolicy Bypass -Scope CurrentUser -Force

# Criar pasta temporária
New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null

# Download UltraVNC
$uvncUrl = "https://www.uvnc.eu/download/1404/UltraVNC_1404_X64_Setup.exe"
$installer = "C:\temp\UltraVNC_Setup.exe"
Invoke-WebRequest -Uri $uvncUrl -OutFile $installer

# Instalar silencioso
Start-Process -FilePath $installer -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /MERGETASKS=installservice" -Wait

# Configurar senha
"123456" | "C:\Program Files\UltraVNC\winvnc.exe" -storepassword

# Iniciar serviço
Restart-Service -Name "UltraVNC Server" -Force

# Firewall
netsh advfirewall firewall add rule name="UltraVNC" dir=in action=allow protocol=TCP localport=5900
'''
    
    # Salvar script em arquivo que pode ser acessado pela VM
    script_path = "/tmp/win11_setup.ps1"
    with open(script_path, 'w') as f:
        f.write(ps_script)
    
    print(f"Script PowerShell salvo em {script_path}")
    print("Executar manualmente via VNC: remote-viewer vnc://localhost:5900")
    
if __name__ == '__main__':
    setup_vnc_automatically()