#!/bin/bash

# Variáveis de conexão
USUARIO="seu_usuario"
SENHA="sua_senha"
BANCO="seu_database"

# Limite de uso (%) para alertar
LIMITE=90

# Verificar o espaço nas tablespaces
espaco_tablespaces=$(mysql -u "$USUARIO" -p"$SENHA" -e "
SELECT table_schema AS 'Database', 
ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' 
FROM information_schema.tables 
GROUP BY table_schema 
HAVING ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) > $LIMITE;
")

# Enviar alerta se alguma tablespace estiver acima do limite
if [[ ! -z "$espaco_tablespaces" ]]; then
    echo "$espaco_tablespaces" > /tmp/alert_tablespace.log
fi