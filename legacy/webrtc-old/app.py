import os
import logging
from logging.handlers import RotatingFileHandler
from flask import Flask, render_template, request, jsonify, session, redirect, url_for
from flask_socketio import SocketIO, emit, join_room

log_handler = RotatingFileHandler('flask.log', maxBytes=5*1024*1024, backupCount=3)
log_handler.setFormatter(logging.Formatter('%(asctime)s [%(levelname)s] %(message)s', datefmt='%Y-%m-%d %H:%M:%S'))
logger = logging.getLogger('webrtc')
logger.setLevel(logging.DEBUG)
logger.addHandler(log_handler)
logger.addHandler(logging.StreamHandler())

app = Flask(__name__)
app.config['SECRET_KEY'] = 'chave_teste_webrtc'
#socketio = SocketIO(app, cors_allowed_origins="*")
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')
# --- AUTENTICAÇÃO COMENTADA PARA TESTES ---
def autenticar_ad(username, password):
    # Retorna True para qualquer combinação de usuário e senha digitada
    print(f"[TESTE] Ignorando AD. Autenticando automaticamente o usuário: {username}")
    return True

@app.route('/')
def index():
    if 'user' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        # O método agora sempre retorna True
        if autenticar_ad(username, password):
            session['user'] = username
            return redirect(url_for('dashboard'))
            
    return render_template('login.html', error=error)

@app.route('/dashboard')
def dashboard():
    # Se quiser testar direto sem passar pelo login, descomente a linha abaixo:
    # session['user'] = 'Professor_Teste'
    
    if 'user' not in session:
        return redirect(url_for('login'))
    return render_template('dashboard.html', username=session['user'])

@app.route('/display')
def display():
    # Rota local da TV Box (Chromium)
    return render_template('display.html')

@app.route('/logout')
def logout():
    session.pop('user', None)
    return redirect(url_for('login'))

# --- SINALIZAÇÃO WEBRTC ---
@socketio.on('connect')
def handle_connect():
    logger.info(f"Socket conectado: {request.sid}")

@socketio.on('join')
def on_join(data):
    room = data['room']
    join_room(room)
    logger.info(f"Cliente {request.sid} entrou na sala: {room}")

@socketio.on('offer')
def handle_offer(data):
    logger.info(f"OFFER recebida de {request.sid}")
    emit('offer', data, room='tvbox')

@socketio.on('answer')
def handle_answer(data):
    logger.info(f"ANSWER recebida de {request.sid}")
    emit('answer', data, room='professor')

@socketio.on('ice-candidate')
def handle_ice(data):
    target_room = 'tvbox' if data['target'] == 'tvbox' else 'professor'
    logger.debug(f"ICE candidate de {request.sid} -> {target_room}")
    emit('ice-candidate', data['candidate'], room=target_room)

@socketio.on('disconnect')
def handle_disconnect():
    logger.warning(f"Socket DESCONECTADO: {request.sid}")
    socketio.emit('professor-desconectou', room='tvbox')

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5000, debug=False)
