#!/bin/bash

# Defina o caminho para o error log do MySQL
ERROR_LOG="/var/log/mysql/error.log"
ULTIMA_CHECAGEM="/tmp/ultima_checagem_error_log"

# Data e hora da última linha lida
if [[ -f "$ULTIMA_CHECAGEM" ]]; then
    ultima_data=$(cat $ULTIMA_CHECAGEM)
else
    ultima_data=$(date '+%Y-%m-%d %H:%M:%S' -d "1 hour ago")
fi

# Procurar erros no error log desde a última checagem
erros_error_log=$(awk -v ultima_data="$ultima_data" '$0 > ultima_data && /ERROR/' "$ERROR_LOG")

# Enviar alerta se erros forem encontrados
if [[ ! -z "$erros_error_log" ]]; then
    echo "$erros_error_log" > /tmp/alert_erro_error_log.log
fi

# Atualizar a última data de checagem
date '+%Y-%m-%d %H:%M:%S' > $ULTIMA_CHECAGEM