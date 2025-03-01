#!/bin/bash

# Variáveis Gerais
STANDBY_USUARIO="standby_usuario"
STANDBY_SENHA="standby_senha"
STANDBY_DATABASE="standby_database"
STANDBY_DUMPFILE="/tmp/standby_dump.sql"

PRODUCAO_USUARIO="producao_usuario"
PRODUCAO_SENHA="producao_senha"
PRODUCAO_DATABASE="producao_database"
PRODUCAO_DUMPFILE="/tmp/producao_dump.sql"

# Exportação de Dados no Banco de Produção
echo "Iniciando exportação de dados no banco de produção..."
mysqldump -u "$PRODUCAO_USUARIO" -p"$PRODUCAO_SENHA" "$PRODUCAO_DATABASE" > "$PRODUCAO_DUMPFILE"

if [ $? -ne 0 ]; then
  echo "Erro durante a exportação. Verifique o log."
  exit 1
fi

# Transferência de Dump para o Standby
echo "Transferindo dump para o servidor standby..."
cp "$PRODUCAO_DUMPFILE" "$STANDBY_DUMPFILE"

# Importação de Dados no Banco de Standby
echo "Iniciando importação de dados no banco de standby..."
mysql -u "$STANDBY_USUARIO" -p"$STANDBY_SENHA" "$STANDBY_DATABASE" < "$STANDBY_DUMPFILE"

if [ $? -ne 0 ]; then
  echo "Erro durante a importação. Verifique o log."
  exit 1
fi

echo "Configuração do servidor standby concluída com sucesso."