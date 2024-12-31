#!/bin/bash

# Variáveis de conexão
USUARIO="<USUARIO>"
SENHA="<SENHA>"
BANCO="<BANCO>"

# Limite de uso (%) para alertar
LIMITE=90

# Função para verificar o espaço nas tablespaces
espaco_tablespaces=$(sqlplus -s "$USUARIO/$SENHA@$BANCO" <<EOF
SET LINESIZE 200
SET FEEDBACK OFF
SELECT tablespace_name, ROUND((used_space / total_space) * 100, 2) AS pct_usado
FROM (
    SELECT df.tablespace_name, df.bytes AS total_space, (df.bytes - free_space) AS used_space
    FROM dba_data_files df
    JOIN (SELECT tablespace_name, SUM(bytes) AS free_space FROM dba_free_space GROUP BY tablespace_name) fs
    ON df.tablespace_name = fs.tablespace_name
)
WHERE ROUND((used_space / total_space) * 100, 2) > $LIMITE;
EXIT;
EOF
)

# Enviar alerta se alguma tablespace estiver acima do limite
if [[ ! -z "$espaco_tablespaces" ]]; then
    echo "$espaco_tablespaces" > /tmp/alert_tablespace.log
fi
