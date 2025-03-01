#!/bin/bash

# Defina as variáveis de conexão com o banco de dados
USUARIO="seu_usuario"
SENHA="sua_senha"
BANCO="seu_database"

# Matar sessões inativas
mysql -u "$USUARIO" -p"$SENHA" -e "
SELECT CONCAT('KILL ', id, ';') 
FROM information_schema.processlist 
WHERE command = 'Sleep' AND time > 86400;
" | mysql -u "$USUARIO" -p"$SENHA"