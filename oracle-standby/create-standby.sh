#!/bin/bash

# Variáveis Gerais
STANDBY_USUARIO="standby_usuario"
STANDBY_SENHA="standby_senha"
STANDBY_DATABASE="standby_database"
STANDBY_LOGFILE="/tmp/standby_setup.log"

PRODUCAO_USUARIO="producao_usuario"
PRODUCAO_SENHA="producao_senha"
PRODUCAO_DATABASE="producao_database"
PRODUCAO_LOGFILE="/tmp/producao_backup.log"

# Configuração Inicial no Servidor Standby
echo "Configurando o ambiente do servidor standby..."
mkdir -p /u01/app/oracle/standby
chown -R oracle:oinstall /u01/app/oracle/standby

# Sincronização do Banco de Produção via RMAN
echo "Iniciando sincronização com o banco de produção..." >> "$STANDBY_LOGFILE"
rman target / <<EOF >> "$STANDBY_LOGFILE"
RUN {
  ALLOCATE CHANNEL c1 DEVICE TYPE DISK;
  RESTORE STANDBY CONTROLFILE FROM SERVICE '$PRODUCAO_DATABASE';
  ALTER DATABASE MOUNT STANDBY DATABASE;
  RESTORE DATABASE FROM SERVICE '$PRODUCAO_DATABASE';
  RECOVER DATABASE NOREDO;
}
EXIT;
EOF

# Verificar Sucesso da Sincronização
if grep -q "ORA-" "$STANDBY_LOGFILE"; then
  echo "Erro durante a sincronização do standby. Verifique o log: $STANDBY_LOGFILE"
  exit 1
fi

echo "Sincronização concluída com sucesso." >> "$STANDBY_LOGFILE"

# Ativar o Modo Standby no Banco de Dados
echo "Ativando o modo standby..." >> "$STANDBY_LOGFILE"
sqlplus -s "$STANDBY_USUARIO/$STANDBY_SENHA@$STANDBY_DATABASE" <<EOF >> "$STANDBY_LOGFILE"
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
EXIT;
EOF

if grep -q "ORA-" "$STANDBY_LOGFILE"; then
  echo "Erro ao ativar o modo standby. Verifique o log: $STANDBY_LOGFILE"
  exit 1
fi

echo "Modo standby ativado com sucesso." >> "$STANDBY_LOGFILE"

# Verificar Status do Data Guard
echo "Verificando status do Data Guard..." >> "$STANDBY_LOGFILE"
sqlplus -s "$STANDBY_USUARIO/$STANDBY_SENHA@$STANDBY_DATABASE" <<EOF >> "$STANDBY_LOGFILE"
SELECT THREAD#, SEQUENCE# FROM V\$ARCHIVED_LOG WHERE APPLIED = 'YES';
EXIT;
EOF

if grep -q "ORA-" "$STANDBY_LOGFILE"; then
  echo "Erro ao verificar o status do Data Guard. Verifique o log: $STANDBY_LOGFILE"
  exit 1
fi

# Finalização
echo "Configuração do servidor standby concluída com sucesso."
echo "Verifique o log para detalhes: $STANDBY_LOGFILE"
