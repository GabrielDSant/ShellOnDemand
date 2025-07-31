# #################################################################################################
# [VER 1.4]
# Este script exclui arquivos de log arquivados aplicados mais antigos que N horas especificadas
# no banco de dados STANDBY.
# Este script será executado por padrão em TODOS os bancos de dados STANDBY em execução.
# Leia as instruções abaixo para saber como usar este script:
# - Você pode configurar a variável MAIL_LIST com seu e-mail para receber alertas caso os logs
#   arquivados não tenham sido aplicados.
#   Exemplo: MAIL_LIST="seu.email@empresa.com"
# - Você pode especificar os logs candidatos à exclusão mais antigos que N horas configurando
#   a variável LAST_N_HOURS com o número de horas.
#   Exemplo: Excluir logs aplicados mais antigos que 24 horas
#   LAST_N_HOURS=24
# - Você pode EXCLUIR qualquer instância para que o script não seja executado nela, passando o nome
#   da instância para a variável EXL_DB.
#   Exemplo: Excluindo a instância "orcl" da exclusão de logs:
#   EXL_DB="\-MGMTDB|ASM|orcl"
# - Você pode usar a opção FORCE ao excluir os logs no console RMAN: [Y|N]
#   Exemplo: FORCE_DELETION=Y
# - Você pode decidir se deseja VALIDAR os logs arquivados após a exclusão: [Y|N]
#   Exemplo: VALIDATE_ARCHIVES=Y
#
#					#   #     #
# Autor:	Mahmmoud ADEL	      # # # #   ###
# 				    #   #   # #   #  
# Criado:      14-Nov-2016
# Modificado:	11-Jan-2017	Adicionadas mais informações na saída.
#		17-Jan-2017	Adicionada a capacidade de ativar/desativar as opções de 
#				exclusão FORÇADA dos logs e validação após a exclusão.
#		20-Jul-2017	Neutralizado o arquivo login.sql, se encontrado no diretório
#				home do usuário Oracle.
#
# #################################################################################################

# ##################################
# NOVO COMENTÁRIO:
# ##################################
# Este script automatiza a exclusão de logs arquivados aplicados em bancos de dados STANDBY.
# Ele verifica se os logs mais antigos que um período especificado (em horas) foram aplicados
# e, caso tenham sido, os exclui usando o RMAN. O script também permite configurar opções como
# exclusão forçada, validação dos logs após a exclusão e envio de alertas por e-mail caso existam
# logs não aplicados. Ele ignora instâncias específicas configuradas pelo usuário.
# #################################################################################################

# ##################################
# VARIÁVEIS: [Alteradas pelo usuário] .......................................
# ##################################

SCRIPT_NAME="delete_standby_archives.sh"
SRV_NAME=`uname -n`
MAIL_LIST="youremail@yourcompany.com"

# #############################################################################
# Defina o número de HORAS em que os ARQUIVOS mais antigos que N horas serão excluídos: [Padrão 8 HORAS]
# #############################################################################
LAST_N_HOURS=8
export LAST_N_HOURS

# #############################################################################
# Deseja VALIDAR os ARQUIVOS após a exclusão?: [Y|N]		[Padrão SIM]
# #############################################################################
VALIDATE_ARCHIVES=Y

# #############################################################################
# Deseja FORÇAR a exclusão dos ARQUIVOS?: [Y|N]			[Padrão NÃO]
# #############################################################################
FORCE_DELETION=N

# #######################################
# Instâncias Excluídas:
# #######################################
# Aqui você pode mencionar as instâncias que o script irá IGNORAR e NÃO será executado:
# Use o separador pipe "|" entre cada nome de instância.
# Exemplo: Excluindo: -MGMTDB, instâncias ASM:

EXL_DB="\-MGMTDB|ASM"				#Instâncias Excluídas [Não serão reportadas como offline].


# ##############################
# O SCRIPT COMEÇA AQUI ............................................
# ##############################

# #########################
# Configurando ORACLE_SID:
# #########################
for ORACLE_SID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
   do
    export ORACLE_SID

# #########################
# Obtendo ORACLE_HOME
# #########################
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $1}'|tail -1`
  USR_ORA_HOME=`grep ${ORA_USER} /etc/passwd| cut -f6 -d ':'|tail -1`

# CONFIGURANDO ORATAB:
if [ -f /etc/oratab ]
  then
  ORATAB=/etc/oratab
  export ORATAB
## Se o sistema operacional for Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  export ORATAB
fi

# TENTATIVA 1: Obter ORACLE_HOME usando o comando pwdx:
  PMON_PID=`pgrep  -lf _pmon_${ORACLE_SID}|awk '{print $1}'`
  export PMON_PID
  ORACLE_HOME=`pwdx ${PMON_PID}|awk '{print $NF}'|sed -e 's/\/dbs//g'`
  export ORACLE_HOME
#echo "ORACLE_SID é ${ORACLE_SID}"
#echo "ORACLE_HOME do PWDX é ${ORACLE_HOME}"

# TENTATIVA 2: Se ORACLE_HOME não for encontrado, obtê-lo do arquivo oratab:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
## Se o sistema operacional for Linux:
if [ -f /etc/oratab ]
  then
  ORATAB=/etc/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME

## Se o sistema operacional for Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME
fi
#echo "ORACLE_HOME do oratab é ${ORACLE_HOME}"
fi

# TENTATIVA 3: Se ORACLE_HOME ainda não for encontrado, procure pela variável de ambiente: [Menos preciso]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`env|grep -i ORACLE_HOME|sed -e 's/ORACLE_HOME=//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME do ambiente é ${ORACLE_HOME}"
fi

# TENTATIVA 4: Se ORACLE_HOME não for encontrado no ambiente, procure no perfil do usuário: [Menos preciso]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`grep -h 'ORACLE_HOME=\/' $USR_ORA_HOME/.bash_profile $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
  export ORACLE_HOME
#echo "ORACLE_HOME do Perfil do Usuário é ${ORACLE_HOME}"
fi

# TENTATIVA 5: Se ORACLE_HOME ainda não for encontrado, procure por orapipe: [Menos preciso]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`locate -i orapipe|head -1|sed -e 's/\/bin\/orapipe//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME da busca por orapipe é ${ORACLE_HOME}"
fi

# TERMINAR: Se todas as tentativas acima falharem em obter a localização do ORACLE_HOME, SAIR do script:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  echo "Por favor, exporte a variável ORACLE_HOME no seu arquivo .bash_profile no diretório home do usuário Oracle para que este script funcione corretamente"
  echo "Exemplo:"
  echo "export ORACLE_HOME=/u01/app/oracle/product/11.2.0/db_1"
exit
fi

# Neutralizar o arquivo login.sql:
# #########################
# A existência do arquivo login.sql no diretório de trabalho atual elimina muitas funções durante a execução deste script:

        if [ -f ./login.sql ]
         then
mv ./login.sql   ./login.sql_NeutralizedBy${SCRIPT_NAME}
        fi

        if [ -f ${USR_ORA_HOME}/login.sql ]
         then
mv ${USR_ORA_HOME}/login.sql   ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}
        fi

# #########################
# Variáveis:
# #########################
export PATH=$PATH:${ORACLE_HOME}/bin


# #########################
# ARQUIVO DE LOG:
# #########################
export LOG_DIR=`pwd`

        if [ ! -d ${LOG_DIR} ]
         then
          export LOG_DIR=/tmp
        fi
LOG_FILE=${LOG_DIR}/DELETE_ARCHIVES.log


# #########################
# Obtendo DB_NAME:
# #########################
VAL1=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT name from v\$database
exit;
EOF
)
# Obtendo DB_NAME em maiúsculas e minúsculas:
DB_NAME_UPPER=`echo $VAL1| perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
DB_NAME_LOWER=$( echo "$DB_NAME_UPPER" | tr -s  '[:upper:]' '[:lower:]' )
export DB_NAME_UPPER
export DB_NAME_LOWER

# DB_NAME está em maiúsculas ou minúsculas?:

     if [ -d $ORACLE_HOME/diagnostics/${DB_NAME_LOWER} ]
        then
                DB_NAME=$DB_NAME_LOWER
        else
                DB_NAME=$DB_NAME_UPPER
     fi

# ###########################
# VERIFICANDO O PAPEL DO BANCO DE DADOS: [STANDBY]
# ###########################
VAL12=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select COUNT(*) from v\$database where DATABASE_ROLE='PHYSICAL STANDBY';
exit;
EOF
)

DB_ROLE=`echo $VAL12| perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`

# Se o banco de dados for um banco de dados standby, prossiga com o restante do script:

		if [ ${DB_ROLE} -gt 0 ]
		 then
# Excluir logs apenas quando eles forem aplicados:
VAL31=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
--select count(*) from v\$archived_log where completion_time between sysdate-2 and  sysdate-$LAST_N_HOURS/24 and APPLIED = 'NO';
--select count(*) from v\$archived_log where name is not null and completion_time between sysdate and sysdate-$LAST_N_HOURS/24 and FAL='NO' and APPLIED = 'NO';
select count(*) from v\$archived_log where name is not null and completion_time between sysdate-(${LAST_N_HOURS}+1)/24 and  sysdate-({$LAST_N_HOURS})/24 and FAL='NO' and APPLIED = 'NO';
EOF
)
NO_APPL_ARC=`echo ${VAL31}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`
export NO_APPL_ARC

#echo "NOT_APPLIED_ARCHIVES=$NO_APPL_ARC"

if [ ${NO_APPL_ARC} -gt 0 ]
then
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
spool ${LOG_FILE}
PROMPT
PROMPT ------------------------------------------------------------------------------------------------

PROMPT SCRIPT TERMINADO! Existem logs arquivados nas últimas ${LAST_N_HOURS} horas que AINDA NÃO foram APLICADOS.
PROMPT CERTIFIQUE-SE DE QUE TODOS OS LOGS FORAM APLICADOS ANTES DE EXCLUIR OS LOGS ARQUIVADOS.
PROMPT ------------------------------------------------------------------------------------------------

PROMPT OS SEGUINTES LOGS AINDA NÃO FORAM APLICADOS NO BANCO DE DADOS STANDBY:
PROMPT -------------------------------------------------------------

set pages 2000
set linesize 199
col name for a120
select name,to_char(completion_time,'HH24:MI:SS DD-MON-YYYY') completion_time,applied from v\$archived_log
where name is not null and completion_time <= sysdate-${LAST_N_HOURS}/24 and FAL='NO' and APPLIED = 'NO'
order by completion_time asc;

PROMPT
spool off
EOF

mail -s "ALERTA: LOGS NAS ÚLTIMAS [${LAST_N_HOURS}] HORAS NÃO FORAM APLICADOS NO BANCO DE DADOS STANDBY [${DB_NAME}] " ${MAIL_LIST} < ${LOG_FILE}

else

echo ""
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
echo "TODOS os logs nas últimas ${LAST_N_HOURS} horas foram APLICADOS com sucesso."
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
echo ""
VAL35=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
PROMPT
--select count(*) from v\$archived_log where name is not null and completion_time between sysdate-2 and sysdate-${LAST_N_HOURS}/24 and APPLIED = 'YES';
select count(*) from v\$archived_log where name is not null and completion_time <= sysdate-${LAST_N_HOURS}/24 and APPLIED = 'YES';
EOF
)
CAND_DEL_ARC=`echo ${VAL35}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`
export CAND_DEL_ARC
  if [ ${CAND_DEL_ARC} -gt 0 ]
   then
echo "VERIFICANDO LOGS CANDIDATOS PARA EXCLUSÃO ..."
sleep 1
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
PROMPT OS SEGUINTES LOGS CANDIDATOS SERÃO EXCLUÍDOS:
PROMPT -------------------------------------------------

col name for a120
select name from v\$archived_log where name is not null and FAL='NO' and completion_time <= sysdate-${LAST_N_HOURS}/24;
EOF

# VERIFICAR OPÇÃO DE VALIDAÇÃO:

	case ${VALIDATE_ARCHIVES} in
	y|Y|yes|YES|Yes) CROSSCHECK_ARCHIVELOGS="change archivelog all crosscheck;"; export CROSSCHECK_ARCHIVELOGS;;
        *)		 CROSSCHECK_ARCHIVELOGS=""; export CROSSCHECK_ARCHIVELOGS;;
        esac

# VERIFICAR OPÇÃO DE EXCLUSÃO FORÇADA:

        case ${FORCE_DELETION} in
        y|Y|yes|YES|Yes) FORCE_OPTION="force"; export FORCE_OPTION;;
        *)               FORCE_OPTION=""; export FORCE_OPTION;;
        esac

# INICIAR EXCLUSÃO DE LOGS CANDIDATOS NO CONSOLE RMAN:
export NLS_DATE_FORMAT="DD-MON-YY HH24:MI:SS"
${ORACLE_HOME}/bin/rman target / <<EOF
delete noprompt ${FORCE_OPTION} archivelog all completed before 'sysdate-${LAST_N_HOURS}/24';
${CROSSCHECK_ARCHIVELOGS}
EOF
echo ""
echo "TODOS OS LOGS MAIS ANTIGOS QUE ${LAST_N_HOURS} HORAS FORAM EXCLUÍDOS COM SUCESSO."
echo "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv"
echo ""
   else
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
PROMPT
PROMPT STATUS DOS LOGS DISPONÍVEIS NAS ÚLTIMAS ${LAST_N_HOURS} HORAS:
PROMPT -----------------------------------------------

set pages 2000 linesize 199
col name for a120
select name,to_char(completion_time,'DD-MON-YYYY HH24:MI:SS') completion_time,applied from v\$archived_log
where name is not null and completion_time >= sysdate-${LAST_N_HOURS}/24
order by completion_time asc;
EOF
echo ""
echo "NENHUM LOG CANDIDATO ESTÁ ELEGÍVEL PARA EXCLUSÃO NAS ÚLTIMAS ${LAST_N_HOURS} HORAS!"
echo "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv"
echo ""
  fi
fi
		fi
		                if [ ${DB_ROLE} -eq 0 ]
                 		 then
		 		  echo "O banco de dados ${DB_NAME} NÃO é um banco de dados STANDBY"
		 		  echo "Este script foi projetado para ser executado apenas em bancos de dados STANDBY!"
		 		  echo "SCRIPT TERMINADO!"
				fi
done

# Desneutralizar o arquivo login.sql:
# ############################
# Se o arquivo login.sql foi renomeado durante a execução do script, revertê-lo para o nome original:
        if [ -f ./login.sql_NeutralizedBy${SCRIPT_NAME} ]
         then
mv ./login.sql_NeutralizedBy${SCRIPT_NAME}  ./login.sql
        fi

        if [ -f ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME} ]
         then
mv ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}  ${USR_ORA_HOME}/login.sql
        fi

# #############
# FIM DO SCRIPT
# #############
# RELATE BUGS para: mahmmoudadel@hotmail.com
# BAIXE A VERSÃO MAIS RECENTE DO PACOTE DE ADMINISTRAÇÃO DE BANCO DE DADOS EM:
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
# AVISO: ESTE SCRIPT É DISTRIBUÍDO NA ESPERANÇA DE QUE SEJA ÚTIL, MAS SEM QUALQUER GARANTIA. ELE É FORNECIDO "COMO ESTÁ".
