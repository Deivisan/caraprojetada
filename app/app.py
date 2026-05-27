from flask import Flask, render_template_string, request, session, redirect
from ldap3 import Server, Connection, ALL
import subprocess
import time

app = Flask(__name__)
app.secret_key = 'chave_secreta_para_sessoes_vnc_projetor'  # Mude para qualquer string segura

# ================= CONFIGURACOES DO ACTIVE DIRECTORY =================
AD_SERVER = 'ldap://10.198.1.2'   # IP ou Hostname do seu Domain Controller
AD_DOMAIN = 'intranet.ufrb.edu.br'  # Seu dominio do AD (ex: ufrb.edu.br)
# =====================================================================

LOGIN_HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>Autenticacao - Projetor</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 80px; background: #222; color: #fff; }
        .login-box { display: inline-block; background: #333; padding: 30px; border-radius: 8px; box-shadow: 0px 4px 10px rgba(0,0,0,0.5); }
        input[type="text"], input[type="password"] { width: 90%; padding: 10px; margin: 10px 0; border: 1px solid #555; background: #444; color: #fff; border-radius: 4px; }
        .btn { background-color: #4CAF50; border: none; color: white; padding: 12px 20px; cursor: pointer; border-radius: 4px; font-weight: bold; width: 100%; font-size: 16px; }
        .btn:hover { background-color: #45a049; }
        .error { color: #ff6b6b; margin-top: 15px; font-weight: bold; }
    </style>
</head>
<body>
    <div class="login-box">
        <h2>Acesso ao Projetor</h2>
        <form action="/login" method="post">
            <input type="text" name="username" placeholder="Usuario Institucional" required><br>
            <input type="password" name="password" placeholder="Senha" required><br>
            <button type="submit" class="btn">ACESSAR</button>
        </form>
        {% if error %} <p class="error">{{ error }}</p> {% endif %}
    </div>
</body>
</html>
"""

CONTROL_HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>Painel Projetor</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; background: #222; color: #fff; }
        .btn { border: none; color: white; padding: 15px 32px; text-align: center; display: inline-block; font-size: 16px; margin: 10px 5px; cursor: pointer; border-radius: 8px; font-weight: bold; width: 200px; }
        .btn-connect { background-color: #008CBA; } .btn-connect:hover { background-color: #007399; }
        .btn-disconnect { background-color: #f44336; } .btn-disconnect:hover { background-color: #da190b; }
        .btn-logout { background-color: #555; padding: 8px 15px; width: auto; font-size: 14px; position: absolute; top: 10px; right: 10px; }
        .info { color: #aaa; margin-top: 20px; font-weight: bold; }
    </style>
</head>
<body>
    <form action="/logout" method="post"><button type="submit" class="btn btn-logout">Sair ({{ username }})</button></form>
    <h2>Controle do Projetor</h2>
    <p>Seu IP detectado: <strong>{{ user_ip }}</strong></p>
    <div>
        <form action="/conectar" method="post" style="display: inline-block;">
            <input type="hidden" name="ip" value="{{ user_ip }}">
            <button type="submit" class="btn btn-connect">CONECTAR TELA</button>
        </form>
        <form action="/desconectar" method="post" style="display: inline-block;">
            <button type="submit" class="btn btn-disconnect">DESCONECTAR</button>
        </form>
    </div>
    {% if msg %} <p class="info">{{ msg }}</p> {% endif %}
</body>
</html>
"""

def init_x_server():
    subprocess.run('sudo pkill -9 xtightvncviewer', shell=True)
    subprocess.Popen('sudo xinit /bin/sleep infinity -- :0 -nocursor', shell=True)
    time.sleep(1)

def autenticar_ad(username, password):
    try:
        user_principal = f"{username}@{AD_DOMAIN}"
        server = Server(AD_SERVER, get_info=ALL)
        conn = Connection(server, user=user_principal, password=password, authentication='SIMPLE')
        if conn.bind():
            conn.unbind()
            return True
        return False
    except Exception:
        return False

@app.route('/')
def index():
    if 'username' not in session:
        return render_template_string(LOGIN_HTML)
    return render_template_string(CONTROL_HTML, user_ip=request.remote_addr, username=session['username'])

@app.route('/login', methods=['POST'])
def login():
    username = request.form.get('username')
    password = request.form.get('password')

    if autenticar_ad(username, password):
        session['username'] = username
        return redirect('/')
    return render_template_string(LOGIN_HTML, error="Usuario ou senha institucionais invalidos.")

@app.route('/logout', methods=['POST'])
def logout():
    session.pop('username', None)
    return redirect('/')

@app.route('/conectar', methods=['POST'])
def conectar():
    if 'username' not in session:
        return redirect('/')
    notebook_ip = request.form.get('ip')
    subprocess.run('sudo pkill -9 xtightvncviewer', shell=True)
    comando = f'echo "123456" | DISPLAY=:0 sudo /usr/bin/xtightvncviewer {notebook_ip}:0 -autopass'
    try:
        subprocess.Popen(comando, shell=True)
        msg = f"Conectado por {session['username']}!"
    except Exception as e:
        msg = f"Erro: {str(e)}"
    return render_template_string(CONTROL_HTML, user_ip=notebook_ip, username=session['username'], msg=msg)

@app.route('/desconectar', methods=['POST'])
def desconectar():
    if 'username' not in session:
        return redirect('/')
    subprocess.run('sudo pkill -9 xtightvncviewer', shell=True)
    return render_template_string(CONTROL_HTML, user_ip=request.remote_addr, username=session['username'], msg="Projetor liberado.")

if __name__ == '__main__':
    init_x_server()
    app.run(host='0.0.0.0', port=80)
