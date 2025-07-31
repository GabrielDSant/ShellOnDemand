###################################################
# Script para exibir informações dos discos ASM e seus grupos.
VER="1.0"
#					#   #     #
# Autor:	Mahmmoud ADEL	      # # # #   ###
# Criado:	27-12-17	    #   #   # #   # 
#
#
#
###################################################

SCRIPT_NAME="asmdisks"

# ###########
# Descrição:
# ###########
echo
echo "============================================================"
echo "Este script exibe informações dos discos ASM e seus grupos ASM."
echo "============================================================"
echo
sleep 1

# #######################################
# Instâncias Excluídas:
# #######################################
# Aqui você pode mencionar as instâncias que o script irá IGNORAR e NÃO será executado contra:
# Use o caractere pipe "|" como separador entre cada nome de instância.
# Exemplo: A linha a seguir exclui: -MGMTDB e instâncias ASM:

EXL_DB="\-MGMTDB|ASM"                           # Instâncias Excluídas [Não serão reportadas como offline].

# ###########################
# Listando Bancos de Dados Disponíveis:
# ###########################

# Contar o número de instâncias:
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|wc -l )

# Sair se nenhum banco de dados estiver em execução:
if [ ${INS_COUNT} -eq 0 ]
 then
   echo Nenhum Banco de Dados em Execução!
   exit
fi

# Se houver apenas um banco de dados, defini-lo como padrão sem solicitar seleção:
if [ ${INS_COUNT} -eq 1 ]
 then
   export ORACLE_SID=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )

# Se houver mais de um banco de dados, solicitar ao usuário que selecione:
elif [ ${INS_COUNT} -gt 1 ]
 then
    echo
    echo "Selecione o ORACLE_SID:[Digite o número]"
    echo ---------------------
    select DB_ID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
     do
        if [ -z "${REPLY##[0-9]*}" ]
         then
          export ORACLE_SID=${DB_ID}
          echo Instância Selecionada:
          echo
          echo "********"
          echo ${DB_ID}
          echo "********"
          echo
          break
         else
          export ORACLE_SID=${REPLY}
          break
        fi
     done

fi
# Sair se o usuário selecionou um número não listado:
        if [ -z "${ORACLE_SID}" ]
         then
          echo "Você inseriu um ORACLE_SID INVÁLIDO"
          exit
        fi

# ########################################
# Obtendo o ORACLE_HOME
# ########################################
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
  echo "Por favor, exporte a variável ORACLE_HOME no seu arquivo .bash_profile no diretório home do usuário oracle para que este script funcione corretamente"
  echo "Exemplo:"
  echo "export ORACLE_HOME=/u01/app/oracle/product/11.2.0/db_1"
exit
fi

# ########################################
# Sair se o usuário atual não for o proprietário do Oracle:
# ########################################
CURR_USER=`whoami`
        if [ ${ORA_USER} != ${CURR_USER} ]; then
          echo ""
          echo "Você está executando este script com o usuário: \"${CURR_USER}\" !!!"
          echo "Por favor, execute este script com o usuário correto do sistema operacional: \"${ORA_USER}\""
          echo "Script Encerrado!"
          exit
        fi


# #####################
# Script SQLPLUS:
# #####################
${ORACLE_HOME}/bin/sqlplus -S '/ as sysdba' <<EOF
set linesize 167 pages 100
col name for a35
PROMPT -----------------

prompt GRUPOS DE DISCO ASM:
PROMPT -----------------

select name,total_mb,free_mb,ROUND((1-(free_mb / total_mb))*100, 2) "%FULL" from v\$asm_diskgroup;

PROMPT -----------------

prompt DISCOS ASM:
PROMPT -----------------


col DISK_PATH 		for a40
col diskgroup_name 	for a15
col FAILGROUP 		for a20
col DISK_FILE_NAME 	for a20
col TOTAL_GB 		for 9999999.99
col FREE_GB 		for 9999999.99
SELECT NVL(a.name, '[CANDIDATE]')diskgroup_name, b.path disk_path, b.name disk_name,
b.failgroup, b.total_MB/1024 TOTAL_GB, b.free_MB/1024 FREE_GB, b.state, b.MODE_STATUS
FROM v\$asm_diskgroup a RIGHT OUTER JOIN v\$asm_disk b USING (group_number)
ORDER BY a.name, b.path;
EOF

# #####################
# Script do Sistema Operacional:
# #####################

FILE_NAME=/sbin/blkid
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""
echo "----------------------------"
echo "MONTAGENS E RÓTULOS DOS DISCOS ASM NO SISTEMA OPERACIONAL: ${FILE_NAME} |sort -k 2 -t:|grep oracleasm"
echo "----------------------------"
/sbin/blkid |sort -k 2 -t:|grep oracleasm
echo ""
fi

# #############
# FIM DO SCRIPT
# #############
# RELATE BUGS para: <mahmmoudadel@hotmail.com>.
# AVISO: ESTE SCRIPT É DISTRIBUÍDO NA ESPERANÇA DE SER ÚTIL, MAS SEM QUALQUER GARANTIA. ELE É FORNECIDO "COMO ESTÁ".
# BAIXE A VERSÃO MAIS RECENTE DO PACOTE DE ADMINISTRAÇÃO DE BANCO DE DADOS EM: http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
