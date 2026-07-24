import os
import re
from datetime import datetime
from ldap3 import Server, Connection, ALL
from flask import Flask, render_template, request, jsonify, session, redirect, url_for
from flask_socketio import SocketIO, emit, join_room

app = Flask(__name__)
app.config['SECRET_KEY'] = 'chave_teste_webrtc'
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

AD_SERVER = os.environ.get('AD_SERVER', 'ldap://10.198.1.2')
AD_DOMAIN = os.environ.get('AD_DOMAIN', 'intranet.ufrb.edu.br')
AD_BASE_DN = os.environ.get('AD_BASE_DN', 'dc=intranet,dc=ufrb,dc=edu,dc=br')

def autenticar_ad(username, password):
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
                    attributes=['displayName', 'name', 'cn', 'mail']
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
    except Exception:
        return False, None, None

@app.route('/')
def index():
    if 'user' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        username = request.form.get('username', '').strip().lower()
        password = request.form.get('password', '')
        if not username or not password:
            error = 'Informe seu SIAPE e senha institucional.'
            return render_template('login.html', error=error)
        username = re.sub(r'@.*$', '', username)
        ok, nome_completo, email = autenticar_ad(username, password)
        if ok:
            session['user'] = username
            session['user_fullname'] = nome_completo
            session['user_email'] = email
            return redirect(url_for('dashboard'))
        else:
            error = 'SIAPE ou senha inválidos. Use suas credenciais institucionais (AD/UFRB).'
    return render_template('login.html', error=error)

@app.route('/dashboard')
def dashboard():
    if 'user' not in session:
        return redirect(url_for('login'))
    fullname = session.get('user_fullname', session['user'])
    return render_template('dashboard.html', username=fullname)

@app.route('/display')
def display():
    return render_template('display.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

# --- SINALIZAÇÃO WEBRTC ---
@socketio.on('join')
def on_join(data):
    room = data['room']
    join_room(room)
    print(f"Cliente entrou na sala: {room}")

@socketio.on('offer')
def handle_offer(data):
    emit('offer', data, room='tvbox')

@socketio.on('answer')
def handle_answer(data):
    emit('answer', data, room='professor')

@socketio.on('ice-candidate')
def handle_ice(data):
    target_room = 'tvbox' if data['target'] == 'tvbox' else 'professor'
    emit('ice-candidate', data['candidate'], room=target_room)

@socketio.on('stop-sharing')
def handle_stop_sharing():
    socketio.emit('professor-parou', room='tvbox')

@socketio.on('disconnect')
def handle_disconnect():
    socketio.emit('professor-desconectou', room='tvbox')

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5000, debug=False)
