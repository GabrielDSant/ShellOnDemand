#!/bin/bash

# Variáveis de conexão
USUARIO="<USUARIO>"
SENHA="<SENHA>"
BANCO="<BANCO>"

# Comando para verificar blocos corrompidos
blocos_corrompidos=$(sqlplus -s "$USUARIO/$SENHA@$BANCO" <<EOF
SET LINESIZE 200
SET FEEDBACK OFF
SELECT * FROM v\$database_block_corruption;
EXIT;
EOF
)

# Enviar alerta se houver blocos corrompidos
if [[ ! -z "$blocos_corrompidos" ]]; then
    echo "$blocos_corrompidos" > /tmp/alert_blocos_corrompidos.log
fi
