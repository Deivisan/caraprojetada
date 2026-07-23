#!/usr/bin/env python3
"""
caraprojetada — Sistema de Projeções UFRB/CETENS
Arquitetura: Flask + Socket.IO + WebRTC
Modo: Standalone (box local) / Centralizado (tvbox.app)
"""

import os
import json
import logging
import time
import sys
from logging.handlers import RotatingFileHandler
from datetime import datetime

# Usar threading mode para compatibilidade com python3.9 + flask 1.1.2
# eventlet funciona mas tem warning de depreciação
ASYNC_MODE = os.environ.get('ASYNC_MODE', 'threading')
if ASYNC_MODE == 'eventlet':
    try:
        import eventlet
        eventlet.monkey_patch()
    except ImportError:
        ASYNC_MODE = 'threading'

from flask import (Flask, render_template, request, jsonify,
                   session, redirect, url_for)
from flask_socketio import SocketIO, emit, join_room

# ═══════════════════════════════════════════════════════════════
# CONFIGURAÇÃO
# ═══════════════════════════════════════════════════════════════

# Caminho base do projeto
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Ambiente
DEV_MODE = os.environ.get('CARAPROJETADA_ENV', 'prod') == 'dev'

# Servidor
HOST = os.environ.get('HOST', '0.0.0.0')
PORT = int(os.environ.get('PORT', 5000))
SECRET_KEY = os.environ.get('SECRET_KEY', 'ufrb-cetens-projecoes-2026')

# Sala atual (cada box tem sua própria)
SALA_ID = os.environ.get('SALA_ID', 'sala-101')
SALA_NOME = os.environ.get('SALA_NOME', 'Sala 101')
INSTITUICAO = os.environ.get('INSTITUICAO', 'CETENS — UFRB')

# URL para QR Code (auto-detectada se não informada)
QR_URL = os.environ.get('QR_URL', None)

# AD/LDAP
AD_SERVER = os.environ.get('AD_SERVER', 'ldap://10.198.1.2')
AD_DOMAIN = os.environ.get('AD_DOMAIN', 'intranet.ufrb.edu.br')
AD_BASE_DN = os.environ.get('AD_BASE_DN', 'dc=intranet,dc=ufrb,dc=edu,dc=br')

# Logging (usar /tmp/ com PID para evitar conflito de permissão)
import getpass as _getpass
_LOG_DIR = os.environ.get('LOG_DIR', '/tmp')
_LOG_USER = _getpass.getuser()
LOG_FILE = os.environ.get('LOG_FILE', os.path.join(_LOG_DIR, f'caraprojetada-{_LOG_USER}.log'))
LOG_LEVEL = logging.DEBUG if DEV_MODE else logging.INFO

# Configurações WebRTC
STUN_SERVERS = os.environ.get('STUN_SERVERS',
    '["stun:stun.l.google.com:19302","stun:stun1.l.google.com:19302"]')
ICE_SERVERS = json.dumps({
    'iceServers': [{"urls": url} for url in json.loads(STUN_SERVERS)]
})

# ═══════════════════════════════════════════════════════════════
# LOGGING (inicialização tardia no entrypoint)
# ═══════════════════════════════════════════════════════════════

logger = logging.getLogger('caraprojetada')
logger.setLevel(LOG_LEVEL)
logger.addHandler(logging.StreamHandler())

def _init_logging():
    """inicializa o log em arquivo (chamado no entrypoint)"""
    try:
        log_dir = os.path.dirname(LOG_FILE)
        if log_dir:
            os.makedirs(log_dir, exist_ok=True)
        handler = RotatingFileHandler(LOG_FILE, maxBytes=5*1024*1024, backupCount=3)
        handler.setFormatter(logging.Formatter(
            '%(asctime)s [%(levelname)s] %(message)s', datefmt='%Y-%m-%d %H:%M:%S'))
        logger.addHandler(handler)
    except Exception as e:
        logger.warning(f'Não foi possível criar log em arquivo: {e}')

# ═══════════════════════════════════════════════════════════════
# APP FACTORY
# ═══════════════════════════════════════════════════════════════

app = Flask(__name__)
app.config['SECRET_KEY'] = SECRET_KEY
app.config['TEMPLATES_AUTO_RELOAD'] = DEV_MODE

socketio = SocketIO(
    app,
    cors_allowed_origins="*",
    async_mode=ASYNC_MODE,
    ping_timeout=10,
    ping_interval=5,
    logger=DEV_MODE,
    engineio_logger=DEV_MODE
)

# ═══════════════════════════════════════════════════════════════
# ESTADO GLOBAL
# ═══════════════════════════════════════════════════════════════

# sessões ativas por sala: { sala_id: { username, started_at, sid_presenter } }
active_sessions = {}

# última offer por sala: { sala_id: offer_data }
last_offer = {}

# heartbeat tracking: { sid: last_ping_time }
heartbeats = {'_start': time.time()}

# ═══════════════════════════════════════════════════════════════
# FUNÇÕES AUXILIARES
# ═══════════════════════════════════════════════════════════════

def get_ip():
    """auto-detecta o IP da box para QR code"""
    if QR_URL:
        return QR_URL
    try:
        import subprocess
        saida = subprocess.check_output(['ip', '-4', 'addr', 'show', 'wlan0']).decode()
        import re
        ip = re.search(r'inet (\d+\.\d+\.\d+\.\d+)', saida)
        if ip:
            return f'http://{ip.group(1)}:{PORT}'
    except Exception:
        pass
    return f'http://localhost:{PORT}'


def registrar_log(evento, detalhes=''):
    """registra evento no log"""
    user = session.get('username', '-') if session else '-'
    ip = request.remote_addr if request else '-'
    logger.info(f'IP={ip} USER={user} EVENTO={evento} {detalhes}')


def autenticar_ad(username, password):
    """autentica contra AD/LDAP ou mock em dev"""
    if DEV_MODE:
        if username == 'admin' and password == 'admin':
            return True, 'Administrador'
        if password == 'dev' or username == password:
            return True, username.title() + ' (DEV)'
        return False, None

    try:
        from ldap3 import Server, Connection, ALL
        user_principal = f'{username}@{AD_DOMAIN}'
        server = Server(AD_SERVER, get_info=ALL)
        conn = Connection(server, user=user_principal,
                         password=password, authentication='SIMPLE')
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
            except Exception:
                pass
            conn.unbind()
            logger.info(f'LOGIN_OK user={username} nome={nome_completo}')
            return True, nome_completo
        return False, None
    except Exception as e:
        logger.error(f'LOGIN_ERRO user={username} erro={e}')
        return False, None


def get_salas():
    """retorna lista de salas disponíveis (configurável via JSON)"""
    salas_file = os.path.join(BASE_DIR, 'salas.json')
    if os.path.exists(salas_file):
        with open(salas_file) as f:
            return json.load(f)
    # fallback: sala única
    return [{
        'id': SALA_ID,
        'nome': SALA_NOME,
        'instituicao': INSTITUICAO,
        'ip': get_ip()
    }]


# ═══════════════════════════════════════════════════════════════
# ROTAS WEB
# ═══════════════════════════════════════════════════════════════

@app.route('/')
def index():
    """página inicial: redireciona conforme sessão"""
    if 'username' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))


@app.route('/login', methods=['GET', 'POST'])
def login():
    """tela de login institucional"""
    error = None
    if request.method == 'POST':
        username = request.form.get('username', '').strip().lower()
        password = request.form.get('password', '')
        if not username or not password:
            error = 'Informe seu SIAPE e senha institucional.'
        else:
            # remove domínio se digitado
            username = __import__('re').sub(r'@.*$', '', username)
            ok, nome_completo = autenticar_ad(username, password)
            if ok:
                session['username'] = username
                session['user_fullname'] = nome_completo
                session['login_time'] = datetime.now().isoformat()
                registrar_log('LOGIN_OK', f'nome="{nome_completo}"')
                return redirect(url_for('dashboard'))
            error = 'SIAPE ou senha inválidos. Use suas credenciais institucionais.'
            registrar_log('LOGIN_ERRO', f'user={username}')

    box_ip = get_ip()
    return render_template('login.html',
        error=error,
        instituicao=INSTITUICAO,
        sala_nome=SALA_NOME,
        qr_url=box_ip
    )


@app.route('/dashboard')
def dashboard():
    """painel do professor com salas disponíveis"""
    if 'username' not in session:
        return redirect(url_for('login'))

    salas = get_salas()
    box_ip = get_ip()

    return render_template('dashboard.html',
        username=session.get('user_fullname', session['username']),
        login_name=session['username'],
        salas=salas,
        qr_url=box_ip,
        ice_servers=ICE_SERVERS,
        instituicao=INSTITUICAO
    )


@app.route('/display')
def display():
    """tela da box no projetor (chromium kiosk)"""
    salas = get_salas()
    sala_atual = salas[0] if salas else {'id': SALA_ID, 'nome': SALA_NOME}
    box_ip = get_ip()

    return render_template('display.html',
        sala_id=sala_atual['id'],
        sala_nome=sala_atual['nome'],
        instituicao=INSTITUICAO,
        qr_url=box_ip,
        ice_servers=ICE_SERVERS
    )


@app.route('/logout')
def logout():
    """encerra sessão"""
    if 'username' in session:
        registrar_log('LOGOUT', f'user={session["username"]}')
    session.clear()
    return redirect(url_for('login'))


# ═══════════════════════════════════════════════════════════════
# API REST
# ═══════════════════════════════════════════════════════════════

@app.route('/api/status')
def api_status():
    """status geral da box"""
    sala = SALA_ID
    sessao = active_sessions.get(sala)
    return jsonify({
        'box': SALA_ID,
        'nome': SALA_NOME,
        'ip': get_ip(),
        'online': True,
        'sala': sala,
        'active': sessao is not None,
        'username': sessao['username'] if sessao else None,
        'since': sessao['started_at'] if sessao else None,
        'uptime': time.time() - heartbeats.get('_start', time.time()),
        'heartbeat_salas': {
            s: len([k for k, v in heartbeats.items()
                   if k.startswith(f'{s}_') and time.time() - v < 30])
            for s in [SALA_ID]
        }
    })


@app.route('/api/salas')
def api_salas():
    """lista todas as salas disponíveis"""
    salas = get_salas()
    resultado = []
    for s in salas:
        sessao = active_sessions.get(s['id'])
        resultado.append({
            **s,
            'active': sessao is not None,
            'username': sessao['username'] if sessao else None,
            'since': sessao['started_at'] if sessao else None
        })
    return jsonify({'salas': resultado, 'total': len(resultado)})


@app.route('/api/health')
def api_health():
    """healthcheck para monitoramento"""
    return jsonify({
        'status': 'ok',
        'sala': SALA_ID,
        'uptime': time.time() - heartbeats.get('_start', time.time()),
        'memory': __import__('resource').getrusage(__import__('resource').RUSAGE_SELF).ru_maxrss
    })


# ═══════════════════════════════════════════════════════════════
# SINALIZAÇÃO WEBRTC (SOCKET.IO)
# ═══════════════════════════════════════════════════════════════

@socketio.on('connect')
def handle_connect():
    logger.info(f'Socket conectado: {request.sid}')
    sid = request.sid
    if '_start' not in heartbeats:
        heartbeats['_start'] = time.time()


@socketio.on('join')
def on_join(data):
    """entra em uma sala: { sala: 'sala-101', tipo: 'display'|'presenter' }"""
    sala = data.get('sala', SALA_ID)
    tipo = data.get('tipo', 'presenter')
    join_room(sala)
    logger.info(f'{tipo} {request.sid} entrou na sala: {sala}')

    # se for display e houver offer pendente, reenvia
    if tipo == 'display' and sala in last_offer:
        logger.info(f'Reenviando offer pendente para display em {sala}')
        emit('offer', last_offer[sala], room=sala, include_self=False)


@socketio.on('offer')
def handle_offer(data):
    """offer WebRTC: encaminha para o display da sala"""
    sala = data.get('sala', SALA_ID)
    logger.info(f'Offer de {request.sid} para sala {sala}')
    last_offer[sala] = data
    emit('offer', data, room=sala, include_self=False)


@socketio.on('answer')
def handle_answer(data):
    """answer WebRTC: encaminha para o presenter da sala"""
    sala = data.get('sala', SALA_ID)
    logger.info(f'Answer de {request.sid} para sala {sala}')
    emit('answer', data, room=sala, include_self=False)


@socketio.on('ice-candidate')
def handle_ice(data):
    """ICE candidate: encaminha para a sala"""
    sala = data.get('sala', SALA_ID)
    logger.info(f'ICE de {request.sid} para sala {sala} (tipo={data.get("candidate", {}).get("candidate", "")[:50]}...)')
    emit('ice-candidate', data['candidate'], room=sala, include_self=False)


@socketio.on('session-start')
def handle_session_start(data):
    """professor iniciou transmissão: marca sessão ativa"""
    sala = data.get('sala', SALA_ID)
    username = data.get('username', 'desconhecido')
    fullname = data.get('fullname', username)
    active_sessions[sala] = {
        'username': username,
        'fullname': fullname,
        'started_at': datetime.now().strftime('%H:%M'),
        'sid_presenter': request.sid,
        'active_since': time.time()
    }
    logger.info(f'SESSION_START sala={sala} user={username}')
    # avisa o display que a sessão iniciou
    emit('session-active', {
        'sala': sala,
        'user': fullname,
        'since': active_sessions[sala]['started_at']
    }, room=sala, include_self=False)


@socketio.on('session-end')
def handle_session_end(data):
    """professor encerrou transmissão explicitamente"""
    sala = data.get('sala', SALA_ID)
    if sala in active_sessions:
        logger.info(f'SESSION_END sala={sala} user={active_sessions[sala]["username"]}')
        del active_sessions[sala]
    # limpa offer pendente (evita reenvio stale ao display reconectar)
    if sala in last_offer:
        del last_offer[sala]
    # avisa o display
    emit('session-ended', {'sala': sala}, room=sala, include_self=False)
    emit('professor-desconectou', room=sala, include_self=False)


@socketio.on('debug-ontrack')
def handle_debug_ontrack(data):
    sala = data.get('sala', SALA_ID)
    logger.info(f'[DISPLAY] ontrack streams={data.get("streamCount")} kind={data.get("kind")} ready={data.get("readyState")}')


@socketio.on('debug-video')
def handle_debug_video(data):
    logger.info(f'[VIDEO] srcObject={data.get("srcObject")} trackCount={data.get("trackCount")} paused={data.get("paused")} currentTime={data.get("currentTime")} readyState={data.get("readyState")} networkState={data.get("networkState")} videoWidth={data.get("videoWidth")} videoHeight={data.get("videoHeight")} trackReadyState={data.get("trackReadyState")} error={data.get("error")}')


@socketio.on('heartbeat')
def handle_heartbeat(data):
    """heartbeat do display: verifica se está vivo"""
    sala = data.get('sala', SALA_ID)
    heartbeats[f'{sala}_{request.sid}'] = time.time()


@socketio.on('disconnect')
def handle_disconnect():
    """socket desconectou: limpa sessão se for presenter"""
    sid = request.sid
    logger.warning(f'Socket desconectado: {sid}')

    # verifica se era um presenter com sessão ativa
    for sala, sessao in list(active_sessions.items()):
        if sessao.get('sid_presenter') == sid:
            logger.info(f'DISCONNECT limpando sessão sala={sala} user={sessao["username"]}')
            del active_sessions[sala]
            # limpa offer pendente
            if sala in last_offer:
                del last_offer[sala]
            emit('professor-desconectou', room=sala, include_self=False)
            break

    # limpa heartbeat
    for key in list(heartbeats.keys()):
        if key.endswith(sid):
            del heartbeats[key]


# ═══════════════════════════════════════════════════════════════
# THREAD DE LIMPEZA (heartbeat watchdog)
# ═══════════════════════════════════════════════════════════════

def _cleanup_loop():
    """thread que limpa sessões órfãs (sem heartbeat do display)"""
    while True:
        try:
            agora = time.time()
            # remove heartbeats antigos (mais de 60s)
            for key in list(heartbeats.keys()):
                if key != '_start' and agora - heartbeats[key] > 60:
                    del heartbeats[key]
        except Exception:
            pass
        time.sleep(15)


# ═══════════════════════════════════════════════════════════════
# ENTRYPOINT
# ═══════════════════════════════════════════════════════════════

if __name__ == '__main__':
    # inicializa logging em arquivo
    _init_logging()

    logger.info(f'🚀 caraprojetada WebRTC iniciando...')
    logger.info(f'   Sala: {SALA_ID} ({SALA_NOME})')
    logger.info(f'   Porta: {PORT}')
    logger.info(f'   Modo: {"DEV" if DEV_MODE else "PROD"}')
    logger.info(f'   Log: {LOG_FILE}')
    logger.info(f'   Async: {ASYNC_MODE}')

    # inicia thread de limpeza
    import threading
    t = threading.Thread(target=_cleanup_loop, daemon=True)
    t.start()

    # inicia servidor
    socketio.run(
        app,
        host=HOST,
        port=PORT,
        debug=DEV_MODE,
        use_reloader=False
    )
