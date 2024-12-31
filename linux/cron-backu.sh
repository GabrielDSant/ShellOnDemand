#!/bin/bash

# Variáveis Gerais
BACKUP_SOURCE_DIR="/caminho/origem"
BACKUP_DEST_HOST="destino.host.com"
BACKUP_DEST_DIR="/caminho/destino"
BACKUP_USER="usuario_backup"
EMAIL="admin@empresa.com"
LOGFILE="/tmp/backup_log.log"

# Limpar log anterior
echo "Iniciando backup em $(date)" > "$LOGFILE"

# Verificar se o diretório de origem existe
if [ -d "$BACKUP_SOURCE_DIR" ]; then
  echo "Diretório de origem encontrado: $BACKUP_SOURCE_DIR" >> "$LOGFILE"
else
  echo "Erro: Diretório de origem não encontrado: $BACKUP_SOURCE_DIR" >> "$LOGFILE"
  echo "Falha no backup. Consulte o log: $LOGFILE" | mail -s "[FALHA] Backup Incremental" "$EMAIL"
  exit 1
fi

# Criar diretório no servidor de destino
ssh "$BACKUP_USER@$BACKUP_DEST_HOST" "mkdir -p $BACKUP_DEST_DIR" >> "$LOGFILE" 2>&1
if [ $? -ne 0 ]; then
  echo "Erro ao criar diretório no destino: $BACKUP_DEST_DIR" >> "$LOGFILE"
  echo "Falha no backup. Consulte o log: $LOGFILE" | mail -s "[FALHA] Backup Incremental" "$EMAIL"
  exit 1
fi

# Fazer backup dos arquivos usando rsync
echo "Iniciando transferência de arquivos..." >> "$LOGFILE"
rsync -avz --delete "$BACKUP_SOURCE_DIR/" "$BACKUP_USER@$BACKUP_DEST_HOST:$BACKUP_DEST_DIR" >> "$LOGFILE" 2>&1
if [ $? -ne 0 ]; then
  echo "Erro durante a transferência de arquivos." >> "$LOGFILE"
  echo "Falha no backup. Consulte o log: $LOGFILE" | mail -s "[FALHA] Backup Incremental" "$EMAIL"
  exit 1
fi

echo "Backup concluído com sucesso em $(date)." >> "$LOGFILE"
echo "Backup concluído com sucesso." | mail -s "[SUCESSO] Backup Incremental" "$EMAIL"

# Finalização
echo "Log finalizado em $(date)" >> "$LOGFILE"
