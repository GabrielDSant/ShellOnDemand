#!/bin/bash

# Variáveis Gerais
ORIGEM_USUARIO="seu_usuario"
ORIGEM_SENHA="sua_senha"
ORIGEM_DATABASE="seu_database"
ORIGEM_DUMPFILE="/caminho/diretorio_origem/seu_dumpfile.sql"

DESTINO_USUARIO="seu_usuario"
DESTINO_SENHA="sua_senha"
DESTINO_DATABASE="seu_database"
DESTINO_DUMPFILE="/caminho/diretorio_destino/seu_dumpfile.sql"

EMAIL="seu_email@example.com"

# Exportação de Dados no Host de Origem
echo "Iniciando exportação de dados no host de origem..."
mysqldump -u "$ORIGEM_USUARIO" -p"$ORIGEM_SENHA" "$ORIGEM_DATABASE" > "$ORIGEM_DUMPFILE"

if [ $? -ne 0 ]; then
  echo "Erro durante a exportação. Verifique o log."
  exit 1
fi

# Transferência de Dump para o Destino
echo "Transferindo dump para o host destino..."
cp "$ORIGEM_DUMPFILE" "$DESTINO_DUMPFILE"

# Importação de Dados no Host de Destino
echo "Iniciando importação de dados no host de destino..."
mysql -u "$DESTINO_USUARIO" -p"$DESTINO_SENHA" "$DESTINO_DATABASE" < "$DESTINO_DUMPFILE"

if [ $? -ne 0 ]; then
  echo "Erro durante a importação. Verifique o log."
  exit 1
fi

# Enviar Log de Transferência por Email
echo "Enviando relatório por email..."
EMAIL_BODY="Relatório de Transferência de Dados\n\n"
EMAIL_BODY+="Informações do Banco de Origem:\n"
EMAIL_BODY+="Nome: $ORIGEM_DATABASE\nDump File: $ORIGEM_DUMPFILE\n\n"
EMAIL_BODY+="Informações do Banco de Destino:\n"
EMAIL_BODY+="Nome: $DESTINO_DATABASE\nDump File: $DESTINO_DUMPFILE\n\n"

echo -e "$EMAIL_BODY" | mail -s "Relatório de Transferência de Dados" "$EMAIL"

echo "Processo concluído com sucesso!"