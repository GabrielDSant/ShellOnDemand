#!/bin/bash

# Variáveis de conexão
USUARIO="seu_usuario"
SENHA="sua_senha"
BANCO="seu_database"

# Verificar blocos corrompidos
blocos_corrompidos=$(mysqlcheck -u "$USUARIO" -p"$SENHA" --databases "$BANCO" --check --extended)

# Enviar alerta se houver blocos corrompidos
if [[ ! -z "$blocos_corrompidos" ]]; then
    echo "$blocos_corrompidos" > /tmp/alert_blocos_corrompidos.log
fi