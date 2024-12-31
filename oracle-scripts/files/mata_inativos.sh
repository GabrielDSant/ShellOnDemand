#!/bin/bash

# Defina as variáveis de conexão com o banco de dados
USUARIO="<USUARIO>"
SENHA="<SENHA>"
BANCO="<BANCO>"

# Script PL/SQL para matar sessões inativas
sqlplus -s "$USUARIO/$SENHA@$BANCO" <<EOF
SET SERVEROUTPUT ON;

DECLARE
    CURSOR c_sessoes IS
        SELECT s.sid, s.serial#
        FROM v\$session s
        WHERE s.status = 'ACTIVE'
          AND s.last_call_et > 86400;  -- 86400 segundos = 1 dia

BEGIN
    FOR r_sessao IN c_sessoes LOOP
        BEGIN
            -- Matar a sessão
            EXECUTE IMMEDIATE 'ALTER SYSTEM KILL SESSION ''' || r_sessao.sid || ',' || r_sessao.serial# || '''';
            DBMS_OUTPUT.PUT_LINE('Sessão ' || r_sessao.sid || ' com serial ' || r_sessao.serial# || ' foi encerrada.');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Erro ao encerrar a sessão ' || r_sessao.sid || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/
EXIT;
EOF
