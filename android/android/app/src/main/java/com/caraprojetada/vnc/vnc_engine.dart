library vnc_engine;

// método chamado pelo flutter para iniciar o droidVNC-NG como serviço
/*
 * O droidVNC-NG roda como app separado.
 * Este modulo age como ponte: recebe intenção do flutter
 * e inicia o VNC via Intent API.
 */
