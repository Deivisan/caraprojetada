#!/usr/bin/env python3
# CaraProjetada Windows Client
# Gerencia TightVNC Server (tvnserver.exe portatil) e se registra no projetor

import sys
import os
import json
import socket
import subprocess
import requests
from pathlib import Path
from datetime import datetime

# Configurações (serão lidas de config.json)
CONFIG = {
    'projector_host': 'projetores.intranet.ufrb.edu.br',
    'api_port': 80,
    'vnc_port': 5900,
    'heartbeat_interval': 30,
    'auto_start': True
}

class VNCMManager:
    """Gerenciador do TightVNC Server (tvnserver.exe portatil)"""

    def __init__(self):
        # binario portatil ao lado deste script
        self.tvnserver_path = Path(__file__).resolve().parent / "tvnserver.exe"

    def is_installed(self):
        return self.tvnserver_path.exists()

    def install(self):
        """O tvnserver e portatil: nao instala, so executa."""
        if self.is_installed():
            return True
        print("[VNC] tvnserver.exe nao encontrado ao lado do client.")
        return False
        
    def set_password(self, password):
        """A senha do VNC e definida na GUI do tightvnc (tvnserver).
        O PIN informado no painel do projetor deve igualar essa senha."""
        if not self.is_installed():
            return False
        # o tvnserver gera/armazena a senha na propria interface
        # nao gravamos nada em arquivo: o usuario define em "administration".
        print(f"[VNC] senha definida pelo usuario na GUI do tightvnc (pin do painel)")
        return True

    def start_service(self):
        """Inicia o tvnserver portatil (modo aplicacao/GUI)."""
        try:
            subprocess.Popen([str(self.tvnserver_path)],
                             stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)
            return True
        except Exception as e:
            print(f"[VNC] Erro ao iniciar tvnserver: {e}")
            return False

    def stop_service(self):
        """Encerra o tvnserver portatil."""
        try:
            subprocess.run(['taskkill', '/IM', 'tvnserver.exe', '/F'],
                           capture_output=True)
            return True
        except Exception:
            return False

class APIClient:
    """Cliente para comunicação com o projetor"""
    
    def __init__(self, host):
        self.base_url = f"http://{host}/api/v1"
        
    def register(self, hostname):
        """Registra o PC no projetor"""
        try:
            response = requests.post(
                f"{self.base_url}/register",
                json={'hostname': hostname},
                timeout=5
            )
            return response.json()
        except Exception as e:
            print(f"[API] Erro no registro: {e}")
            return None
            
    def heartbeat(self, hostname):
        """Envia heartbeat periódico"""
        try:
            response = requests.post(
                f"{self.base_url}/heartbeat",
                json={'hostname': hostname, 'online': True},
                timeout=5
            )
            return response.json()
        except Exception as e:
            return None
            
    def get_vnc_password(self, session_id):
        """Obtém senha VNC para sessão"""
        try:
            response = requests.get(
                f"{self.base_url}/vnc/password?session_id={session_id}",
                timeout=5
            )
            return response.json()
        except Exception:
            return None

def get_local_ip():
    """Obtém o IP local"""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

def main():
    if len(sys.argv) > 1:
        if sys.argv[1] == '--install-service':
            print("[SETUP] Instalando como serviço Windows...")
            # Implementar instalação como serviço
            return
            
        if sys.argv[1] == '--minimized':
            print("[STARTUP] Iniciando minimizado...")
            # Iniciar como system tray apenas
            return
    
    # Execução normal
    hostname = socket.gethostname()
    local_ip = get_local_ip()
    
    print(f"[INIT] CaraProjetada Client - {hostname} ({local_ip})")
    
    # Inicializa VNC Manager
    vnc = VNCMManager()
    
    # Inicializa API Client
    api = APIClient(CONFIG['projector_host'])
    
    # Registra no projetor
    registration = api.register(hostname)
    if registration:
        print(f"[API] Registrado: {registration.get('session_id', 'N/A')}")
        
        # Obtém senha VNC se houver sessão ativa
        if 'session_id' in registration:
            vnc_info = api.get_vnc_password(registration['session_id'])
            if vnc_info and 'password' in vnc_info:
                vnc.set_password(vnc_info['password'])
    else:
        print("[API] Falha no registro - check rede")

if __name__ == '__main__':
    main()