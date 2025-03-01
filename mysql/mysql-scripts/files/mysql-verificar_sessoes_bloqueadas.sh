#!/bin/bash

# Variáveis de conexão
USUARIO="seu_usuario"
SENHA="sua_senha"
BANCO="seu_database"

# Verificar sessões bloqueadas
sessoes_bloqueadas=$(mysql -u "$USUARIO" -p"$SENHA" -e "
SELECT * FROM information_schema.processlist 
WHERE command = 'Sleep' AND time > 120;
")

# Enviar alerta se houver sessões bloqueadas
if [[ ! -z "$sessoes_bloqueadas" ]]; then
    echo "$sessoes_bloqueadas" > /tmp/alert_sessoes_bloqueadas.log
fi