from flask import Flask, render_template_string, request, session, redirect, jsonify
import subprocess
import time
from datetime import datetime
import os
import re

# ldap3 é opcional — necessário apenas em PROD
try:
    from ldap3 import Server, Connection, ALL
    LDAP_DISPONIVEL = True
except ImportError:
    LDAP_DISPONIVEL = False

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'chave_secreta_projecoes_ufrb_cetens')

# ── MODO DE DESENVOLVIMENTO ─────────────────────────────────────
CARAPROJETADA_ENV = os.environ.get('CARAPROJETADA_ENV', 'prod')
DEV_MODE = CARAPROJETADA_ENV == 'dev'

AD_SERVER = os.environ.get('AD_SERVER', 'ldap://10.198.1.2')
AD_DOMAIN = os.environ.get('AD_DOMAIN', 'intranet.ufrb.edu.br')
AD_BASE_DN = os.environ.get('AD_BASE_DN', 'dc=intranet,dc=ufrb,dc=edu,dc=br')
LOG_FILE = os.environ.get('LOG_FILE', '/var/log/projetor-acessos.log')

current_session = {
    'active': False,
    'username': None,
    'user_ip': None,
    'display': None,
    'os_type': None,
    'started_at': None,
    'user_fullname': None
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
    if DEV_MODE:
        print(f'[DEV LOG] {linha}')
        return
    try:
        with open(LOG_FILE, 'a') as f:
            f.write(linha + '\n')
    except:
        pass

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
            try:
                conn.search(
                    search_base=AD_BASE_DN,
                    search_filter=f'(sAMAccountName={username})',
                    attributes=['displayName', 'name', 'cn', 'mail']
                )
                if conn.entries:
                    entry = conn.entries[0]
                    for attr in ['displayName', 'name', 'cn']:
                        if hasattr(entry, attr) and entry[attr].value:
                            nome_completo = entry[attr].value
                            break
            except:
                pass
            conn.unbind()
            registrar_log('LOGIN_OK', f'nome="{nome_completo}"')
            return True, nome_completo
        return False, None
    except Exception as e:
        registrar_log('LOGIN_ERRO', f'erro={str(e)}')
        return False, None

def autenticar_ad_completo(username, password):
    if DEV_MODE:
        if username == 'admin' and password == 'admin':
            return True, 'Administrador DEV', 'admin@dev.local'
        if password == 'dev' or username == password:
            return True, username.title() + ' (DEV)', f'{username}@dev.local'
        return False, None, None

    if not LDAP_DISPONIVEL:
        return False, None, None

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
            return True, nome_completo, email
        return False, None, None
    except Exception as e:
        return False, None, None

# ══════════════════════════════════════════════════════════════════
# TEMPLATES HTML (LOGIN + PAINEL DE CONTROLE)
# ══════════════════════════════════════════════════════════════════
# ── PÁGINA DE LOGIN ──────────────────────────────────────────────
LOGIN_HTML = """<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sistema de Projeções &mdash; UFRB &middot; CETENS</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', 'Open Sans', system-ui, -apple-system, sans-serif;
            background: linear-gradient(135deg, #003366 0%, #005580 40%, #6A1B9A 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .login-wrapper { max-width: 520px; width: 100%; }
        .login-card {
            background: #fff;
            border-radius: 16px;
            padding: 40px 36px;
            box-shadow: 0 8px 40px rgba(0,0,0,0.25);
            border-top: 5px solid #FFB300;
        }
        .brand {
            text-align: center;
            margin-bottom: 28px;
        }
        .brand img {
            max-width: 240px;
            height: auto;
            margin-bottom: 14px;
        }
        .brand h1 {
            font-size: 22px;
            color: #003366;
            font-weight: 700;
            letter-spacing: -0.3px;
        }
        .brand .sub {
            font-size: 13px;
            color: #666;
            margin-top: 2px;
        }
        .brand .sub strong {
            color: #008B9E;
        }
        .brand .divider {
            width: 60px;
            height: 3px;
            background: linear-gradient(90deg, #003366, #008B9E, #6A1B9A, #FFB300);
            margin: 14px auto 0;
            border-radius: 3px;
        }
        .info-box {
            background: #f0f4f8;
            border: 1px solid #d0dce8;
            border-radius: 10px;
            padding: 16px 18px;
            margin-bottom: 20px;
            font-size: 13.5px;
            color: #2c3e50;
            line-height: 1.7;
        }
        .info-box strong { color: #003366; }
        .info-box .highlight {
            display: inline-block;
            background: #FFB300;
            color: #003366;
            font-weight: 700;
            padding: 0 6px;
            border-radius: 3px;
        }
        .form-group {
            margin-bottom: 18px;
        }
        .form-group label {
            display: block;
            font-size: 13px;
            font-weight: 600;
            color: #444;
            margin-bottom: 6px;
        }
        .form-group input {
            width: 100%;
            padding: 13px 14px;
            border: 1.5px solid #d0d5dd;
            border-radius: 8px;
            font-size: 15px;
            transition: all 0.2s;
            outline: none;
            background: #fafafa;
        }
        .form-group input:focus {
            border-color: #003366;
            background: #fff;
            box-shadow: 0 0 0 3px rgba(0,51,102,0.10);
        }
        .btn-login {
            width: 100%;
            padding: 14px;
            background: linear-gradient(135deg, #003366, #005580);
            color: #fff;
            border: none;
            border-radius: 8px;
            font-size: 15px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
            margin-top: 4px;
        }
        .btn-login:hover {
            background: linear-gradient(135deg, #004480, #006699);
            box-shadow: 0 4px 15px rgba(0,51,102,0.3);
        }
        .btn-login:active {
            transform: scale(0.98);
        }
        .error-msg {
            background: #fef2f2;
            color: #991b1b;
            padding: 12px 16px;
            border-radius: 8px;
            font-size: 14px;
            margin-bottom: 18px;
            border: 1px solid #fecaca;
        }
        .footer {
            text-align: center;
            margin-top: 24px;
            font-size: 11.5px;
            color: #888;
            line-height: 1.7;
        }
        .footer strong { color: #003366; }

        @media (max-width: 500px) {
            .login-card { padding: 24px 18px; }
        }
    </style>
</head>
<body>
    <div class="login-wrapper">
        <div class="login-card">
            <div class="brand">
                <div style="display:flex;justify-content:center;align-items:center;margin-bottom:16px;">
                    <img src="/static/UFRB-20_assinatura_principal_preto.png"
                         alt="UFRB"
                         style="max-height:52px;width:auto;">
                </div>
                <h1>Sistema de Proje&ccedil;&otilde;es</h1>
                <div class="sub"><strong>CETENS</strong> &middot; UFRB &middot; Feira de Santana</div>
                <div class="divider"></div>
            </div>

            <div class="info-box">
                <strong>&#128161; Para que serve este sistema?</strong><br>
                Este sistema permite que voc&ecirc; <strong>espelhe a tela do seu computador</strong>
                no projetor multim&iacute;dia da sala, utilizando suas credenciais institucionais.
                Funciona em computadores da UFRB com Windows ou Linux.<br><br>
                <strong>&#128272; Acesso:</strong> informe seu <span class="highlight">SIAPE</span>
                (nome de usu&aacute;rio da rede UFRB) e sua senha institucional (AD).
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
                <button type="submit" class="btn-login">Acessar o Sistema de Proje&ccedil;&otilde;es</button>
            </form>

            <div class="footer">
                <strong>Universidade Federal do Rec&ocirc;ncavo da Bahia</strong><br>
                Centro de Ci&ecirc;ncia e Tecnologia em Energia e Sustentabilidade &bull; CETENS<br>
                Sistema de Proje&ccedil;&otilde;es
            </div>
        </div>
    </div>
</body>
</html>"""

# ── PAINEL DE CONTROLE ───────────────────────────────────────────
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
        .dot.green {
            background: #16a34a;
            box-shadow: 0 0 6px rgba(22,163,74,0.4);
        }
        .dot.yellow {
            background: #eab308;
            box-shadow: 0 0 6px rgba(234,179,8,0.4);
        }
        .dot.red {
            background: #dc2626;
            box-shadow: 0 0 6px rgba(220,38,38,0.4);
        }

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
        .msg-box.warning {
            background: #fef8e7; border-color: #fde0a0; color: #5c4a00;
        }
        .msg-box.error {
            background: #fef2f2; border-color: #fecaca; color: #991b1b;
        }
        .msg-box.success {
            background: #f0fdf4; border-color: #bbf7d0; color: #166534;
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
   <div class="sub">UFRB &middot; CETENS{% if dev_mode %} <span style="color:#FFB300;font-weight:600;">&middot; DEV</span>{% endif %}</div>
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

                <form action="/conectar" method="post" style="display:inline;">
                    <input type="hidden" name="ip" value="{{ user_ip }}">
                    <button type="submit" class="btn btn-primary">
                        {% if session_active and session_user != username %}
                            &#9888; Assumir Projetor
                        {% else %}
                            &#9654; Conectar Tela ao Projetor
                        {% endif %}
                    </button>
                </form>

 {% if session_active and session_user == username %}
 <div class="btn-group">
  {% if dev_mode %}
  <a href="/vnc-view" class="btn btn-outline" style="text-decoration:none;text-align:center;">
   🖥️ Ver Tela VNC (DEV)
  </a>
  {% endif %}
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


# ── TELA DO PROJETOR (IDLE SCREEN 24/7) ────────────────────────────
PROJECTOR_IDLE_HTML = """<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Projetor — Sistema de Projeções</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700;900&display=swap');
* { margin: 0; padding: 0; box-sizing: border-box; }
html, body { width: 100%; height: 100%; overflow: hidden; }
body {
 font-family: 'Inter', 'Segoe UI', system-ui, sans-serif;
 background: linear-gradient(135deg, #001a33 0%, #003366 35%, #005580 65%, #002233 100%);
 color: #fff;
 display: flex;
 align-items: center;
 justify-content: center;
 cursor: none;
 user-select: none;
}
.scene {
 width: 100%; height: 100%;
 display: flex; flex-direction: column;
 align-items: center; justify-content: center;
 position: relative;
}

/* ── Partículas animadas (fundo) ── */
.particles {
 position: absolute; top: 0; left: 0; width: 100%; height: 100%;
 pointer-events: none; overflow: hidden;
}
.particle {
 position: absolute;
 width: 4px; height: 4px;
 background: rgba(255,179,0,0.3);
 border-radius: 50%;
 animation: floatUp linear infinite;
}
@keyframes floatUp {
 0% { transform: translateY(100vh) scale(0); opacity: 0; }
 10% { opacity: 1; }
 90% { opacity: 1; }
 100% { transform: translateY(-10vh) scale(1); opacity: 0; }
}

/* ── Logo / Identidade ── */
.identity {
 text-align: center;
 margin-bottom: 48px;
 position: relative;
 z-index: 2;
}
.identity .logo-icon {
 width: 80px; height: 80px;
 margin: 0 auto 20px;
 background: linear-gradient(135deg, #FFB300, #FF8F00);
 border-radius: 20px;
 display: flex; align-items: center; justify-content: center;
 font-size: 40px;
 box-shadow: 0 8px 32px rgba(255,179,0,0.3);
 animation: pulse 3s ease-in-out infinite;
}
@keyframes pulse {
 0%, 100% { transform: scale(1); box-shadow: 0 8px 32px rgba(255,179,0,0.3); }
 50% { transform: scale(1.05); box-shadow: 0 12px 48px rgba(255,179,0,0.5); }
}
.identity h1 {
 font-size: 36px;
 font-weight: 900;
 letter-spacing: -1px;
 text-shadow: 0 2px 12px rgba(0,0,0,0.3);
}
.identity .org {
 font-size: 16px;
 font-weight: 300;
 color: rgba(255,255,255,0.7);
 margin-top: 6px;
 letter-spacing: 2px;
 text-transform: uppercase;
}

/* ── Instruções de conexão ── */
.connect-info {
 text-align: center;
 position: relative; z-index: 2;
 max-width: 700px;
}
.connect-info .step-grid {
 display: grid;
 grid-template-columns: repeat(3, 1fr);
 gap: 24px;
 margin-bottom: 40px;
}
.step-card {
 background: rgba(255,255,255,0.08);
 backdrop-filter: blur(10px);
 border: 1px solid rgba(255,255,255,0.12);
 border-radius: 16px;
 padding: 24px 16px;
 text-align: center;
 transition: all 0.3s;
}
.step-card:hover {
 background: rgba(255,255,255,0.14);
 transform: translateY(-2px);
}
.step-num {
 width: 32px; height: 32px;
 background: linear-gradient(135deg, #FFB300, #FF8F00);
 border-radius: 50%;
 display: flex; align-items: center; justify-content: center;
 font-weight: 700; font-size: 14px; color: #003366;
 margin: 0 auto 12px;
}
.step-card h3 {
 font-size: 14px; font-weight: 600;
 margin-bottom: 6px;
}
.step-card p {
 font-size: 12px; color: rgba(255,255,255,0.6);
 line-height: 1.5;
}

/* ── URL grande ── */
.url-display {
 background: rgba(0,0,0,0.3);
 border: 2px solid rgba(255,179,0,0.4);
 border-radius: 16px;
 padding: 20px 32px;
 display: inline-block;
 margin-bottom: 24px;
 animation: glow 4s ease-in-out infinite;
}
@keyframes glow {
 0%, 100% { border-color: rgba(255,179,0,0.3); box-shadow: 0 0 20px rgba(255,179,0,0.1); }
 50% { border-color: rgba(255,179,0,0.7); box-shadow: 0 0 40px rgba(255,179,0,0.2); }
}
.url-display .url-label {
 font-size: 11px; text-transform: uppercase;
 letter-spacing: 2px; color: rgba(255,255,255,0.5);
 margin-bottom: 6px;
}
.url-display .url-value {
 font-size: 28px; font-weight: 700;
 font-family: 'Courier New', monospace;
 color: #FFB300;
 letter-spacing: 1px;
}
.url-display .url-hint {
 font-size: 11px; color: rgba(255,255,255,0.4);
 margin-top: 4px;
}

/* ── Status ── */
.status-bar {
 position: absolute;
 bottom: 32px;
 left: 50%; transform: translateX(-50%);
 display: flex; align-items: center; gap: 10px;
 background: rgba(0,0,0,0.25);
 padding: 8px 20px;
 border-radius: 20px;
 font-size: 12px;
}
.status-dot {
 width: 8px; height: 8px;
 border-radius: 50%;
 animation: blink 2s ease-in-out infinite;
}
.status-dot.available { background: #16a34a; }
.status-dot.in-use { background: #eab308; }
@keyframes blink {
 0%, 100% { opacity: 1; }
 50% { opacity: 0.4; }
}
.status-text { color: rgba(255,255,255,0.6); }

/* ── Hora ── */
.clock {
 position: absolute;
 top: 24px; right: 32px;
 font-size: 14px;
 font-weight: 300;
 color: rgba(255,255,255,0.3);
 font-family: 'Courier New', monospace;
}

/* ── Responsivo ── */
@media (max-width: 768px) {
 .connect-info .step-grid { grid-template-columns: 1fr; gap: 12px; }
 .identity h1 { font-size: 24px; }
 .url-display .url-value { font-size: 18px; }
 .step-card { padding: 16px 12px; }
}
</style>
</head>
<body>
<div class="scene">
 <!-- Partículas -->
 <div class="particles" id="particles"></div>

 <!-- Relógio -->
 <div class="clock" id="clock"></div>

 <!-- Identidade -->
 <div class="identity">
  <div class="logo-icon">🎬</div>
  <h1>Sistema de Projeções</h1>
  <div class="org">UFRB · CETENS · Feira de Santana</div>
 </div>

 <!-- Instruções -->
 <div class="connect-info">
  <div class="step-grid">
   <div class="step-card">
    <div class="step-num">1</div>
    <h3>Acesse o endereço</h3>
    <p>Abra o navegador do seu computador e digite o endereço abaixo</p>
   </div>
   <div class="step-card">
    <div class="step-num">2</div>
    <h3>Faça login</h3>
    <p>Use seu SIAPE e senha institucional da rede UFRB</p>
   </div>
   <div class="step-card">
    <div class="step-num">3</div>
    <h3>Conecte ao projetor</h3>
    <p>Clique em "Conectar Tela" e sua tela será espelhada automaticamente</p>
   </div>
  </div>

  <div class="url-display">
   <div class="url-label">Endereço de acesso</div>
   <div class="url-value">http://{{ projector_ip }}</div>
   <div class="url-hint">Digite no navegador do seu computador na rede UFRB</div>
  </div>
 </div>

 <!-- Status -->
 <div class="status-bar">
  <span class="status-dot {% if session_active %}in-use{% else %}available{% endif %}"></span>
  <span class="status-text">
   {% if session_active %}
    Projetor em uso por {{ session_user_full }} · desde {{ session_start }}
   {% else %}
    Projetor disponível · Aguardando conexão
   {% endif %}
  </span>
 </div>
</div>

<script>
// Partículas animadas
(function() {
 const container = document.getElementById('particles');
 for (let i = 0; i < 30; i++) {
  const p = document.createElement('div');
  p.className = 'particle';
  p.style.left = Math.random() * 100 + '%';
  p.style.animationDuration = (8 + Math.random() * 12) + 's';
  p.style.animationDelay = Math.random() * 10 + 's';
  p.style.width = p.style.height = (2 + Math.random() * 4) + 'px';
  container.appendChild(p);
 }
})();

// Relógio
function updateClock() {
 const now = new Date();
 document.getElementById('clock').textContent =
  now.toLocaleDateString('pt-BR') + '  ' +
  now.toLocaleTimeString('pt-BR', {hour:'2-digit', minute:'2-digit'});
}
updateClock();
setInterval(updateClock, 30000);

// Polling de status a cada 30s
setInterval(function() {
 fetch('/api/v1/status').then(r => r.json()).then(data => {
  location.reload();
 }).catch(() => {});
}, 30000);
</script>
</body>
</html>"""

# ── EMULAÇÃO VNC (MODO DEV) ──────────────────────────────────────
VNC_VIEWER_HTML = """<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>VNC Viewer — Emulação DEV</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap');
* { margin: 0; padding: 0; box-sizing: border-box; }
html, body { width: 100%; height: 100%; overflow: hidden; background: #000; }
body {
 font-family: 'Inter', 'Segoe UI', system-ui, sans-serif;
 display: flex; flex-direction: column;
}

/* ── Barra VNC superior ── */
.vnc-toolbar {
 background: linear-gradient(180deg, #1a1a2e, #16213e);
 padding: 8px 16px;
 display: flex; align-items: center; gap: 12px;
 border-bottom: 1px solid rgba(255,255,255,0.1);
 flex-shrink: 0;
 z-index: 10;
}
.vnc-toolbar .vnc-icon {
 width: 28px; height: 28px;
 background: linear-gradient(135deg, #003366, #005580);
 border-radius: 6px;
 display: flex; align-items: center; justify-content: center;
 font-size: 14px;
}
.vnc-toolbar .vnc-title {
 color: #fff; font-size: 13px; font-weight: 600;
}
.vnc-toolbar .vnc-subtitle {
 color: rgba(255,255,255,0.5); font-size: 11px;
}
.vnc-toolbar .vnc-status {
 margin-left: auto;
 display: flex; align-items: center; gap: 6px;
}
.vnc-toolbar .vnc-dot {
 width: 8px; height: 8px;
 border-radius: 50%;
 background: #16a34a;
 animation: vncBlink 2s ease-in-out infinite;
}
@keyframes vncBlink {
 0%, 100% { opacity: 1; box-shadow: 0 0 6px rgba(22,163,74,0.5); }
 50% { opacity: 0.5; box-shadow: none; }
}
.vnc-toolbar .vnc-status-text {
 color: rgba(255,255,255,0.6); font-size: 11px;
}
.vnc-toolbar .btn-vnc {
 background: rgba(255,255,255,0.1);
 color: #fff; border: 1px solid rgba(255,255,255,0.15);
 border-radius: 6px; padding: 4px 12px;
 font-size: 11px; cursor: pointer;
 transition: all 0.15s;
}
.vnc-toolbar .btn-vnc:hover { background: rgba(255,255,255,0.2); }
.vnc-toolbar .btn-vnc.danger { color: #f87171; border-color: rgba(248,113,113,0.3); }
.vnc-toolbar .btn-vnc.danger:hover { background: rgba(248,113,113,0.15); }

/* ── Área da tela simulada ── */
.vnc-screen {
 flex: 1;
 display: flex;
 align-items: center;
 justify-content: center;
 position: relative;
 background: #0a0a1a;
 overflow: hidden;
}

/* Desktop simulado */
.desktop-sim {
 width: 100%; height: 100%;
 background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
 display: flex; flex-direction: column;
 align-items: center; justify-content: center;
 position: relative;
}

/* Scanline VNC */
.scanline {
 position: absolute; top: 0; left: 0; width: 100%; height: 100%;
 background: repeating-linear-gradient(
  0deg,
  transparent, transparent 2px,
  rgba(0,0,0,0.03) 2px, rgba(0,0,0,0.03) 4px
 );
 pointer-events: none;
 z-index: 5;
}

/* Conteúdo do desktop */
.desktop-content {
 text-align: center;
 z-index: 2;
 max-width: 600px;
 padding: 40px;
}
.desktop-content .vnc-badge {
 display: inline-flex;
 align-items: center; gap: 8px;
 background: rgba(22,163,74,0.2);
 border: 1px solid rgba(22,163,74,0.4);
 border-radius: 20px;
 padding: 6px 16px;
 font-size: 12px;
 color: #4ade80;
 margin-bottom: 24px;
}
.desktop-content .vnc-badge .dot {
 width: 6px; height: 6px;
 border-radius: 50%;
 background: #4ade80;
 animation: vncBlink 1.5s ease-in-out infinite;
}
.desktop-content h2 {
 font-size: 22px; font-weight: 700;
 color: #fff;
 margin-bottom: 8px;
 text-shadow: 0 2px 8px rgba(0,0,0,0.3);
}
.desktop-content .user-info {
 font-size: 14px; color: rgba(255,255,255,0.6);
 margin-bottom: 32px;
}
.desktop-content .desktop-preview {
 background: rgba(255,255,255,0.05);
 border: 1px solid rgba(255,255,255,0.1);
 border-radius: 12px;
 padding: 32px;
 width: 400px;
 margin: 0 auto;
}
.desktop-preview .screen-icon {
 font-size: 48px;
 margin-bottom: 12px;
}
.desktop-preview p {
 color: rgba(255,255,255,0.4);
 font-size: 13px;
 line-height: 1.6;
}
.desktop-preview .note {
 color: #FFB300;
 font-size: 11px;
 margin-top: 12px;
}

/* Barra de tarefas simulada */
.taskbar {
 position: absolute;
 bottom: 0; left: 0; width: 100%;
 background: rgba(10,10,26,0.95);
 border-top: 1px solid rgba(255,255,255,0.08);
 padding: 4px 16px;
 display: flex; align-items: center;
 gap: 12px; z-index: 6;
}
.taskbar .tb-start {
 background: linear-gradient(135deg, #003366, #005580);
 color: #fff; border: none;
 border-radius: 4px; padding: 4px 12px;
 font-size: 11px; font-weight: 600;
 cursor: default;
}
.taskbar .tb-app {
 display: flex; align-items: center; gap: 4px;
 background: rgba(255,255,255,0.08);
 border: 1px solid rgba(255,255,255,0.1);
 border-radius: 4px; padding: 3px 10px;
 font-size: 10px; color: rgba(255,255,255,0.7);
}
.taskbar .tb-app.active {
 background: rgba(0,51,102,0.3);
 border-color: rgba(0,85,128,0.5);
 color: #fff;
}
.taskbar .tb-clock {
 margin-left: auto;
 font-size: 11px;
 color: rgba(255,255,255,0.5);
 font-family: 'Courier New', monospace;
}

/* ── DEV watermark ── */
.dev-watermark {
 position: absolute;
 top: 50%; left: 50%;
 transform: translate(-50%, -50%) rotate(-30deg);
 font-size: 120px;
 font-weight: 900;
 color: rgba(255,179,0,0.05);
 pointer-events: none;
 white-space: nowrap;
 z-index: 3;
 letter-spacing: 10px;
}
</style>
</head>
<body>
<!-- Toolbar VNC -->
<div class="vnc-toolbar">
 <div class="vnc-icon">🖥️</div>
 <div>
  <div class="vnc-title">TightVNC Viewer</div>
  <div class="vnc-subtitle">{{ connected_ip }}:{{ vnc_display }}</div>
 </div>
 <div class="vnc-status">
  <span class="vnc-dot"></span>
  <span class="vnc-status-text">Conectado · {{ elapsed_time }}</span>
 </div>
 <button class="btn-vnc" onclick="window.open('/','_blank')">🧩 Painel</button>
 <form action="/desconectar" method="post" style="display:inline;">
  <button type="submit" class="btn-vnc danger">⏹ Desconectar</button>
 </form>
</div>

<!-- Tela VNC -->
<div class="vnc-screen">
 <div class="dev-watermark">DEV MODE</div>
 <div class="scanline"></div>

 <div class="desktop-sim">
  <div class="desktop-content">
   <div class="vnc-badge">
    <span class="dot"></span>
    Conexão VNC ativa — Tela sendo espelhada no projetor
   </div>
   <h2>Tela de {{ user_fullname }}</h2>
   <div class="user-info">
    SIAPE: {{ username }} · IP: {{ connected_ip }} · {{ os_type }}
   </div>

   <div class="desktop-preview">
    <div class="screen-icon">💻</div>
    <p>
     <strong>Em produção</strong>, esta área mostraria a tela real
     do computador do usuário, capturada via VNC e exibida
     no projetor em fullscreen.
    </p>
    <p class="note">
     ⚡ Modo DEV: a conexão VNC é simulada.<br>
     O comando real seria:<br>
     <code style="font-size:10px;background:rgba(0,0,0,0.3);padding:2px 6px;border-radius:3px;">
      xtightvncviewer {{ connected_ip }}:{{ vnc_display }} -autopass
     </code>
    </p>
   </div>
  </div>

  <!-- Taskbar simulada -->
  <div class="taskbar">
   <div class="tb-start">⚑ Iniciar</div>
   <div class="tb-app active">🖥️ VNC — {{ connected_ip }}</div>
   <div class="tb-app">📁 Arquivos</div>
   <div class="tb-app">🌐 Navegador</div>
   <div class="tb-clock" id="tb-clock"></div>
  </div>
 </div>
</div>

<script>
// Relógio da taskbar
function updateClock() {
 const now = new Date();
 document.getElementById('tb-clock').textContent =
  now.toLocaleTimeString('pt-BR', {hour:'2-digit', minute:'2-digit'}) + ' · ' +
  now.toLocaleDateString('pt-BR');
}
updateClock();
setInterval(updateClock, 10000);

// Atualizar tempo decorrido
const startTime = new Date('{{ started_iso }}');
function updateElapsed() {
 const diff = Math.floor((Date.now() - startTime.getTime()) / 1000);
 const m = Math.floor(diff / 60);
 const s = diff % 60;
 const h = Math.floor(m / 60);
 // Atualizar texto se existir
 const statusText = document.querySelector('.vnc-status-text');
 if (statusText) {
  const elapsed = h > 0 ? h + 'h ' + (m%60) + 'min' : m + 'min ' + s + 's';
  statusText.textContent = 'Conectado · ' + elapsed;
 }
}
setInterval(updateElapsed, 1000);
updateElapsed();
</script>
</body>
</html>"""


 # ── ROTAS ────────────────────────────────────────────────────────

@app.route('/')
def index():
 if 'username' not in session:
  return render_template_string(LOGIN_HTML)

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

# ── TELA DO PROJETOR (IDLE SCREEN) ────────────────────────────────
@app.route('/projetor')
def projetor_idle():
 """Idle screen do projetor — fica 24/7 em fullscreen mostrando como conectar."""
 projector_ip = request.host
 return render_template_string(PROJECTOR_IDLE_HTML,
  projector_ip=projector_ip,
  session_active=current_session['active'],
  session_user_full=current_session.get('user_fullname', current_session.get('username', '')),
  session_start=current_session.get('started_at', ''))

# ── EMULAÇÃO VNC (MODO DEV) ──────────────────────────────────────
@app.route('/vnc-view')
def vnc_view():
 """Emulação visual da conexão VNC — mostra o que o projetor exibiria."""
 if not DEV_MODE:
  return redirect('/')
 if 'username' not in session and not current_session['active']:
  return redirect('/')

 elapsed = ''
 started_iso = datetime.now().isoformat()
 if current_session.get('started_at'):
  try:
   started_dt = datetime.strptime(current_session['started_at'], '%d/%m/%Y %H:%M')
   started_iso = started_dt.isoformat()
   diff = datetime.now() - started_dt
   total_sec = int(diff.total_seconds())
   m, s = divmod(total_sec, 60)
   h, m = divmod(m, 60)
   elapsed = f'{h}h {m}min' if h > 0 else f'{m}min {s}s'
  except:
   elapsed = '0min 0s'

 return render_template_string(VNC_VIEWER_HTML,
  connected_ip=current_session.get('user_ip', request.remote_addr),
  vnc_display=current_session.get('display', '0'),
  user_fullname=current_session.get('user_fullname', current_session.get('username', '')),
  username=current_session.get('username', ''),
  os_type=current_session.get('os_type', ''),
  elapsed_time=elapsed,
  started_iso=started_iso)

@app.route('/login', methods=['POST'])
def login():
    username = request.form.get('username', '').strip().lower()
    password = request.form.get('password')

    if not username or not password:
        return render_template_string(LOGIN_HTML,
            error='Informe seu SIAPE e senha institucional.')

    # Remove @ufrb.edu.br se o usuario digitou email completo
    username = re.sub(r'@.*$', '', username)

    ok, nome_completo, email = autenticar_ad_completo(username, password)

    if ok:
        session['username'] = username
        session['user_fullname'] = nome_completo
        session['user_email'] = email
        registrar_log('LOGIN_OK', f'SIAPE={username} nome="{nome_completo}" email={email}')
        return redirect('/')

    registrar_log('LOGIN_FALHA', f'tentativa SIAPE={username}')
    return render_template_string(LOGIN_HTML,
        error='SIAPE ou senha inv&aacute;lidos. Use suas credenciais institucionais (AD/UFRB).')

@app.route('/logout', methods=['POST'])
def logout():
    if current_session.get('username') == session.get('username'):
        if not DEV_MODE:
            subprocess.run('sudo pkill -9 xtightvncviewer', shell=True)
        registrar_log('DESCONECTOU_LOGOUT', f'SIAPE={session.get("username")}')
        current_session['active'] = False
        current_session['username'] = None
        current_session['user_ip'] = None
        current_session['display'] = None
        current_session['os_type'] = None
        current_session['started_at'] = None
        current_session['user_fullname'] = None
    session.pop('username', None)
    session.pop('user_fullname', None)
    session.pop('user_email', None)
    return redirect('/')

@app.route('/conectar', methods=['POST'])
def conectar():
    if 'username' not in session:
        return redirect('/')

    notebook_ip = request.form.get('ip')
    user = session['username']
    fullname = session.get('user_fullname', user)

    # Detecta SO automaticamente - sem seletor manual
    disp, os_name = detect_os(request.headers.get('User-Agent', ''))
    vnc_display = disp

    # Se outro usuario esta usando, avisa e permite assumir
    if current_session['active'] and current_session['username'] != user:
        msg = (
            '<strong>&#9888; Este projetor j&aacute; est&aacute; em uso!</strong><br>'
            f'Conectado por <strong>{current_session["user_fullname"]}</strong> '
            f'({current_session["username"]}) desde '
            f'{current_session["started_at"]}.<br><br>'
            'Clique novamente em <strong>Assumir Projetor</strong> para '
            'desconect&aacute;-lo e conectar sua tela.'
        )
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

    # Conecta
    subprocess.run('sudo pkill -9 xtightvncviewer', shell=True)
    comando = f'echo "123456" | DISPLAY=:0 sudo /usr/bin/xtightvncviewer {notebook_ip}:{vnc_display} -autopass'

    # Atualiza sessão ANTES de qualquer redirect
    current_session['active'] = True
    current_session['username'] = user
    current_session['user_fullname'] = fullname
    current_session['user_ip'] = notebook_ip
    current_session['display'] = vnc_display
    current_session['os_type'] = os_name
    current_session['started_at'] = datetime.now().strftime('%d/%m/%Y %H:%M')
    registrar_log('CONECTOU', f'SIAPE={user} nome="{fullname}" IP={notebook_ip} OS={os_name} display={vnc_display}')

    if DEV_MODE:
        registrar_log('VNC_SIMULADO', f'comando="{comando}"')
        # Redireciona para a emulação visual VNC
        return redirect('/vnc-view')
    else:
        try:
            subprocess.Popen(comando, shell=True)
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

    if not DEV_MODE:
        subprocess.run('sudo pkill -9 xtightvncviewer', shell=True)
    registrar_log('DESCONECTOU', f'SIAPE={user} nome="{fullname}"')
    current_session['active'] = False
    current_session['username'] = None
    current_session['user_ip'] = None
    current_session['display'] = None
    current_session['os_type'] = None
    current_session['started_at'] = None
    current_session['user_fullname'] = None

    disp, os_name = detect_os(request.headers.get('User-Agent', ''))
    return render_template_string(CONTROL_HTML,
        user_ip=request.remote_addr, username=user, user_fullname=fullname,
        os_detect=os_name, dev_mode=DEV_MODE,
        session_active=False,
        session_user='', session_user_full='',
        session_start='', session_display='', session_os='', session_ip='',
        msg='<strong>Projetor liberado.</strong> Voc&ecirc; pode fechar a p&aacute;gina.')

# ── ENDPOINT DE RESET (DEV) ──────────────────────────────────────

if DEV_MODE:
    @app.route('/api/dev/reset', methods=['POST'])
    def dev_reset():
        current_session['active'] = False
        current_session['username'] = None
        current_session['user_ip'] = None
        current_session['display'] = None
        current_session['os_type'] = None
        current_session['started_at'] = None
        current_session['user_fullname'] = None
        registrar_log('DEV_RESET', 'Sessao resetada pelo modo DEV')
        return jsonify({'success': True, 'message': 'Sessao resetada (DEV)'})

# ── API ──────────────────────────────────────────────────────────

@app.route('/api/v1/status', methods=['GET'])
def api_status():
    return jsonify({
        'projector': 'carapreta-box',
        'ip': request.host,
        'online': True,
        'mode': 'DEV' if DEV_MODE else 'PROD',
        'active_session': current_session['active'],
        'current_user': current_session.get('username'),
        'current_user_full': current_session.get('user_fullname'),
        'since': current_session.get('started_at'),
        'os': current_session.get('os_type'),
        'display': current_session.get('display'),
        'user_ip': current_session.get('user_ip'),
        'vnc_password': '123456' if not DEV_MODE else '***dev***',
        'capabilities': ['vnc', 'autodetect-os', 'log-access']
    })

@app.route('/api/v1/force-disconnect', methods=['POST'])
def api_force_disconnect():
    subprocess.run('sudo pkill -9 xtightvncviewer', shell=True)
    registrar_log('FORCE_DISCONNECT_API', f'por API')
    current_session['active'] = False
    current_session['username'] = None
    current_session['user_ip'] = None
    current_session['display'] = None
    current_session['os_type'] = None
    current_session['started_at'] = None
    current_session['user_fullname'] = None
    return jsonify({'success': True, 'message': 'Projetor liberado a forca'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', '5000' if DEV_MODE else '80'))
    host = os.environ.get('HOST', '127.0.0.1' if DEV_MODE else '0.0.0.0')

    if DEV_MODE:
        print('=' * 50)
        print('  CARAPROJETADA — MODO DEV')
        print('  Auth: admin/admin ou qualquer user com senha dev')
        print('  VNC:  simulado (apenas log)')
        print(f'  URL:  http://{host}:{port}')
        print('=' * 50)
    else:
        try:
            os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        except:
            pass
        init_x_server()

    app.run(host=host, port=port, debug=DEV_MODE)
