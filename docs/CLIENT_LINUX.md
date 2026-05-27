# 🐧 Cliente VNC para Linux - Guia Futuro

## Ferramentas Recomendadas

| Ferramenta | Comando Instalação | Comentários |
|------------|-------------------|-------------|
| **x11vnc** | `sudo apt install x11vnc` | Melhor integração com X11 |
| **TigerVNC** | `sudo apt install tigervnc-standalone-server` | Mais moderno |
| **TightVNC** | `sudo apt install tightvncserver` | Compatível com xtightvncviewer |

---

## Configuração x11vnc (Recomendado)

```bash
# Instalar
sudo apt install -y x11vnc

# Senha VNC (arquivo ~/.vnc_pass)
x11vnc -storepasswd 123456 ~/.vnc_pass

# Iniciar como serviço
cat > ~/.config/systemd/user/x11vnc.service << 'EOF'
[Unit]
Description=x11vnc service
After=graphical-session.target

[Service]
ExecStart=/usr/bin/x11vnc -display :0 -usepw -forever -shared -rfbauth ~/.vnc_pass
Restart=always

[Install]
WantedBy=default.target
EOF

systemctl --user enable x11vnc
```

---

## Configuração TightVNC

```bash
# Instalar
sudo apt install tightvncserver

# Configurar senha
echo "123456" | vncpasswd -f ~/.vnc/config > /dev/null

# Iniciar servidor
vncserver :0 -geometry 1920x1080 -depth 24
```

---

## Roadmap

### Fase 1 - Script de Instalação
- [ ] Script shell automático para instalar VNC
- [ ] Configuração senha headless via heredoc
- [ ] Autostart via systemd

### Fase 2 - App GUI
- [ ] Interface GTK/Qt para gerenciar conexões
- [ ] QR Code para pareamento com projetor
- [ ] Status de projetores na rede