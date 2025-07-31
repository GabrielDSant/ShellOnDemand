#!/bin/bash

# Diretório de destino para os scripts
DEST_DIR="/usr/local/bin"

# Lista de scripts a serem transferidos
SCRIPTS=(
  "monitorar_tablespaces.sh"
  "verificar_sessoes_bloqueadas.sh"
  "verificar_blocos_corrompidos.sh"
  "monitorar_alert_log.sh"
  "mata_inativos.sh"
)

# Transferir scripts para o servidor
echo "Transferindo scripts para $DEST_DIR..."
for SCRIPT in "${SCRIPTS[@]}"; do
  if [ -f "$SCRIPT" ]; then
    cp "$SCRIPT" "$DEST_DIR/"
    chmod 0755 "$DEST_DIR/$(basename "$SCRIPT")"
    echo "Script $SCRIPT transferido com sucesso."
  else
    echo "Aviso: $SCRIPT não encontrado no diretório atual."
  fi
done

# Configurar cron para executar scripts
echo "Configurando tarefas no cron..."
CRON_FILE="/etc/cron.d/oracle_monitoring"

if [ ! -f "$CRON_FILE" ]; then
  touch "$CRON_FILE"
  chmod 0644 "$CRON_FILE"
fi

for SCRIPT in "${SCRIPTS[@]}"; do
  CRON_JOB="0 * * * * root $DEST_DIR/$SCRIPT"
  if ! grep -Fq "$CRON_JOB" "$CRON_FILE"; then
    echo "$CRON_JOB" >> "$CRON_FILE"
    echo "Cron configurado para $SCRIPT."
  else
    echo "Cron já configurado para $SCRIPT."
  fi
done

# Enviar alertas por e-mail para logs de erro
EMAIL="seu_email@example.com"

function send_alert {
  local LOG_FILE=$1
  local SUBJECT=$2

  if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
    mail -s "$SUBJECT" "$EMAIL" < "$LOG_FILE"
    echo "Alerta enviado: $SUBJECT."
  else
    echo "Nenhum alerta para $SUBJECT."
  fi
}

# Verificar e enviar alertas
send_alert "/tmp/alert_tablespace.log" "Alerta: Espaço em tablespaces"
send_alert "/tmp/alert_sessoes_bloqueadas.log" "Alerta: Sessões bloqueadas"
send_alert "/tmp/alert_blocos_corrompidos.log" "Alerta: Blocos de dados corrompidos"
send_alert "/tmp/alert_erro_alert_log.log" "Alerta: Erros no alert log"

echo "Script concluído."
