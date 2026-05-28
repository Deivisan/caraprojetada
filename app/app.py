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

    if DEV_MODE:
        registrar_log('VNC_SIMULADO', f'comando="{comando}"')
        msg = (
            '<strong>&#9989; MODO DEV — Conexão simulada!</strong><br>'
            f'Comando que seria executado:<br>'
            f'<code style="font-size:12px;background:#f0f0f0;padding:4px 8px;border-radius:4px;">'
            f'{comando}</code>'
        )
    else:
        try:
            subprocess.Popen(comando, shell=True)
            msg = '<strong>&#9989; Conectado com sucesso!</strong> Sua tela est&aacute; sendo exibida no projetor.'
        except Exception as e:
            registrar_log('ERRO_CONECTAR', f'SIAPE={user} erro={str(e)}')
            msg = f'<strong>Erro ao conectar:</strong> {str(e)}'

    current_session['active'] = True
    current_session['username'] = user
    current_session['user_fullname'] = fullname
    current_session['user_ip'] = notebook_ip
    current_session['display'] = vnc_display
    current_session['os_type'] = os_name
    current_session['started_at'] = datetime.now().strftime('%d/%m/%Y %H:%M')
    registrar_log('CONECTOU', f'SIAPE={user} nome="{fullname}" IP={notebook_ip} OS={os_name} display={vnc_display}')

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
