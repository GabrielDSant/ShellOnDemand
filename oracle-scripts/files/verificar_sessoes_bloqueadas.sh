#!/bin/bash

# Variáveis de conexão
USUARIO="<USUARIO>"
SENHA="<SENHA>"
BANCO="<BANCO>"

# Comando para verificar sessões bloqueadas há mais de 2 minutos
sessoes_bloqueadas=$(sqlplus -s "$USUARIO/$SENHA@$BANCO" <<EOF
SET LINESIZE 200
SET FEEDBACK OFF
SELECT sid, blocking_session, seconds_in_wait
FROM v\$session
WHERE blocking_session IS NOT NULL
  AND seconds_in_wait > 120;
EXIT;
EOF
)

# Enviar alerta se houver sessões bloqueadas
if [[ ! -z "$sessoes_bloqueadas" ]]; then
    echo "$sessoes_bloqueadas" > /tmp/alert_sessoes_bloqueadas.log
fi
