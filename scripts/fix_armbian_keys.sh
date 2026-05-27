#!/bin/bash
# Corrige chaves GPG do Armbian para apt update funcionar
# Uso: ./fix_armbian_keys.sh

KEY_PATH="/etc/apt/trusted.gpg.d/armbian.gpg"
BACKUP_PATH="/etc/apt/trusted.gpg.d/armbian.gpg.bak"
TEMP_KEY="/tmp/armbian_fixed.gpg"

echo "Iniciando a correcao das chaves do Armbian..."

if [ ! -f "$KEY_PATH" ]; then
    echo "Erro: Arquivo $KEY_PATH nao encontrado."
    exit 1
fi

sudo cp "$KEY_PATH" "$BACKUP_PATH"
echo "Backup criado em $BACKUP_PATH"

cat "$KEY_PATH" | gpg --dearmor | sudo tee "$TEMP_KEY" > /dev/null

if [ $? -ne 0 ] || [ ! -s "$TEMP_KEY" ]; then
    gpg --no-default-keyring --keyring "$KEY_PATH" --export | sudo tee "$TEMP_KEY" > /dev/null
fi

sudo mv "$TEMP_KEY" "$KEY_PATH"
sudo chmod 644 "$KEY_PATH"

echo "Chave convertida com sucesso. Rodando apt update para validar..."
sudo apt update

echo "----------------------------------------------------"
echo "Se os avisos sumiram, remova o backup com:"
echo "sudo rm $BACKUP_PATH"
