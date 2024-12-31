#!/bin/bash

# Variáveis Gerais
ORIGEM_USUARIO="seu_usuario"
ORIGEM_SENHA="sua_senha"
ORIGEM_DATABASE="seu_database"
ORIGEM_DIRECTORY="/caminho/diretorio_origem"
ORIGEM_DUMPFILE="seu_dumpfile.dmp"
ORIGEM_LOGFILE="seu_logfile.log"

DESTINO_USUARIO="seu_usuario"
DESTINO_SENHA="sua_senha"
DESTINO_DATABASE="seu_database"
DESTINO_DIRECTORY="/caminho/diretorio_destino"
DESTINO_DUMPFILE="seu_dumpfile.dmp"
DESTINO_LOGFILE="seu_logfile.log"

EMAIL="seu_email@example.com"
SMTP_HOST="smtp.example.com"
SMTP_PORT="587"
SMTP_USUARIO="usuario_smtp"
SMTP_SENHA="senha_smtp"
EMAIL_REMETENTE="no-reply@example.com"

# Exportação de Dados no Host de Origem
echo "Iniciando exportação de dados no host de origem..."
expdp "$ORIGEM_USUARIO/$ORIGEM_SENHA@$ORIGEM_DATABASE" \
  directory="$ORIGEM_DIRECTORY" \
  dumpfile="$ORIGEM_DUMPFILE" \
  logfile="$ORIGEM_LOGFILE"

if grep -q "ORA-" "$ORIGEM_DIRECTORY/$ORIGEM_LOGFILE"; then
  echo "Erro durante a exportação. Verifique o log: $ORIGEM_DIRECTORY/$ORIGEM_LOGFILE"
  exit 1
fi

# Verificação do Dump
if [ ! -f "$ORIGEM_DIRECTORY/$ORIGEM_DUMPFILE" ]; then
  echo "Arquivo de dump não encontrado: $ORIGEM_DIRECTORY/$ORIGEM_DUMPFILE"
  exit 1
fi

# Transferência de Dump para o Destino
echo "Transferindo dump para o host destino..."
cp "$ORIGEM_DIRECTORY/$ORIGEM_DUMPFILE" "$DESTINO_DIRECTORY/"

# Importação de Dados no Host de Destino
echo "Iniciando importação de dados no host de destino..."
impdp "$DESTINO_USUARIO/$DESTINO_SENHA@$DESTINO_DATABASE" \
  directory="$DESTINO_DIRECTORY" \
  dumpfile="$DESTINO_DUMPFILE" \
  logfile="$DESTINO_LOGFILE"

if grep -q "ORA-" "$DESTINO_DIRECTORY/$DESTINO_LOGFILE"; then
  echo "Erro durante a importação. Verifique o log: $DESTINO_DIRECTORY/$DESTINO_LOGFILE"
  exit 1
fi

if ! grep -q "successfully completed" "$DESTINO_DIRECTORY/$DESTINO_LOGFILE"; then
  echo "Importação não foi concluída com sucesso. Verifique o log: $DESTINO_DIRECTORY/$DESTINO_LOGFILE"
  exit 1
fi

# Verificação e Recompilação de Objetos Inválidos
echo "Verificando e recompilando objetos inválidos no destino..."
SQLPLUS_LOG="/tmp/invalid_objects_recompilation.log"
echo "SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF" > recompilar.sql
echo "SPOOL $SQLPLUS_LOG" >> recompilar.sql
echo "BEGIN" >> recompilar.sql
echo "  FOR obj IN (SELECT owner, object_name, object_type FROM dba_objects WHERE status = 'INVALID') LOOP" >> recompilar.sql
echo "    EXECUTE IMMEDIATE 'ALTER ' || obj.object_type || ' ' || obj.owner || '.' || obj.object_name || ' COMPILE';" >> recompilar.sql
echo "  END LOOP;" >> recompilar.sql
echo "END;" >> recompilar.sql
echo "SPOOL OFF" >> recompilar.sql
echo "EXIT;" >> recompilar.sql

sqlplus -s "$DESTINO_USUARIO/$DESTINO_SENHA@$DESTINO_DATABASE" @recompilar.sql

if grep -q "ORA-" "$SQLPLUS_LOG"; then
  echo "Objetos inválidos encontrados após recompilação. Verifique o log: $SQLPLUS_LOG"
  mail -s "Alerta: Objetos inválidos não recompilados após migração" "$EMAIL" < "$SQLPLUS_LOG"
else
  echo "Todos os objetos inválidos recompilados com sucesso."
fi

# Enviar Log de Transferência por Email
echo "Enviando relatório por email..."
EMAIL_BODY="Relatório de Transferência de Dados\n\n"
EMAIL_BODY+="Informações do Banco de Origem:\n"
EMAIL_BODY+="Nome: $ORIGEM_DATABASE\nDump File: $ORIGEM_DUMPFILE\n\n"
EMAIL_BODY+="Informações do Banco de Destino:\n"
EMAIL_BODY+="Nome: $DESTINO_DATABASE\nLog File: $DESTINO_LOGFILE\n\n"
EMAIL_BODY+="Conteúdo do Log de Importação:\n"
EMAIL_BODY+="$(cat "$DESTINO_DIRECTORY/$DESTINO_LOGFILE")\n"

mail -s "Relatório de Transferência de Dados" "$EMAIL" <<< "$EMAIL_BODY"

# Limpeza de Arquivos Temporários
echo "Limpando arquivos temporários..."
rm -f recompilar.sql "$SQLPLUS_LOG"

echo "Processo concluído com sucesso!"
