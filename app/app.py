from flask import Flask, render_template_string, request, session, redirect, jsonify, send_file
import subprocess
import time
from datetime import datetime
import os
import re
import socket
import struct

# ldap3 obrigatório em produção
from ldap3 import Server, Connection, ALL

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'chave_secreta_projecoes_ufrb_cetens')

AD_SERVER = os.environ.get('AD_SERVER', 'ldap://10.198.1.2')
AD_DOMAIN = os.environ.get('AD_DOMAIN', 'intranet.ufrb.edu.br')
AD_BASE_DN = os.environ.get('AD_BASE_DN', 'dc=intranet,dc=ufrb,dc=edu,dc=br')
LOG_FILE = os.environ.get('LOG_FILE', '/home/carapreta/projetor-acessos.log')

# modo dev: desativa autenticacao AD real (apenas para testes locais)
DEV_MODE = os.environ.get('DEV_MODE', 'False').lower() in ('1', 'true', 'yes', 'on')

# ldap3 e importado diretamente no topo (obrigatorio em producao)
LDAP_DISPONIVEL = True

# link de download do cliente vnc.
# primario: a propria box serve o binario (sempre funciona, fallback local).
# secundario (opcional): release do github via env VNC_DOWNLOAD_URL.
VNC_BINARY_PATH = os.environ.get('VNC_BINARY_PATH', '/home/carapreta/caraprojetada-vnc.exe')
VNC_DOWNLOAD_URL = os.environ.get(
    'VNC_DOWNLOAD_URL',
    '/download/vnc'
)

current_session = {
    'active': False,
    'username': None,
    'user_ip': None,
    'display': None,
    'os_type': None,
    'started_at': None,
    'user_fullname': None,
    'original_resolution': None
}

def detect_os(user_agent):
    ua = user_agent.lower() if user_agent else ''
    if 'linux' in ua:
        return ('3', 'Linux')
    elif 'windows' in ua or 'win64' in ua or 'wow64' in ua:
        return ('0', 'Windows')
    elif 'mac' in ua or 'os x' in ua:
        return ('0', 'macOS')
    return ('0', 'Desconhecido')

def registrar_log(evento, detalhes=''):
    data = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    ip = request.remote_addr if request else '-'
    user = session.get('username', '-') if session else '-'
    linha = f'[{data}] IP={ip} USUARIO={user} EVENTO={evento} {detalhes}'
    try:
        with open(LOG_FILE, 'a') as f:
            f.write(linha + '\n')
    except:
        pass

def probe_vnc_resolution(host, port=5900):
    """Conecta no servidor VNC do notebook e descobre a resolucao do framebuffer.
    Retorna (width, height) ou (None, None) em caso de erro.
    Suporta RFB 3.8 com Tight security (tipo 16) sem sub-autenticacao,
    e None auth (tipo 2)."""
    sock = socket.socket()
    sock.settimeout(4)
    try:
        sock.connect((host, port))
        proto = sock.recv(12)  # "RFB 003.008\n"
        if not proto.startswith(b'RFB'):
            return None, None
        sock.send(proto)  # ecoa o mesmo protocolo

        sec_count = ord(sock.recv(1))
        sec_types = sock.recv(sec_count) if sec_count > 0 else b''

        # Tenta Tight security (16) primeiro, depois None (2)
        sec_chosen = None
        if 16 in sec_types:
            sec_chosen = 16
        elif 2 in sec_types:
            sec_chosen = 2
        else:
            registrar_log('RES_PROBE_ERRO', f'sem sec type compativel: {list(sec_types)}')
            return None, None

        sock.send(bytes([sec_chosen]))

        if sec_chosen == 16:
            # Tight security
            sub = ord(sock.recv(1))
            if sub > 0:
                sock.recv(sub)  # descarta sub-tipos
            # Le SecurityResult
            result = struct.unpack('>I', sock.recv(4))[0]
            if result != 0:
                return None, None
        elif sec_chosen == 2:
            # None auth: le SecurityResult (4 bytes)
            result = struct.unpack('>I', sock.recv(4))[0]
            if result != 0:
                return None, None

        # ClientInit: shared flag = 1
        sock.send(b'\x01')

        # ServerInit: 2B width + 2B height + 4B name_len + name
        si = sock.recv(4)
        w = struct.unpack('>H', si[0:2])[0]
        h = struct.unpack('>H', si[2:4])[0]
        return w, h
    except Exception as e:
        registrar_log('RES_PROBE_ERRO', f'{host}:{port} {type(e).__name__}:{e}')
        return None, None
    finally:
        sock.close()

def autenticar_ad(username, password):
    if DEV_MODE:
        if username == 'admin' and password == 'admin':
            return True, 'Administrador DEV'
        if password == 'dev' or username == password:
            return True, username.title() + ' (DEV)'
        return False, None

    if not LDAP_DISPONIVEL:
        registrar_log('LOGIN_ERRO', 'ldap3 nao instalado')
        return False, None

    try:
        user_principal = f'{username}@{AD_DOMAIN}'
        server = Server(AD_SERVER, get_info=ALL)
        conn = Connection(server, user=user_principal, password=password, authentication='SIMPLE')
        if conn.bind():
            nome_completo = username
            email = ''
            try:
                conn.search(
                    search_base=AD_BASE_DN,
                    search_filter=f'(sAMAccountName={username})',
                    attributes=['displayName', 'name', 'cn', 'mail', 'department', 'title']
                )
                if conn.entries:
                    entry = conn.entries[0]
                    for attr in ['displayName', 'name', 'cn']:
                        if hasattr(entry, attr) and entry[attr].value:
                            nome_completo = entry[attr].value
                            break
                    if hasattr(entry, 'mail') and entry['mail'].value:
                        email = entry['mail'].value
            except:
                pass
            conn.unbind()
            registrar_log('LOGIN_OK', f'SIAPE={username} nome="{nome_completo}" email="{email}"')
            return True, nome_completo, email
        return False, None, None
    except Exception as e:
        registrar_log('LOGIN_ERRO', f'erro={str(e)}')
        return False, None, None

# ══════════════════════════════════════════════════════════════════
# TEMPLATES HTML
# ══════════════════════════════════════════════════════════════════

LOGIN_HTML = """<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sistema de Proje&ccedil;&otilde;es &mdash; UFRB &middot; CETENS</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body { height: 100%; overflow: hidden; }
        body {
            font-family: 'Segoe UI', 'Open Sans', system-ui, -apple-system, sans-serif;
            background: linear-gradient(135deg, #003366 0%, #005580 40%, #6A1B9A 100%);
            height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 16px;
        }
        .layout {
            width: 100%;
            max-width: 980px;
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 22px;
            align-items: stretch;
        }
        .card {
            background: #fff;
            border-radius: 16px;
            padding: 28px 30px;
            box-shadow: 0 8px 40px rgba(0,0,0,0.25);
            display: flex;
            flex-direction: column;
        }
        .card.login { border-top: 5px solid #FFB300; }
        .card.side  { border-top: 5px solid #008B9E; }
        .brand { margin-bottom: 18px; }
        .brand img { max-height: 44px; width: auto; margin-bottom: 10px; }
        .brand h1 {
            font-size: 19px; color: #003366; font-weight: 700; letter-spacing: -0.3px;
        }
        .brand .sub { font-size: 12px; color: #666; margin-top: 2px; }
        .brand .sub strong { color: #008B9E; }
        .brand .divider {
            width: 56px; height: 3px; margin-top: 12px; border-radius: 3px;
            background: linear-gradient(90deg, #003366, #008B9E, #6A1B9A, #FFB300);
        }
        .info-box {
            background: #f0f4f8; border: 1px solid #d0dce8; border-radius: 10px;
            padding: 14px 16px; font-size: 13px; color: #2c3e50; line-height: 1.6; margin-bottom: 18px;
        }
        .info-box strong { color: #003366; }
        .info-box .hl {
            display: inline-block; background: #FFB300; color: #003366;
            font-weight: 700; padding: 0 6px; border-radius: 3px;
        }
        .form-group { margin-bottom: 14px; }
        .form-group label {
            display: block; font-size: 12.5px; font-weight: 600; color: #444; margin-bottom: 5px;
        }
        .form-group input {
            width: 100%; padding: 12px 14px; border: 1.5px solid #d0d5dd; border-radius: 8px;
            font-size: 15px; outline: none; background: #fafafa; transition: all 0.2s;
        }
        .form-group input:focus {
            border-color: #003366; background: #fff; box-shadow: 0 0 0 3px rgba(0,51,102,0.10);
        }
        .btn-login {
            width: 100%; padding: 13px; margin-top: 4px;
            background: linear-gradient(135deg, #003366, #005580); color: #fff;
            border: none; border-radius: 8px; font-size: 15px; font-weight: 600;
            cursor: pointer; transition: all 0.2s;
        }
        .btn-login:hover { background: linear-gradient(135deg, #004480, #006699); box-shadow: 0 4px 15px rgba(0,51,102,0.3); }
        .btn-login:active { transform: scale(0.98); }
        .error-msg {
            background: #fef2f2; color: #991b1b; padding: 10px 14px; border-radius: 8px;
            font-size: 13px; margin-bottom: 14px; border: 1px solid #fecaca;
        }
        .card-side h2 {
            font-size: 15px; color: #005580; font-weight: 700; margin-bottom: 6px;
            display: flex; align-items: center; gap: 7px;
        }
        .side-desc { font-size: 12.5px; color: #2c3e50; line-height: 1.55; margin-bottom: 14px; }
        .btn-download {
            display: flex; align-items: center; justify-content: center; gap: 8px;
            width: 100%; padding: 12px; text-decoration: none; color: #fff;
            background: linear-gradient(135deg, #008B9E, #005580); border: none;
            border-radius: 8px; font-size: 14px; font-weight: 600; cursor: pointer; transition: all 0.15s;
        }
        .btn-download:hover { background: linear-gradient(135deg, #00a3b8, #006699); box-shadow: 0 4px 15px rgba(0,139,158,0.3); }
        .side-warn {
            margin-top: 10px; font-size: 10.5px; color: #8a5a00; line-height: 1.5;
            background: #fff7e6; border: 1px solid #ffe0a3; border-radius: 8px; padding: 8px 10px;
        }
        .side-steps { margin-top: 14px; font-size: 12px; color: #2c3e50; line-height: 1.6; }
        .side-steps ol { padding-left: 18px; margin: 0; }
        .side-steps li { margin-bottom: 4px; }
        .side-steps strong { color: #003366; }
        .side-foot {
            margin-top: auto; padding-top: 14px; font-size: 11px; color: #888; line-height: 1.5;
            display: flex; align-items: center; justify-content: space-between; gap: 8px;
        }
        .side-foot a { color: #008B9E; text-decoration: none; }
        .gh-logo {
            position: fixed; right: 14px; bottom: 12px;
            display: flex; align-items: center; gap: 6px;
            font-size: 11px; color: #fff; text-decoration: none;
            background: rgba(0,0,0,0.25); padding: 6px 10px; border-radius: 20px;
            transition: all 0.15s;
        }
        .gh-logo:hover { background: rgba(0,0,0,0.45); }
        .gh-logo svg { width: 18px; height: 18px; fill: #fff; }
        @media (max-width: 720px) {
            html, body { overflow: auto; }
            .layout { grid-template-columns: 1fr; max-width: 440px; }
        }
    </style>
</head>
<body>
    <div class="layout">
        <!-- coluna esquerda: login (foco) -->
        <div class="card login">
            <div class="brand">
                <img src="/static/UFRB-20_assinatura_principal_preto.png" alt="UFRB">
                <h1>Sistema de Proje&ccedil;&otilde;es</h1>
                <div class="sub"><strong>CETENS</strong> &middot; UFRB &middot; Feira de Santana</div>
                <div class="divider"></div>
            </div>
            <div class="info-box">
                Espelhe a tela do seu computador no projetor da sala usando suas
                credenciais institucionais. Funciona em Windows ou Linux da UFRB.
            </div>
            {% if error %}
            <div class="error-msg">&#9888; {{ error }}</div>
            {% endif %}
            <form action="/login" method="post">
                <div class="form-group">
                    <label>SIAPE (usu&aacute;rio institucional)</label>
                    <input type="text" name="username" placeholder="Ex.: joao.silva"
                           required autofocus autocomplete="off">
                </div>
                <div class="form-group">
                    <label>Senha institucional (AD)</label>
                    <input type="password" name="password" placeholder="Sua senha da rede UFRB"
                           required autocomplete="off">
                </div>
                <button type="submit" class="btn-login">Acessar</button>
            </form>
        </div>

        <!-- coluna direita: cliente de proje&ccedil;&atilde;o -->
        <div class="card card-side">
            <h2>&#128229; Cliente de proje&ccedil;&atilde;o (Windows)</h2>
            <div class="side-desc">
                Baixe o app que espelha sua tela no projetor. Ao abrir, ele j&aacute; mostra
                um <strong>PIN</strong> na tela &mdash; use esse n&uacute;mero no login.
                N&atilde;o &eacute; preciso configurar nada.
            </div>
            <a class="btn-download" href="{{ vnc_download_url }}" download>
                &#11015; Baixar cliente (.exe)
            </a>
            <div class="side-warn">
                &#9888; Software de terceiros (TightVNC), pode ser sinalizado pelo navegador.
                &Eacute; <strong>autenticado e distribu&iacute;do pela UFRB/CETENS</strong>.
            </div>
            <div class="side-steps">
                <ol>
                    <li>Baixe e execute o <strong>caraprojetada-vnc.exe</strong>.</li>
                    <li>Anota o <strong>PIN</strong> que aparece na tela do app.</li>
                    <li>Fa&ccedil;a login aqui e clique em <strong>Conectar</strong>.</li>
                    <li>Informe o <strong>PIN</strong> mostrado pelo app.</li>
                </ol>
            </div>
            <div class="side-foot">
                <span>D&uacute;vidas? <a href="/ajuda">Veja o tutorial &rarr;</a></span>
            </div>
        </div>
    </div>

    <a class="gh-logo" href="https://github.com/Deivisan/caraprojetada" target="_blank" rel="noopener" title="Reposit&oacute;rio no GitHub">
        <svg viewBox="0 0 16 16" aria-hidden="true"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg>
        GitHub
    </a>
</body>
</html>"""

CONTROL_HTML = """<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sistema de Proje&ccedil;&otilde;es &mdash; Painel</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', 'Open Sans', system-ui, -apple-system, sans-serif;
            background: linear-gradient(135deg, #003366 0%, #005580 40%, #6A1B9A 100%);
            min-height: 100vh;
            padding: 20px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .panel-wrapper { max-width: 560px; width: 100%; }
        .panel-card {
            background: #fff;
            border-radius: 16px;
            padding: 36px;
            box-shadow: 0 8px 40px rgba(0,0,0,0.25);
            border-top: 5px solid #FFB300;
        }
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 24px;
            flex-wrap: wrap; gap: 12px;
        }
        .header-left { display: flex; align-items: center; gap: 0; }
        .header-left h1 {
            font-size: 18px; color: #003366; font-weight: 700;
            line-height: 1.2;
        }
        .header-left .sub { font-size: 11px; color: #888; }
        .user-badge {
            background: #e8f0f8;
            color: #003366;
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 12.5px;
            font-weight: 600;
            white-space: nowrap;
            max-width: 200px;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        .ip-box {
            background: #f0f4f8;
            border: 1px solid #d0dce8;
            border-radius: 10px;
            padding: 14px 18px;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
            flex-wrap: wrap;
        }
        .ip-box .label { font-size: 13px; color: #666; }
        .ip-box .value {
            font-size: 16px; font-weight: 700; color: #003366;
            font-family: 'Courier New', monospace;
        }
        .ip-box .os-tag {
            margin-left: auto;
            background: #e8f0f8; color: #003366;
            padding: 3px 10px; border-radius: 12px;
            font-size: 11px; font-weight: 600;
        }
        {% if session_active %}
        .session-card {
            background: #fef8e7;
            border: 1px solid #fde0a0;
            border-radius: 10px;
            padding: 16px 18px;
            margin-bottom: 20px;
        }
        .session-card .s-title {
            font-size: 12px; font-weight: 600; color: #8a6d00;
            text-transform: uppercase; letter-spacing: 0.5px;
            margin-bottom: 6px;
        }
        .session-card .s-detail {
            font-size: 14px; color: #5c4a00; line-height: 1.6;
        }
        .session-card .s-detail strong { color: #b8860b; }
        {% endif %}
        .connect-area {
            border: 1.5px dashed #c8d8e8;
            border-radius: 12px; padding: 24px;
            margin-bottom: 16px;
            background: #fafcfe;
        }
        .status-row {
            display: flex; align-items: center; gap: 8px;
            font-size: 13px; font-weight: 500; margin-bottom: 16px;
        }
        .dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; }
        .dot.green { background: #16a34a; box-shadow: 0 0 6px rgba(22,163,74,0.4); }
        .dot.yellow { background: #eab308; box-shadow: 0 0 6px rgba(234,179,8,0.4); }
        .dot.red { background: #dc2626; box-shadow: 0 0 6px rgba(220,38,38,0.4); }
        .btn-group {
            display: flex;
            gap: 12px;
            margin-top: 10px;
            flex-wrap: wrap;
        }
        .btn {
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.15s;
        }
        .btn-primary {
            background: linear-gradient(135deg, #003366, #005580);
            color: #fff;
            flex: 1;
        }
        .btn-primary:hover {
            background: linear-gradient(135deg, #004480, #006699);
            box-shadow: 0 4px 15px rgba(0,51,102,0.3);
        }
        .btn-danger {
            background: #fff;
            color: #991b1b;
            border: 1.5px solid #fecaca;
        }
        .btn-danger:hover { background: #fef2f2; }
        .btn-outline {
            background: #f3f4f6;
            color: #555;
            border: 1px solid #d0d5dd;
            font-size: 12px;
            padding: 8px 16px;
        }
        .btn-outline:hover { background: #e5e7eb; }
        .msg-box {
            border-radius: 10px; padding: 14px 18px;
            margin-top: 16px; font-size: 14px;
            background: #f0f4f8; border: 1px solid #d0dce8;
            color: #2c3e50;
            line-height: 1.6;
        }
        .msg-box.warning { background: #fef8e7; border-color: #fde0a0; color: #5c4a00; }
        .msg-box.error { background: #fef2f2; border-color: #fecaca; color: #991b1b; }
        .msg-box.success { background: #f0fdf4; border-color: #bbf7d0; color: #166534; }
        .pin-area {
            text-align: center;
            padding: 20px 10px 10px;
        }
        .pin-area .pin-label {
            display: block;
            font-size: 13px;
            font-weight: 600;
            color: #4a5568;
            margin-bottom: 10px;
            text-transform: uppercase;
            letter-spacing: 1.5px;
        }
        .pin-input {
            width: 180px !important;
            text-align: center;
            letter-spacing: 12px;
            font-size: 28px !important;
            font-weight: 700;
            color: #003366;
            padding: 14px 12px !important;
            border: 2px solid #cfe0f0 !important;
            transition: all 0.2s;
            margin: 0 auto;
            display: block;
        }
        .pin-input:focus {
            border-color: #003366 !important;
            box-shadow: 0 0 0 3px rgba(0,51,102,0.12) !important;
        }
        .footer {
            text-align: center; margin-top: 24px;
            font-size: 11px; color: #888; line-height: 1.6;
        }
        .footer strong { color: #003366; }
        @media (max-width: 500px) {
            .panel-card { padding: 20px; }
            .header { flex-direction: column; align-items: stretch; }
            .user-badge { align-self: flex-start; }
            .btn-group { flex-direction: column; }
            .btn { width: 100%; }
        }
    </style>
</head>
<body>
    <div class="panel-wrapper">
        <div class="panel-card">
            <div class="header">
                <div class="header-left">
                    <div>
                        <h1>Sistema de Proje&ccedil;&otilde;es</h1>
                        <div class="sub">UFRB &middot; CETENS</div>
                    </div>
                </div>
                <div class="user-badge" title="{{ user_fullname }}">&#128100; {{ user_fullname }}</div>
            </div>
            <div class="ip-box">
                <span class="label">&#127760; Seu IP</span>
                <span class="value">{{ user_ip }}</span>
                <span class="os-tag">{{ os_detect }}</span>
            </div>
            {% if session_active %}
            <div class="session-card">
                <div class="s-title">&#9654; Projetor em uso</div>
                <div class="s-detail">
                    <strong>{{ session_user_full }}</strong> ({{ session_user }})
                    desde {{ session_start }}<br>
                    {{ session_os }} &bull; {{ session_ip }}
                </div>
            </div>
            {% endif %}
            <div class="connect-area">
                <div class="status-row">
                    {% if session_active and session_user != username %}
                    <span class="dot red"></span>
                    Projetor ocupado por <strong>{{ session_user_full }}</strong>
                    {% elif session_active %}
                    <span class="dot yellow"></span>
                    Projetor em uso por voc&ecirc;
                    {% else %}
                    <span class="dot green"></span>
                    Projetor dispon&iacute;vel
                    {% endif %}
                </div>
                {% if not session_active %}
                <form action="/conectar" method="post">
                    <div class="pin-area">
                        <span class="pin-label">PIN de acesso</span>
                        <input type="text" name="pin" class="pin-input"
                               placeholder="&#8226;&#8226;&#8226;&#8226;"
                               required autocomplete="off"
                               inputmode="numeric" maxlength="4"
                               pattern="\\d{4}">
                    </div>
                    <button type="submit" class="btn btn-primary" style="width:100%;">
                        &#9654; Conectar ao Projetor
                    </button>
                </form>
                {% endif %}
                {% if session_active and session_user == username %}
                <div class="btn-group">
                    <form action="/desconectar" method="post" style="display:inline;width:100%;">
                        <button type="submit" class="btn btn-danger" style="width:100%;">
                            &#9632; Desconectar do Projetor
                        </button>
                    </form>
                </div>
                {% endif %}
            </div>
            {% if msg %}
            <div class="msg-box {% if 'Erro' in msg %}error{% elif 'Conectado' in msg or 'liberado' in msg %}success{% elif 'uso' in msg %}warning{% endif %}">
                {{ msg|safe }}
            </div>
            {% endif %}
            <div style="text-align:center;margin-top:16px;">
                <form action="/logout" method="post" style="display:inline;">
                    <button type="submit" class="btn btn-outline">Sair da sess&atilde;o</button>
                </form>
            </div>
            <div class="footer">
                <strong>UFRB</strong> &bull; Universidade Federal do Rec&ocirc;ncavo da Bahia<br>
                CETENS &bull; Centro de Ci&ecirc;ncia e Tecnologia em Energia e Sustentabilidade<br>
                Sistema de Proje&ccedil;&otilde;es &bull; <a href="/projetor" style="color:#008B9E;">Tela do Projetor</a>
            </div>
        </div>
    </div>
</body>
</html>"""

HELP_HTML = """<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Como usar &mdash; Sistema de Proje&ccedil;&otilde;es UFRB/CETENS</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body { height: 100%; overflow: hidden; }
        body {
            font-family: 'Segoe UI', 'Open Sans', system-ui, -apple-system, sans-serif;
            background: linear-gradient(135deg, #003366 0%, #005580 40%, #6A1B9A 100%);
            height: 100vh; display: flex; align-items: center; justify-content: center; padding: 16px;
        }
        .wrap { width: 100%; max-width: 760px; max-height: 94vh; overflow-y: auto; }
        .card {
            background: #fff; border-radius: 16px; padding: 28px 32px;
            box-shadow: 0 8px 40px rgba(0,0,0,0.25); border-top: 5px solid #008B9E;
        }
        .brand { margin-bottom: 16px; }
        .brand img { max-height: 40px; width: auto; margin-bottom: 8px; }
        .brand h1 { font-size: 19px; color: #003366; font-weight: 700; }
        .brand .sub { font-size: 12px; color: #666; }
        .brand .sub strong { color: #008B9E; }
        h2 { font-size: 15px; color: #005580; margin: 18px 0 8px; }
        p, li { font-size: 13px; color: #2c3e50; line-height: 1.6; }
        ol, ul { padding-left: 20px; }
        li { margin-bottom: 5px; }
        .step {
            display: flex; gap: 12px; align-items: flex-start; margin-bottom: 12px;
            background: #f0f4f8; border: 1px solid #d0dce8; border-radius: 10px; padding: 12px 14px;
        }
        .step .num {
            flex: 0 0 26px; height: 26px; border-radius: 50%; background: #003366; color: #fff;
            display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 13px;
        }
        .step .txt { font-size: 13px; color: #2c3e50; line-height: 1.55; }
        .step .txt strong { color: #003366; }
        .warn {
            font-size: 11.5px; color: #8a5a00; background: #fff7e6; border: 1px solid #ffe0a3;
            border-radius: 8px; padding: 10px 12px; margin: 14px 0; line-height: 1.55;
        }
        .btn-back {
            display: inline-block; margin-top: 16px; padding: 11px 22px; text-decoration: none;
            background: linear-gradient(135deg, #003366, #005580); color: #fff; border-radius: 8px;
            font-size: 14px; font-weight: 600;
        }
        .btn-back:hover { background: linear-gradient(135deg, #004480, #006699); }
        .btn-download-big {
            display: flex; align-items: center; justify-content: center; gap: 10px;
            width: 100%; padding: 15px; margin: 4px 0 4px; text-decoration: none; color: #fff;
            background: linear-gradient(135deg, #008B9E, #005580); border: none;
            border-radius: 10px; font-size: 16px; font-weight: 700; cursor: pointer; transition: all 0.15s;
        }
        .btn-download-big:hover { background: linear-gradient(135deg, #00a3b8, #006699); box-shadow: 0 4px 18px rgba(0,139,158,0.35); }
        .dl-note { font-size: 11.5px; color: #008B9E; text-align: center; margin-bottom: 6px; }
        .gh-logo {
            position: fixed; right: 14px; bottom: 12px; display: flex; align-items: center; gap: 6px;
            font-size: 11px; color: #fff; text-decoration: none; background: rgba(0,0,0,0.25);
            padding: 6px 10px; border-radius: 20px;
        }
        .gh-logo:hover { background: rgba(0,0,0,0.45); }
        .gh-logo svg { width: 18px; height: 18px; fill: #fff; }
    </style>
</head>
<body>
    <div class="wrap">
        <div class="card">
            <div class="brand">
                <img src="/static/UFRB-20_assinatura_principal_preto.png" alt="UFRB">
                <h1>Como usar o Sistema de Proje&ccedil;&otilde;es</h1>
                <div class="sub"><strong>CETENS</strong> &middot; UFRB &middot; Feira de Santana</div>
            </div>

            <p>O <strong>Sistema de Proje&ccedil;&otilde;es</strong> &eacute; a tela exibida no
            projetor da sala. Por ele voc&ecirc; espelha a tela do seu computador na TV, de forma
            segura, usando suas credenciais institucionais (AD/UFRB).</p>

            <a class="btn-download-big" href="{{ vnc_download_url }}" download>
                &#11015; Baixar cliente de proje&ccedil;&atilde;o (.exe)
            </a>
            <p class="dl-note">Arquivo port&aacute;til &mdash; n&atilde;o precisa instalar.</p>

            <h2>1. Abra o cliente no seu computador (Windows)</h2>
            <div class="step">
                <div class="num">1</div>
                <div class="txt">Execute o <strong>caraprojetada-vnc.exe</strong> que voc&ecirc; baixou.</div>
            </div>
            <div class="step">
                <div class="num">2</div>
                <div class="txt">Pronto: o app j&aacute; mostra um <strong>PIN</strong> na tela,
                sozinho. N&atilde;o &eacute; preciso configurar nada.</div>
            </div>
            <div class="step">
                <div class="num">3</div>
                <div class="txt">Mantenha o programa aberto durante a proje&ccedil;&atilde;o.</div>
            </div>

            <h2>2. Conecte no projetor</h2>
            <div class="step">
                <div class="num">4</div>
                <div class="txt">Na tela de login, informe seu <strong>SIAPE</strong> e senha
                institucional (AD).</div>
            </div>
            <div class="step">
                <div class="num">5</div>
                <div class="txt">Clique em <strong>Conectar</strong> e informe o <strong>PIN</strong>
                que aparece na tela do app.</div>
            </div>
            <div class="step">
                <div class="num">6</div>
                <div class="txt">Sua tela aparece no projetor. Ao terminar, clique em
                <strong>Desconectar</strong>.</div>
            </div>

            <div class="warn">
                &#9888; O <strong>caraprojetada-vnc.exe</strong> &eacute; um software de terceiros
                (TightVNC) e pode ser sinalizado pelo navegador como potencialmente inseguro.
                Ele &eacute; <strong>autenticado e distribu&iacute;do pela UFRB/CETENS</strong>
                para uso institucional.
            </div>

            <a class="btn-back" href="/">&larr; Voltar ao login</a>
        </div>
    </div>

    <a class="gh-logo" href="https://github.com/Deivisan/caraprojetada" target="_blank" rel="noopener" title="Reposit&oacute;rio no GitHub">
        <svg viewBox="0 0 16 16" aria-hidden="true"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg>
        GitHub
    </a>
</body>
</html>"""

PROJECTOR_IDLE_HTML = """<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Projetor — UFRB CETENS</title>
<style>
* { margin:0; padding:0; box-sizing:border-box; }
html, body { width:100%; height:100%; overflow:hidden; }
body {
 font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
 background: linear-gradient(160deg, #001a33 0%, #003366 30%, #004d80 60%, #002244 100%);
 color: #fff;
 display: flex;
 align-items: center;
 justify-content: center;
 cursor: none;
 user-select: none;
}

/* overlay animado */
body::before {
 content: '';
 position: fixed;
 top:0; left:0; width:100%; height:100%;
 background:
  radial-gradient(ellipse at 25% 50%, rgba(0,153,204,0.12) 0%, transparent 60%),
  radial-gradient(ellipse at 75% 50%, rgba(106,27,154,0.08) 0%, transparent 60%),
  radial-gradient(ellipse at 50% 0%, rgba(255,179,0,0.04) 0%, transparent 50%);
 animation: bgShift 10s ease-in-out infinite alternate;
 pointer-events: none;
}
@keyframes bgShift {
 0% { transform: scale(1); opacity:0.6; }
 100% { transform: scale(1.08); opacity:1; }
}

.container {
 position: relative;
 z-index: 2;
 text-align: center;
 padding: 40px;
 width: 100%;
 max-width: 900px;
}

/* logo */
.logo-wrap {
 margin-bottom: 56px;
}
.logo-wrap img {
 max-width: 380px;
 width: 90%;
 height: auto;
 filter: brightness(1.15);
}

/* status */
.status-area {
 margin-bottom: 48px;
}
.status-text {
 font-size: 48px;
 font-weight: 200;
 letter-spacing: 6px;
 color: rgba(255,255,255,0.85);
 animation: softPulse 4s ease-in-out infinite;
 text-shadow: 0 0 40px rgba(255,255,255,0.06);
}
@keyframes softPulse {
 0%, 100% { opacity:0.6; text-shadow: 0 0 20px rgba(255,255,255,0.03); }
 50% { opacity:1; text-shadow: 0 0 60px rgba(255,255,255,0.08); }
}

.indicator {
 display: inline-flex;
 align-items: center;
 gap: 12px;
 margin-top: 24px;
 padding: 10px 28px;
 background: rgba(255,255,255,0.05);
 border: 1px solid rgba(255,255,255,0.08);
 border-radius: 40px;
 backdrop-filter: blur(4px);
}
.indicator .pulse-dot {
 width: 10px; height: 10px;
 background: #22c55e;
 border-radius: 50%;
 animation: blinkLive 2s ease-in-out infinite;
}
@keyframes blinkLive {
 0%, 100% { opacity:1; box-shadow: 0 0 10px rgba(34,197,94,0.5); }
 50% { opacity:0.3; box-shadow: 0 0 2px rgba(34,197,94,0.1); }
}
.indicator .label {
 font-size: 13px;
 font-weight: 400;
 color: rgba(255,255,255,0.5);
 letter-spacing: 2px;
 text-transform: uppercase;
}

/* instrucoes minimalistas */
.hint {
 font-size: 13px;
 color: rgba(255,255,255,0.2);
 letter-spacing: 1px;
 margin-top: 16px;
}

/* clock */
.clock {
 position: absolute;
 top: 28px;
 right: 32px;
 font-size: 13px;
 font-weight: 300;
 color: rgba(255,255,255,0.2);
 font-family: 'Courier New', monospace;
 letter-spacing: 0.5px;
}

/* rodape */
.footer-bar {
 position: absolute;
 bottom: 28px;
 left: 50%; transform: translateX(-50%);
 font-size: 11px;
 color: rgba(255,255,255,0.15);
 letter-spacing: 2px;
 text-transform: uppercase;
 white-space: nowrap;
}

/* responsivo */
@media (max-width: 640px) {
 .status-text { font-size: 28px; letter-spacing: 3px; }
 .logo-wrap { margin-bottom: 36px; }
 .logo-wrap img { max-width: 260px; }
 .clock { top: 16px; right: 16px; font-size: 11px; }
 .indicator { padding: 8px 18px; }
 .indicator .label { font-size: 11px; }
}
</style>
</head>
<body>
<div class="container">
 <div class="logo-wrap">
  <img src="/static/UFRB-20_assinatura_principal_preto.png" alt="UFRB 20 anos &mdash; Universidade Federal do Rec&ocirc;ncavo da Bahia">
 </div>

 <div class="status-area">
  <div class="status-text" id="status-msg">Aguardando conex&atilde;o...</div>
  <div class="indicator">
   <span class="pulse-dot" id="status-dot"></span>
   <span class="label" id="status-label">Projetor dispon&iacute;vel</span>
  </div>
 </div>

 <div class="hint" id="hint-user"></div>
</div>

<div class="clock" id="clock"></div>
<div class="footer-bar">UFRB &middot; Universidade Federal do Rec&ocirc;ncavo da Bahia</div>

<script>
function pad(n) { return n<10?'0'+n:n; }
function updateClock() {
 var now = new Date();
 document.getElementById('clock').textContent =
  pad(now.getDate())+'/'+pad(now.getMonth()+1)+'/'+now.getFullYear()+'  '+
  pad(now.getHours())+':'+pad(now.getMinutes());
}
function updateStatus() {
 fetch('/api/v1/status').then(function(r){return r.json()}).then(function(d){
  var msg=document.getElementById('status-msg');
  var dot=document.getElementById('status-dot');
  var lbl=document.getElementById('status-label');
  var hint=document.getElementById('hint-user');
  if(d.active_session) {
   msg.textContent='Projetor em uso';
   dot.style.background='#eab308';
   dot.style.animation='blinkLive 1.5s ease-in-out infinite';
   lbl.textContent='Conectado a '+ (d.current_user_full||d.current_user||'alguem');
   hint.textContent='desde '+ (d.since||'') +' \u00b7 sessao remota ativa';
  } else {
   msg.textContent='Aguardando conex\u00e3o...';
   dot.style.background='#22c55e';
   dot.style.animation='blinkLive 2s ease-in-out infinite';
   lbl.textContent='Projetor dispon\u00edvel';
   hint.textContent='';
  }
 }).catch(function(){});
}
document.addEventListener('DOMContentLoaded', function(){
 updateClock(); updateStatus();
 setInterval(updateClock,60000);
 setInterval(updateStatus,15000);
});
</script>
</body>
</html>"""

# ══════════════════════════════════════════════════════════════════
# ROTAS
# ══════════════════════════════════════════════════════════════════

@app.route('/')
def index():
    if 'username' not in session:
        return render_template_string(LOGIN_HTML, vnc_download_url=VNC_DOWNLOAD_URL)
    disp, os_name = detect_os(request.headers.get('User-Agent', ''))
    fullname = session.get('user_fullname', session['username'])
    return render_template_string(CONTROL_HTML,
        user_ip=request.remote_addr,
        username=session['username'],
        user_fullname=fullname,
        os_detect=os_name,
        dev_mode=DEV_MODE,
        session_active=current_session['active'],
        session_user=current_session.get('username', ''),
        session_user_full=current_session.get('user_fullname', current_session.get('username', '')),
        session_start=current_session.get('started_at', ''),
        session_display=current_session.get('display', ''),
        session_os=current_session.get('os_type', ''),
        session_ip=current_session.get('user_ip', ''),
        msg='')

@app.route('/projetor')
def projetor_idle():
    try:
        saida = subprocess.check_output(['ip', '-4', 'addr', 'show', 'wlan0']).decode()
        ip_box = re.search(r'inet (\d+\.\d+\.\d+\.\d+)', saida)
        projector_ip = ip_box.group(1) if ip_box else '127.0.0.1'
    except Exception:
        projector_ip = '127.0.0.1'
    return render_template_string(PROJECTOR_IDLE_HTML, projector_ip=projector_ip)

@app.route('/ajuda')
def ajuda():
    return render_template_string(HELP_HTML)

@app.route('/login', methods=['POST'])
def login():
    username = request.form.get('username', '').strip().lower()
    password = request.form.get('password')
    if not username or not password:
        return render_template_string(LOGIN_HTML, error='Informe seu SIAPE e senha institucional.', vnc_download_url=VNC_DOWNLOAD_URL)
    username = re.sub(r'@.*$', '', username)
    ok, nome_completo, email = autenticar_ad(username, password)
    if ok:
        session['username'] = username
        session['user_fullname'] = nome_completo
        session['user_email'] = email
        return redirect('/')
    return render_template_string(LOGIN_HTML,
        error='SIAPE ou senha inv&aacute;lidos. Use suas credenciais institucionais (AD/UFRB).',
        vnc_download_url=VNC_DOWNLOAD_URL)

@app.route('/logout', methods=['POST'])
def logout():
    if current_session.get('username') == session.get('username'):
        # ─── Restaura resolução original do display ───
        orig_res = current_session.get('original_resolution')
        if orig_res:
            try:
                subprocess.run(
                    ['xrandr', '--output', 'HDMI-1', '--mode', orig_res],
                    timeout=5
                )
            except Exception:
                pass
        # ─── fim restauração ───
        subprocess.run(['pkill', '-9', 'xtightvncviewer'])
        registrar_log('DESCONECTOU_LOGOUT', f'SIAPE={session.get("username")}')
        current_session['active'] = False
        current_session['username'] = None
        current_session['user_ip'] = None
        current_session['display'] = None
        current_session['os_type'] = None
        current_session['started_at'] = None
        current_session['user_fullname'] = None
        current_session['original_resolution'] = None
    session.pop('username', None)
    session.pop('user_fullname', None)
    session.pop('user_email', None)
    return redirect('/')

@app.route('/conectar', methods=['POST'])
def conectar():
    if 'username' not in session:
        return redirect('/')
    pin = request.form.get('pin', '').strip()
    notebook_ip = request.remote_addr
    user = session['username']
    fullname = session.get('user_fullname', user)
    disp, os_name = detect_os(request.headers.get('User-Agent', ''))
    vnc_display = disp
    if current_session['active'] and current_session['username'] != user:
        msg = ('<strong>&#9888; Este projetor j&aacute; est&aacute; em uso!</strong><br>'
               f'Conectado por <strong>{current_session["user_fullname"]}</strong> '
               f'({current_session["username"]}) desde '
               f'{current_session["started_at"]}.<br><br>'
               'Aguarde at&eacute; que a sess&atilde;o atual seja encerrada '
               'para conectar sua tela.')
        return render_template_string(CONTROL_HTML,
            user_ip=notebook_ip, username=user, user_fullname=fullname,
            os_detect=os_name, dev_mode=DEV_MODE,
            session_active=True,
            session_user=current_session['username'],
            session_user_full=current_session.get('user_fullname', current_session['username']),
            session_start=current_session.get('started_at', ''),
            session_display=current_session.get('display', ''),
            session_os=current_session.get('os_type', ''),
            session_ip=current_session.get('user_ip', ''),
            msg=msg)
    # Mata sessão anterior e conecta
    subprocess.run(['pkill', '-9', 'xtightvncviewer'])
    # Comando otimizado: sem sudo (roda como root), quality baixo + compressão máxima
    # senha VNC vem do PIN informado pelo usuário (4 dígitos)
    comando = (f'echo "{pin}" | DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0 '
                f'/usr/bin/xtightvncviewer -autopass -quality 6 -compresslevel 9 '

               f'-fullscreen {notebook_ip}:{vnc_display}')
    try:
        proc = subprocess.Popen(comando, shell=True,
                                stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL)
        conectado = False
        # aguarda até estabelecer ou falhar (senha errada costuma sair em <3s)
        for _ in range(60):  # ate 6s
            if proc.poll() is not None:
                # processo saiu => falha (senha/PIN errado ou servidor VNC off)
                registrar_log('ERRO_CONECTAR',
                              f'SIAPE={user} rc={proc.returncode}')
                msg = ('<strong>&#9888; N&atilde;o foi poss&iacute;vel conectar.</strong><br>'
                       'Verifique se o PIN/senha do VNC est&aacute; correto e se o '
                       'servidor VNC est&aacute; ativo no seu computador.')
                return render_template_string(CONTROL_HTML,
                    user_ip=notebook_ip, username=user, user_fullname=fullname,
                    os_detect=os_name,
                    session_active=current_session['active'],
                    session_user=current_session.get('username', ''),
                    session_user_full=current_session.get('user_fullname', current_session.get('username', '')),
                    session_start=current_session.get('started_at', ''),
                    session_display=current_session.get('display', ''),
                    session_os=current_session.get('os_type', ''),
                    session_ip=current_session.get('user_ip', ''),
                    msg=msg)
            time.sleep(0.1)
        # nao saiu do loop => viewer continua rodando => conexao estabelecida
        conectado = True
        # ─── Ajuste de resolução: probe VNC + xrandr ───
        try:
            xrandr_out = subprocess.run(
                ['xrandr', '--current'],
                capture_output=True, text=True, timeout=5
            ).stdout
            # Extrai resolucao atual e modos suportados
            modos_suportados = set()
            for line in xrandr_out.splitlines():
                m_mode = re.search(r'^\s+(\d+x\d+)', line)
                if m_mode:
                    modos_suportados.add(m_mode.group(1))
                if 'HDMI-1' in line and '*' in line:
                    m_cur = re.search(r'(\d+)x(\d+)', line)
                    if m_cur:
                        orig_res = f'{m_cur.group(1)}x{m_cur.group(2)}'
                        current_session['original_resolution'] = orig_res
            # Prova resolucao real do notebook via VNC
            vnc_w, vnc_h = probe_vnc_resolution(notebook_ip, 5900)
            if vnc_w and vnc_h:
                nova_res = f'{vnc_w}x{vnc_h}'
                registrar_log('RES_PROBE',
                              f'notebook={nova_res} display={orig_res}')
                if nova_res != orig_res and nova_res in modos_suportados:
                    subprocess.run(
                        ['xrandr', '--output', 'HDMI-1', '--mode', nova_res],
                        timeout=5
                    )
                elif nova_res not in modos_suportados:
                    registrar_log('RES_PROBE',
                                  f'resolucao {nova_res} nao suportada pelo display')
            else:
                registrar_log('RES_PROBE', 'sem resposta VNC, mantem resolucao')
        except Exception as res_err:
            registrar_log('RES_ERRO', str(res_err))
        # ─── fim do ajuste de resolução ───
        current_session['active'] = True
        current_session['username'] = user
        current_session['user_fullname'] = fullname
        current_session['user_ip'] = notebook_ip
        current_session['display'] = vnc_display
        current_session['os_type'] = os_name
        current_session['started_at'] = datetime.now().strftime('%d/%m/%Y %H:%M')
        registrar_log('CONECTOU', f'SIAPE={user} nome="{fullname}" IP={notebook_ip} OS={os_name} display={vnc_display}')
        msg = '<strong>&#9989; Conectado com sucesso!</strong> Sua tela est&aacute; sendo exibida no projetor.'
    except Exception as e:
        registrar_log('ERRO_CONECTAR', f'SIAPE={user} erro={str(e)}')
        msg = f'<strong>Erro ao conectar:</strong> {str(e)}'
    return render_template_string(CONTROL_HTML,
        user_ip=notebook_ip, username=user, user_fullname=fullname,
        os_detect=os_name, dev_mode=DEV_MODE,
        session_active=current_session['active'],
        session_user=current_session.get('username', ''),
        session_user_full=current_session.get('user_fullname', ''),
        session_start=current_session.get('started_at', ''),
        session_display=current_session.get('display', ''),
        session_os=current_session.get('os_type', ''),
        session_ip=current_session.get('user_ip', ''),
        msg=msg)

@app.route('/desconectar', methods=['POST'])
def desconectar():
    if 'username' not in session:
        return redirect('/')
    user = session['username']
    fullname = session.get('user_fullname', user)
    subprocess.run(['pkill', '-9', 'xtightvncviewer'])
    # ─── Restaura resolução original do display ───
    orig_res = current_session.get('original_resolution')
    if orig_res:
        try:
            subprocess.run(
                ['xrandr', '--output', 'HDMI-1', '--mode', orig_res],
                timeout=5
            )
            registrar_log('RES_RESTORE', f'restaurado {orig_res}')
        except Exception as res_err:
            registrar_log('RES_ERRO', f'falha restore {orig_res}: {res_err}')
    # ─── fim restauração ───
    registrar_log('DESCONECTOU', f'SIAPE={user} nome="{fullname}"')
    current_session['active'] = False
    current_session['username'] = None
    current_session['user_ip'] = None
    current_session['display'] = None
    current_session['os_type'] = None
    current_session['started_at'] = None
    current_session['user_fullname'] = None
    current_session['original_resolution'] = None
    disp, os_name = detect_os(request.headers.get('User-Agent', ''))
    return render_template_string(CONTROL_HTML,
        user_ip=request.remote_addr, username=user, user_fullname=fullname,
        os_detect=os_name, dev_mode=DEV_MODE,
        session_active=False,
        session_user='', session_user_full='',
        session_start='', session_display='', session_os='', session_ip='',
        msg='<strong>Projetor liberado.</strong> Voc&ecirc; pode fechar a p&aacute;gina.')

# ══════════════════════════════════════════════════════════════════
# API
# ══════════════════════════════════════════════════════════════════

@app.route('/download/vnc')
def download_vnc():
    """Serve o cliente VNC (tightvnc portatil) direto da box.
    fallback local sempre disponivel, independente do github."""
    import os.path as _osp
    if _osp.exists(VNC_BINARY_PATH):
        try:
            return send_file(
                VNC_BINARY_PATH,
                as_attachment=True,
                download_name='caraprojetada-vnc.exe',
                mimetype='application/octet-stream'
            )
        except TypeError:
            # flask 1.x usa attachment_filename em vez de download_name
            return send_file(
                VNC_BINARY_PATH,
                as_attachment=True,
                attachment_filename='caraprojetada-vnc.exe',
                mimetype='application/octet-stream'
            )
    return 'Cliente VNC indisponível nesta box.', 404


@app.route('/api/v1/status', methods=['GET'])
def api_status():
    return jsonify({
        'projector': 'carapreta-box',
        'ip': request.host,
        'online': True,
        'mode': 'PROD',
        'active_session': current_session['active'],
        'current_user': current_session.get('username'),
        'current_user_full': current_session.get('user_fullname'),
        'since': current_session.get('started_at'),
        'os': current_session.get('os_type'),
        'display': current_session.get('display'),
        'user_ip': current_session.get('user_ip'),
        'vnc_password': '[protegido]',
        'capabilities': ['vnc', 'autodetect-os', 'log-access', 'pin-required']
    })

@app.route('/api/v1/force-disconnect', methods=['POST'])
def api_force_disconnect():
    subprocess.run(['pkill', '-9', 'xtightvncviewer'])
    registrar_log('FORCE_DISCONNECT_API', 'por API')
    current_session['active'] = False
    current_session['username'] = None
    current_session['user_ip'] = None
    current_session['display'] = None
    current_session['os_type'] = None
    current_session['started_at'] = None
    current_session['user_fullname'] = None
    return jsonify({'success': True, 'message': 'Projetor liberado a forca'})

if __name__ == '__main__':
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    except:
        pass
    app.run(host='0.0.0.0', port=80)
