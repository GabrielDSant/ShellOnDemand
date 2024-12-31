#!/bin/bash

# Defina o caminho para o alert log do Oracle
ALERT_LOG="/caminho/para/alert_log.log"
ULTIMA_CHECAGEM="/tmp/ultima_checagem_alert_log"

# Data e hora da última linha lida
if [[ -f "$ULTIMA_CHECAGEM" ]]; then
    ultima_data=$(cat $ULTIMA_CHECAGEM)
else
    ultima_data=$(date '+%Y-%m-%d %H:%M:%S' -d "1 hour ago")
fi

# Procurar erros no alert log desde a última checagem
erros_alert_log=$(awk -v ultima_data="$ultima_data" '$0 > ultima_data && /ORA-/' "$ALERT_LOG")

# Enviar alerta se erros forem encontrados
if [[ ! -z "$erros_alert_log" ]]; then
    echo "$erros_alert_log" > /tmp/alert_erro_alert_log.log
fi

# Atualizar a última data de checagem
date '+%Y-%m-%d %H:%M:%S' > $ULTIMA_CHECAGEM
