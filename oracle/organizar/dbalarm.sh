# #################################################################################################
# Este script realiza monitoramento de bancos de dados Oracle e do sistema operacional. 
# Ele verifica logs de alertas de banco de dados e listeners, monitora o uso de CPU, 
# espaço em disco, tablespaces, área de recuperação flash (FRA) e grupos de discos ASM. 
# Também identifica sessões bloqueadas, operações longas e bancos de dados offline. 
# Alertas são enviados por e-mail quando os limites definidos são excedidos.
# #################################################################################################

# #################################################################################################
# Verificando logs de alertas de banco de dados e listeners para erros.
# Relatando bancos de dados offline.
# Verificando CPU, sistema de arquivos e tablespaces quando excedem os limites definidos.
# Relatando operações longas/sessões ativas no banco de dados quando a CPU ultrapassa o limite definido.
# Verificando sessões bloqueadas no banco de dados.
VER="[5.0]"
# #################################################################################################
#                                       #   #     #
# Autor:        Mahmmoud ADEL         # # # #   ###
# Criado:       22-12-13            #   #   # #   #  
#
# Modificado:    23-12-13 Tratamento para logs inexistentes na primeira execução.
#                14-05-14 Tratamento para inexistência do diretório LOG_DIR.
#                18-05-14 Adicionado monitoramento de sistema de arquivos.
#                19-05-14 Adicionado monitoramento de CPU.
#                03-12-14 Adicionado monitoramento de tablespaces.
#                08-09-15 Alteração na saída do mpstat no Linux 6.
#                02-04-16 Usando dba_tablespace_usage_metrics para calcular MAXSIZE (11g em diante).
#                         Recomendado por Satyajit Mohapatra.
#                10-04-16 Adicionado monitoramento da área de recuperação flash (FRA).
#                10-04-16 Adicionado monitoramento de grupos de discos ASM.
#                15-09-16 Adicionado recurso "DIG MORE" para relatar operações longas, consultas
#                         e sessões ativas no banco de dados quando a CPU atinge o limite definido.
#                29-12-16 Melhorado o critério de busca do ORACLE_HOME.
#                02-01-17 Adicionado parâmetro EXL_DB para permitir que o usuário exclua bancos de dados
#                         do monitoramento do script dbalarm.
#                04-05-17 Adicionada a capacidade de desativar alertas de banco de dados offline
#                         através da variável CHKOFFLINEDB.
#                11-05-17 Adicionada a opção de excluir tablespaces/grupos de discos ASM do monitoramento.
#                11-05-17 Ajustado o método de relatar bancos de dados offline e verificar logs de listeners.
#                20-07-17 Modificada a variável de ambiente COLUMNS para exibir totalmente a saída do comando top.
#                         Neutralizar login.sql se encontrado no diretório home do usuário Oracle devido a bugs.
#                19-10-17 Adicionada a função de verificar o log do Goldengate.
#                11-04-18 Adicionado o recurso de monitorar a disponibilidade de serviços específicos.
#                28-04-18 Adicionada a função de imprimir o progresso do script.
#                30-04-18 Adicionado modo paranoico para relatar EXPORT/IMPORT, ALTER SYSTEM, ALTER DATABASE,
#                         inicialização/desligamento da instância e outras atividades importantes do banco de dados.
# #################################################################################################
SCRIPT_NAME="dbalarm${VER}"
SRV_NAME=`uname -n`
MAIL_LIST="youremail@yourcompany.com"

        case ${MAIL_LIST} in "youremail@yourcompany.com")
         echo
         echo "******************************************************************"
         echo "Buddy! You forgot to edit line# 47 in dbalarm.sh script."
         echo "Please replace youremail@yourcompany.com with your E-mail address."
         echo "******************************************************************"
         echo
         echo "Script Terminated !"
         echo 
         exit;;
        esac

FILE_NAME=/etc/redhat-release
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
LNXVER=`cat /etc/redhat-release | grep -o '[0-9]'|head -1`
export LNXVER
fi

# #########################
# LIMITES:
# #########################
# Modifique os limites para os valores que preferir:

FSTHRESHOLD=95          # LIMITE PARA %USADO DO SISTEMA DE ARQUIVOS [OS]
CPUTHRESHOLD=95         # LIMITE PARA %UTILIZAÇÃO DA CPU [OS]
TBSTHRESHOLD=95         # LIMITE PARA %USADO DO TABLESPACE [DB]
FRATHRESHOLD=95         # LIMITE PARA %USADO DA FRA [DB]
ASMTHRESHOLD=95         # LIMITE PARA %USADO DOS GRUPOS DE DISCO ASM [DB]
BLOCKTHRESHOLD=1        # LIMITE PARA SESSÕES BLOQUEADAS [DB]
CHKLISTENER=Y           # Habilitar/Desabilitar Verificação de Listeners: [Padrão Habilitado]	[DB]
CHKOFFLINEDB=Y          # Habilitar/Desabilitar Alerta de Banco de Dados Offline: [Padrão Habilitado]	[DB]
CHKGOLDENGATE=N         # Habilitar/Desabilitar Alerta do Goldengate: [Padrão Desabilitado]	[GG]
CPUDIGMORE=Y            # Detalhar Sessões Ativas do DB quando a CPU atingir o limite: [RECOMENDADO DEFINIR =N em ambientes MUITO OCUPADOS]	[DB]
SERVICEMON=""           # Monitorar Serviços Nomeados Específicos. Ex.: SERVICEMON="'ORCL_RO','ERP_SRVC','SAP_SERVICE'"					[DB]
PARANOIDMODE=N          # Modo paranoico relatará mais eventos como export/import, inicialização/desligamento da instância. [Padrão Desabilitado]		[DB]

# #######################################
# Instâncias Excluídas:
# #######################################
# Aqui você pode mencionar as instâncias que o dbalarm irá IGNORAR e NÃO será executado:
# Use o separador "|" entre cada nome de instância.
# Ex.: Excluindo: -MGMTDB, instâncias ASM:

EXL_DB="\-MGMTDB|ASM"                   #Instâncias Excluídas [Não serão relatadas como offline].

# #########################
# Tablespaces Excluídos:
# #########################
# Aqui você pode excluir um ou mais tablespaces se não quiser ser alertado quando atingirem o limite:
# Ex.: para excluir "UNDOTBS1" modifique a variável a seguir sem remover o valor "donotremove":
# EXL_TBS="donotremove|UNDOTBS1"
EXL_TBS="donotremove"

# #########################
# Grupos de Discos ASM Excluídos:
# #########################
# Aqui você pode excluir um ou mais Grupos de Discos ASM se não quiser ser alertado quando atingirem o limite:
# Ex.: para excluir o DISKGROUP "FRA" modifique a variável a seguir sem remover o valor "donotremove":
# EXL_DISK_GROUP="donotremove|FRA"
EXL_DISK_GROUP="donotremove"

# #########################
# Erros Excluídos:
# #########################
# Aqui você pode excluir os erros que não deseja ser alertado quando aparecerem nos logs:
# Use o separador "|" entre cada erro.

EXL_ALERT_ERR="ORA-2396|TNS-00507|TNS-12502|TNS-12560|TNS-12537|TNS-00505"              #Erros de ALERTLOG Excluídos [Não serão relatados].
EXL_LSNR_ERR="TNS-00507|TNS-12502|TNS-12560|TNS-12537|TNS-00505"                        #Erros de LISTENER Excluídos [Não serão relatados].
EXL_GG_ERR="donotremove"                                                                #Erros do GoldenGate Excluídos [Não serão relatados].

# ################################
# Sistemas de Arquivos/Pontos de Montagem Excluídos:
# ################################
# Aqui você pode excluir sistemas de arquivos/pontos de montagem específicos de serem relatados pelo dbalarm:
# Ex.: Excluindo: /dev/mapper, /dev/asm pontos de montagem:

EXL_FS="\/dev\/mapper\/|\/dev\/asm\/"                                                   #Pontos de montagem Excluídos [Serão ignorados durante a verificação].

# Solução para o bug de saída do comando df "`/root/.gvfs': Permission denied"
if [ -f /etc/redhat-release ]
 then
  export DF='df -hPx fuse.gvfs-fuse-daemon'
 else
  export DF='df -h'
fi

# #########################
# Verificando o Sistema de Arquivos:
# #########################

echo "Verificando Utilização do Sistema de Arquivos ..."

# Relatar Partições que atingem o limite de Espaço Usado:

FSLOG=/tmp/filesystem_DBA_BUNDLE.log
echo "[Relatado pelo script ${SCRIPT_NAME}]"       > ${FSLOG}
echo ""                                         >> ${FSLOG}
${DF}                                           >> ${FSLOG}
${DF} | grep -v "^Filesystem" |awk '{print substr($0, index($0, $2))}'| egrep -v "${EXL_FS}"|awk '{print $(NF-1)" "$NF}'| while read OUTPUT
   do
        PRCUSED=`echo ${OUTPUT}|awk '{print $1}'|cut -d'%' -f1`
        FILESYS=`echo ${OUTPUT}|awk '{print $2}'`
                if [ ${PRCUSED} -ge ${FSTHRESHOLD} ]
                 then
mail -s "ALERTA: Sistema de Arquivos [${FILESYS}] no Servidor [${SRV_NAME}] atingiu ${PRCUSED}% de espaço usado" $MAIL_LIST < ${FSLOG}
                fi
   done

rm -f ${FSLOG}


# #############################
# Verificando a Utilização da CPU:
# #############################

echo "Verificando Utilização da CPU ..."

# Relatar Utilização da CPU se atingir >= CPUTHRESHOLD:
OS_TYPE=`uname -s`
CPUUTLLOG=/tmp/CPULOG_DBA_BUNDLE.log

# Obtendo a utilização da CPU nos últimos 5 segundos:
case `uname` in
        Linux ) CPU_REPORT_SECTIONS=`iostat -c 1 5 | sed -e 's/,/./g' | tr -s ' ' ';' | sed '/^$/d' | tail -1 | grep ';' -o | wc -l`
                CPU_COUNT=`cat /proc/cpuinfo|grep processor|wc -l`
                        if [ ${CPU_REPORT_SECTIONS} -ge 6 ]; then
                           CPU_IDLE=`iostat -c 1 5 | sed -e 's/,/./g' | tr -s ' ' ';' | sed '/^$/d' | tail -1| cut -d ";" -f 7`
                        else
                           CPU_IDLE=`iostat -c 1 5 | sed -e 's/,/./g' | tr -s ' ' ';' | sed '/^$/d' | tail -1| cut -d ";" -f 6`
                        fi
        ;;
        AIX )   CPU_IDLE=`iostat -t $INTERVAL_SEC $NUM_REPORT | sed -e 's/,/./g'|tr -s ' ' ';' | tail -1 | cut -d ";" -f 6`
                CPU_COUNT=`lsdev -C|grep Process|wc -l`
        ;;
        SunOS ) CPU_IDLE=`iostat -c $INTERVAL_SEC $NUM_REPORT | tail -1 | awk '{ print $4 }'`
                CPU_COUNT=`psrinfo -v|grep "Status of processor"|wc -l`
        ;;
        HP-UX)  SAR="/usr/bin/sar"
                CPU_COUNT=`lsdev -C|grep Process|wc -l`
                if [ ! -x $SAR ]; then
                 echo "sar command is not supported on your environment | CPU Check ignored"; CPU_IDLE=99
                else
                 CPU_IDLE=`/usr/bin/sar 1 5 | grep Average | awk '{ print $5 }'`
                fi
        ;;
        *) echo "uname command is not supported on your environment | CPU Check ignored"; CPU_IDLE=99
        ;;
        esac

# Obtendo Utilização da CPU (100-%IDLE):
CPU_UTL_FLOAT=`echo "scale=2; 100-($CPU_IDLE)"|bc`

# Converter a média de número flutuante para inteiro:
CPU_UTL=${CPU_UTL_FLOAT%.*}

        if [ -z ${CPU_UTL} ]
         then
          CPU_UTL=1
        fi

# Comparar a utilização atual da CPU com o Limite:
CPULOG=/tmp/top_processes_DBA_BUNDLE.log

        if [ ${CPU_UTL} -ge ${CPUTHRESHOLD} ]
         then
                export COLUMNS=300           #Aumentar a largura das COLUNAS para exibir a saída completa [Padrão é 167]
                echo "ESTATÍSTICAS DA CPU:"         >  ${CPULOG}
                echo "========="          >> ${CPULOG}
                mpstat 1 5                >> ${CPULOG}
                echo ""                   >> ${CPULOG}
                echo "Saída do VMSTAT:"     >> ${CPULOG}
                echo "============="      >> ${CPULOG}
                echo "[Se o número da fila de execução na coluna (r) exceder o número de CPUs [${CPU_COUNT}] isso indica um gargalo de CPU no sistema]." >> ${CPULOG}
                echo ""                   >> ${CPULOG}
                vmstat 2 5                >> ${CPULOG}
                echo ""                   >> ${CPULOG}
                echo "Top 10 Processos:"  >> ${CPULOG}
                echo "================"   >> ${CPULOG}
                echo ""                   >> ${CPULOG}
                top -c -b -n 1|head -17   >> ${CPULOG}
                unset COLUMNS                #Definir a largura das COLUNAS de volta ao valor padrão
                #ps -eo pcpu,pid,user,args | sort -k 1 -r | head -11 >> ${CPULOG}
# Verificar SESSÕES ATIVAS no lado do DB:
for ORACLE_SID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
   do
    export ORACLE_SID

# Obtendo ORACLE_HOME:
# ###################
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|egrep -v ${EXL_DB}|awk '{print $1}'|tail -1`
  USR_ORA_HOME=`grep ${ORA_USER} /etc/passwd| cut -f6 -d ':'|tail -1`

# CONFIGURANDO ORATAB:
if [ -f /etc/oratab ]
  then
  ORATAB=/etc/oratab
  export ORATAB
## Se o SO for Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  export ORATAB
fi

# TENTATIVA1: Obter ORACLE_HOME usando o comando pwdx:
  PMON_PID=`pgrep  -lf _pmon_${ORACLE_SID}|awk '{print $1}'`
  export PMON_PID
  ORACLE_HOME=`pwdx ${PMON_PID}|awk '{print $NF}'|sed -e 's/\/dbs//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME do PWDX é ${ORACLE_HOME}"

# TENTATIVA2: Se ORACLE_HOME não for encontrado, obtê-lo do arquivo oratab:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
## Se o SO for Linux:
if [ -f /etc/oratab ]
  then
  ORATAB=/etc/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME

## Se o SO for Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME
fi
#echo "ORACLE_HOME do oratab é ${ORACLE_HOME}"
fi

# TENTATIVA3: Se ORACLE_HOME ainda não for encontrado, procure pela variável de ambiente: [Menos preciso]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`env|grep -i ORACLE_HOME|sed -e 's/ORACLE_HOME=//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME do ambiente é ${ORACLE_HOME}"
fi

# TENTATIVA4: Se ORACLE_HOME não for encontrado no ambiente, procure no perfil do usuário: [Menos preciso]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`grep -h 'ORACLE_HOME=\/' $USR_ORA_HOME/.bash_profile $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
  export ORACLE_HOME
#echo "ORACLE_HOME do Perfil do Usuário é ${ORACLE_HOME}"
fi

# TENTATIVA5: Se ORACLE_HOME ainda não for encontrado, procure por orapipe: [Menos preciso]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`locate -i orapipe|head -1|sed -e 's/\/bin\/orapipe//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME da busca por orapipe é ${ORACLE_HOME}"
fi


# Verificar Transações Longas se CPUDIGMORE=Y:
                 case ${CPUDIGMORE} in
                 y|Y|yes|YES|Yes)
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 200
SPOOL ${CPULOG} APPEND
prompt
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Prompt SESSÕES ATIVAS NO BANCO DE DADOS [${ORACLE_SID}]:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

set feedback off linesize 200 pages 1000
col "OS_PID"                            for a8
col module                              for a30
col event                               for a24
col "STATUS|WAIT_STATE|TIME_WAITED"     for a31
col "INS|USER|SID,SER|MACHIN|MODUL"     for a65
col "ST|WA_ST|WAITD|ACT_SINC|LOG_T"     for a44
col "SQLID | FULL_SQL_TEXT"             for a75
col "CURR_SQLID"                        for a35
col "I|BLKD_BY"                         for a9
select
substr(s.INST_ID||'|'||s.USERNAME||'| '||s.sid||','||s.serial#||' |'||substr(s.MACHINE,1,22)||'|'||substr(s.MODULE,1,18),1,65)"INS|USER|SID,SER|MACHIN|MODUL"
,substr(s.status||'|'||w.state||'|'||round(w.WAIT_TIME_MICRO/1000000)||'|'||LAST_CALL_ET||'|'||to_char(LOGON_TIME,'ddMon'),1,44) "ST|WA_ST|WAITD|ACT_SINC|LOG_T"
,substr(w.event,1,24) "EVENT"
--substr(w.event,1,30)"EVENT",s.SQL_ID ||' | '|| Q.SQL_FULLTEXT "SQLID | FULL_SQL_TEXT"
,s.SQL_ID "CURRENT SQLID"
,s.FINAL_BLOCKING_INSTANCE||'|'||s.FINAL_BLOCKING_SESSION "I|BLKD_BY"
from    gv\$session s, gv\$session_wait w
where   s.USERNAME is not null
and     s.sid=w.sid
and     s.STATUS='ACTIVE'
and     w.EVENT NOT IN ('SQL*Net message from client','class slave wait','Streams AQ: waiting for messages in the queue','Streams capture: waiting for archive log'
        ,'Streams AQ: waiting for time management or cleanup tasks','PL/SQL lock timer','rdbms ipc message')
order by "I|BLKD_BY" desc,w.event,"INS|USER|SID,SER|MACHIN|MODUL","ST|WA_ST|WAITD|ACT_SINC|LOG_T" desc,"CURRENT SQLID";

PROMPT
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

PROMPT STATUS DAS SESSÕES: [Instância Local]
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

set pages 0
select 'TODAS:        '||count(*)         from v\$session;
select 'BACKGROUND: '||count(*)         from v\$session where USERNAME is null;
select 'INATIVAS:   '||count(*)         from v\$session where USERNAME is not null and status='INACTIVE';
select 'ATIVAS:     '||count(*)         from v\$session where USERNAME is not null and status='ACTIVE';

prompt
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Prompt Operações Longas no Banco de Dados [${ORACLE_SID}]:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

set linesize 200 pages 1000
col OPERATION                           for a21
col "%DONE"                             for 99.999
col "STARTED|MIN_ELAPSED|REMAIN"        for a30
col MESSAGE                             for a80
col "USERNAME| SID,SERIAL#"             for a26
        select USERNAME||'| '||SID||','||SERIAL# "USERNAME| SID,SERIAL#",SQL_ID
        --,OPNAME OPERATION
        ,substr(SOFAR/TOTALWORK*100,1,5) "%DONE"
        ,to_char(START_TIME,'DD-Mon HH24:MI')||'| '||trunc(ELAPSED_SECONDS/60)||'|'||trunc(TIME_REMAINING/60) "STARTED|MIN_ELAPSED|REMAIN" ,MESSAGE
        from v\$session_longops where SOFAR/TOTALWORK*100 <>'100'
        order by "STARTED|MIN_ELAPSED|REMAIN" desc, "USERNAME| SID,SERIAL#";

PROMPT
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

PROMPT Consultas Executando Há Mais de 1 Hora no Banco de Dados [${ORACLE_SID}]:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

set lines 200
col module                      for a30
col DURATION_HOURS              for 99999.9
col STARTED_AT                  for a13
col "USERNAME| SID,SERIAL#"     for a30
col "SQL_ID | SQL_TEXT"         for a120
select username||'| '||sid ||','|| serial# "USERNAME| SID,SERIAL#",substr(MODULE,1,30) "MODULE", to_char(sysdate-last_call_et/24/60/60,'DD-MON HH24:MI') STARTED_AT,
last_call_et/60/60 "DURATION_HOURS"
--,SQL_ID ||' | '|| (select SQL_FULLTEXT from v\$sql where address=sql_address) "SQL_ID | SQL_TEXT"
,SQL_ID
from v\$session where
username is not null 
and module is not null
-- 1 é o número de horas
and last_call_et > 60*60*1
and status = 'ACTIVE';

PROMPT
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

PROMPT JOBS EM EXECUÇÃO no Banco de Dados [${ORACLE_SID}]:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

col INS                         for 999
col "JOB_NAME|OWNER|SPID|SID"   for a55
col ELAPSED_TIME                for a17
col CPU_USED                    for a17
col "WAIT_SEC"                  for 9999999999
col WAIT_CLASS                  for a15
col "BLKD_BY"                   for 9999999
col "WAITED|WCLASS|EVENT"       for a45
select j.RUNNING_INSTANCE INS,j.JOB_NAME ||' | '|| j.OWNER||' |'||SLAVE_OS_PROCESS_ID||'|'||j.SESSION_ID"JOB_NAME|OWNER|SPID|SID"
,s.FINAL_BLOCKING_SESSION "BLKD_BY",ELAPSED_TIME,CPU_USED
,substr(s.SECONDS_IN_WAIT||'|'||s.WAIT_CLASS||'|'||s.EVENT,1,45) "WAITED|WCLASS|EVENT",S.SQL_ID
from dba_scheduler_running_jobs j, gv\$session s
where   j.RUNNING_INSTANCE=S.INST_ID(+)
and     j.SESSION_ID=S.SID(+)
order by INS,"JOB_NAME|OWNER|SPID|SID",ELAPSED_TIME;

SPOOL OFF
EOF

                ;;
                esac
  done
mail -s "ALERTA: Utilização da CPU no Servidor [${SRV_NAME}] atingiu [${CPU_UTL}%]" $MAIL_LIST < ${CPULOG}
        fi

rm -f ${CPUUTLLOG}
rm -f ${CPULOG}

echo "VERIFICAÇÃO DA CPU Concluída"

# #########################
# Obtendo ORACLE_SID:
# #########################
# Sair enviando e-mail de alerta se nenhum DB estiver em execução:
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|wc -l )
        if [ $INS_COUNT -eq 0 ]
         then
         echo "[Relatado pelo script ${SCRIPT_NAME}]"                                              > /tmp/oracle_processes_DBA_BUNDLE.log
         echo " "                                                                               >> /tmp/oracle_processes_DBA_BUNDLE.log
         echo "Instâncias em execução no momento no servidor [${SRV_NAME}]:"                              >> /tmp/oracle_processes_DBA_BUNDLE.log
         echo "***************************************************"                             >> /tmp/oracle_processes_DBA_BUNDLE.log
         ps -ef|grep -v grep|grep pmon                                                          >> /tmp/oracle_processes_DBA_BUNDLE.log
         echo " "                                                                               >> /tmp/oracle_processes_DBA_BUNDLE.log
         echo "Listeners em execução no momento no servidor [${SRV_NAME}]:"                              >> /tmp/oracle_processes_DBA_BUNDLE.log
         echo "***************************************************"                             >> /tmp/oracle_processes_DBA_BUNDLE.log
         ps -ef|grep -v grep|grep tnslsnr                                                       >> /tmp/oracle_processes_DBA_BUNDLE.log
mail -s "ALERTA: Nenhum Banco de Dados Está em Execução no Servidor: $SRV_NAME !!!" $MAIL_LIST                    < /tmp/oracle_processes_DBA_BUNDLE.log
         rm -f /tmp/oracle_processes_DBA_BUNDLE.log
         exit
        fi

# #########################
# Configurando ORACLE_SID:
# #########################
echo "CONFIGURANDO ORACLE_SID"
for ORACLE_SID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
   do
    export ORACLE_SID

# #########################
# Obtendo ORACLE_HOME
# #########################
echo "Obtendo ORACLE HOME"
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $1}'|tail -1`
  USR_ORA_HOME=`grep ${ORA_USER} /etc/passwd| cut -f6 -d ':'|tail -1`

# CONFIGURANDO ORATAB:
if [ -f /etc/oratab ]
  then
  ORATAB=/etc/oratab
  export ORATAB
## Se o SO for Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  export ORATAB
fi

# TENTATIVA1: Obter ORACLE_HOME usando o comando pwdx:
  PMON_PID=`pgrep  -lf _pmon_${ORACLE_SID}|awk '{print $1}'`
  export PMON_PID
  ORACLE_HOME=`pwdx ${PMON_PID}|awk '{print $NF}'|sed -e 's/\/dbs//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME do PWDX é ${ORACLE_HOME}"

# TENTATIVA2: Se ORACLE_HOME não for encontrado, obtê-lo do arquivo oratab:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
## Se o SO for Linux:
if [ -f /etc/oratab ]
  then
  ORATAB=/etc/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME

## Se o SO for Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME
fi
#echo "ORACLE_HOME do oratab é ${ORACLE_HOME}"
fi

# TENTATIVA3: Se ORACLE_HOME ainda não for encontrado, procure pela variável de ambiente: [Menos preciso]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`env|grep -i ORACLE_HOME|sed -e 's/ORACLE_HOME=//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME do ambiente é ${ORACLE_HOME}"
fi

# TENTATIVA4: Se ORACLE_HOME não for encontrado no ambiente, procure no perfil do usuário: [Menos preciso]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`grep -h 'ORACLE_HOME=\/' $USR_ORA_HOME/.bash_profile $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
  export ORACLE_HOME
#echo "ORACLE_HOME do Perfil do Usuário é ${ORACLE_HOME}"
fi

# TENTATIVA5: Se ORACLE_HOME ainda não for encontrado, procure por orapipe: [Menos preciso]
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
  echo "Ex.:"
  echo "export ORACLE_HOME=/u01/app/oracle/product/11.2.0/db_1"
mail -s "O script dbalarm no Servidor [${SRV_NAME}] falhou ao encontrar ORACLE_HOME, Por favor, exporte a variável ORACLE_HOME no seu arquivo .bash_profile no diretório home do usuário oracle" $MAIL_LIST < /dev/null
exit
fi

# #########################
# Variáveis:
# #########################
export PATH=$PATH:${ORACLE_HOME}/bin
export LOG_DIR=${USR_ORA_HOME}/BUNDLE_Logs
mkdir -p ${LOG_DIR}
chown -R ${ORA_USER} ${LOG_DIR}
chmod -R go-rwx ${LOG_DIR}

        if [ ! -d ${LOG_DIR} ]
         then
          mkdir -p /tmp/BUNDLE_Logs
          export LOG_DIR=/tmp/BUNDLE_Logs
          chown -R ${ORA_USER} ${LOG_DIR}
          chmod -R go-rwx ${LOG_DIR}
        fi

# ##########################
# Neutralizar arquivo login.sql: [Correção de Bug]
# ##########################
# A existência do arquivo login.sql no diretório home do usuário Oracle no Linux elimina muitas funções durante a execução deste script a partir do crontab:
echo "Neutralizando login.sql se encontrado"

        if [ -f ${USR_ORA_HOME}/login.sql ]
         then
mv ${USR_ORA_HOME}/login.sql   ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}
        fi

# ########################
# Obtendo ORACLE_BASE:
# ########################
echo "Obtendo ORACLE BASE"
# Obter ORACLE_BASE do perfil do usuário se estiver VAZIO:

if [ -z "${ORACLE_BASE}" ]
 then
  ORACLE_BASE=`grep -h 'ORACLE_BASE=\/' $USR_ORA_HOME/.bash* $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
fi

# #########################
# Obtendo DB_NAME:
# #########################
echo "Configurando DB_NAME"
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

# ###################
# Obtendo Versão do DB:
# ###################
echo "Verificando Versão do DB"
VAL311=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select version from v\$instance;
exit;
EOF
)
DB_VER=`echo $VAL311|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`


# #####################
# Obtendo Tamanho do Bloco do DB:
# #####################
echo "Verificando Tamanho do Bloco do DB"
VAL312=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select value from v\$parameter where name='db_block_size';
exit;
EOF
)
blksize=`echo $VAL312|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`


# #####################
# Obtendo Função do DB:
# #####################
echo "Verificando Função do DB"
VAL312=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select DATABASE_ROLE from v\$database;
exit;
EOF
)
DB_ROLE=`echo $VAL312|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

        case ${DB_ROLE} in
         PRIMARY) DB_ROLE_ID=0;;
               *) DB_ROLE_ID=1;;
        esac


# ######################################
# Verificar Utilização da Área de Recuperação Flash:
# ######################################
VAL318=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select value from v\$parameter where name='db_recovery_file_dest';
exit;
EOF
)
FRA_LOC=`echo ${VAL318}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# Se FRA estiver configurado, verificar sua utilização:
  if [ ! -z ${FRA_LOC} ]
   then

FRACHK1=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 termout off echo off feedback off linesize 190
col name for A40
SELECT ROUND((SPACE_USED - SPACE_RECLAIMABLE)/SPACE_LIMIT * 100, 1) FROM V\$RECOVERY_FILE_DEST;
exit;
EOF
)

FRAPRCUSED=`echo ${FRACHK1}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# Converter FRAPRCUSED de número flutuante para inteiro:
FRAPRCUSED=${FRAPRCUSED%.*}
        if [ -z ${FRAPRCUSED} ]
         then
          FRAPRCUSED=1
        fi

# Se FRA %USADO >= o limite definido, enviar um alerta por e-mail:
INTEG='^[0-9]+$'
        # Verificar se o valor de FRAPRCUSED é um número válido:
        if [[ ${FRAPRCUSED} =~ ${INTEG} ]]
         then
echo "Verificando FRA para [${ORACLE_SID}] ..."
               if [ ${FRAPRCUSED} -ge ${FRATHRESHOLD} ]
                 then
FRA_RPT=${LOG_DIR}/FRA_REPORT.log

FRACHK2=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize 199
col name for a100
col TOTAL_MB for 99999999999999999
col FREE_MB for  99999999999999999
SPOOL ${FRA_RPT}
PROMPT
PROMPT Utilização da Área de Recuperação Flash:
PROMPT -----------------------------------------------

SELECT NAME,SPACE_LIMIT/1024/1024 TOTAL_MB,(SPACE_LIMIT - SPACE_USED + SPACE_RECLAIMABLE)/1024/1024 AS FREE_MB,
ROUND((SPACE_USED - SPACE_RECLAIMABLE)/SPACE_LIMIT * 100, 1) AS "%FULL"
FROM V\$RECOVERY_FILE_DEST;

PROMPT
PROMPT COMPONENTES DA FRA:
PROMPT ------------------------------

select * from v\$flash_recovery_area_usage;
spool off
exit;
EOF
)

mail -s "ALERTA: FRA atingiu ${FRAPRCUSED}% no banco de dados [${DB_NAME_UPPER}] no Servidor [${SRV_NAME}]" $MAIL_LIST < ${FRA_RPT}
               fi
        fi

rm -f ${FRAFULL}
rm -f ${FRA_RPT}
  fi


# ################################
# Verificar Utilização do Grupo de Discos ASM:
# ################################
echo "Verificando Utilização do Grupo de Discos ASM ..."
VAL314=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select count(*) from v\$asm_diskgroup;
exit;
EOF
)
ASM_GROUP_COUNT=`echo ${VAL314}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# Se os DISCOS ASM existirem, verificar a utilização do tamanho:
  if [ ${ASM_GROUP_COUNT} -gt 0 ]
   then
echo "Verificando ASM em [${ORACLE_SID}] ..."

ASM_UTL=${LOG_DIR}/ASM_UTILIZATION.log

ASMCHK1=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 termout off echo off feedback off linesize 190
col name for A40
spool ${ASM_UTL}
select name,ROUND((1-(free_mb / total_mb))*100, 2) "%FULL" from v\$asm_diskgroup;
spool off
exit;
EOF
)

ASMFULL=${LOG_DIR}/asm_full.log
#cat ${ASM_UTL}|awk '{ print $1" "$NF }'| while read OUTPUT3
cat ${ASM_UTL}|egrep -v ${EXL_DISK_GROUP}|awk '{ print $1" "$NF }'| while read OUTPUT3
   do
        ASMPRCUSED=`echo ${OUTPUT3}|awk '{print $NF}'`
        ASMDGNAME=`echo ${OUTPUT3}|awk '{print $1}'`
        echo "[Relatado pelo script ${SCRIPT_NAME}]"                       > ${ASMFULL}
        echo " "                                                        >> ${ASMFULL}
        echo "ASM_DISK_GROUP            %USADO"                          >> ${ASMFULL}
        echo "----------------------          --------------"           >> ${ASMFULL}
        echo "${ASMDGNAME}                        ${ASMPRCUSED}%"       >> ${ASMFULL}

# Converter ASMPRCUSED de número flutuante para inteiro:
ASMPRCUSED=${ASMPRCUSED%.*}
        if [ -z ${ASMPRCUSED} ]
         then
          ASMPRCUSED=1
        fi
# Se ASM %USADO >= o limite definido, enviar um e-mail para cada GRUPO DE DISCO:
               if [ ${ASMPRCUSED} -ge ${ASMTHRESHOLD} ]
                 then
ASM_RPT=${LOG_DIR}/ASM_REPORT.log

ASMCHK2=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 100
set linesize 199
col name for a35
SPOOL ${ASM_RPT}
prompt
prompt GRUPOS DE DISCO ASM:
PROMPT ------------------

select name,total_mb,free_mb,ROUND((1-(free_mb / total_mb))*100, 2) "%FULL" from v\$asm_diskgroup;
spool off
exit;
EOF
)

mail -s "ALERTA: GRUPO DE DISCO ASM [${ASMDGNAME}] atingiu ${ASMPRCUSED}% no banco de dados [${DB_NAME_UPPER}] no Servidor [${SRV_NAME}]" $MAIL_LIST < ${ASM_RPT}
               fi
   done

rm -f ${ASMFULL}
rm -f ${ASM_RPT}
  fi

# #########################
# Verificação de Tamanho dos Tablespaces:
# #########################

echo "Verificando TABLESPACES em [${ORACLE_SID}] ..."

        if [ ${DB_VER} -gt 10 ]
         then
# Se a Versão do Banco de Dados for 11g em diante:

TBSCHK=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF

set pages 0 termout off echo off feedback off 
col tablespace_name for A25
col y for 999999999 heading 'Total_MB'
col z for 999999999 heading 'Used_MB'
col bused for 999.99 heading '%Used'

spool ${LOG_DIR}/tablespaces_DBA_BUNDLE.log

select tablespace_name,
       (used_space*$blksize)/(1024*1024) Used_MB,
       (tablespace_size*$blksize)/(1024*1024) Total_MB,
       used_percent "%Used"
from dba_tablespace_usage_metrics;

spool off
exit;
EOF
)

         else

# Se a Versão do Banco de Dados for 10g para trás:
# Verificar se AUTOEXTEND OFF (MAXSIZE=0) está definido para qualquer um dos datafiles dividir pelo tamanho ALOCADO, caso contrário, dividir pelo MAXSIZE:
VAL33=$(${ORACLE_HOME}/bin/sqlplus -S '/ as sysdba' << EOF
set pages 0 feedback off;
SELECT COUNT(*) FROM DBA_DATA_FILES WHERE MAXBYTES=0;
exit;
EOF
)
VAL44=`echo $VAL33| awk '{print $NF}'`
                case ${VAL44} in
                "0") CALCPERCENTAGE1="((sbytes - fbytes)*100 / MAXSIZE) bused " ;;
                  *) CALCPERCENTAGE1="round(((sbytes - fbytes) / sbytes) * 100,2) bused " ;;
                esac

VAL55=$(${ORACLE_HOME}/bin/sqlplus -S '/ as sysdba' << EOF
set pages 0 feedback off;
SELECT COUNT(*) FROM DBA_TEMP_FILES WHERE MAXBYTES=0;
exit;
EOF
)
VAL66=`echo $VAL55| awk '{print $NF}'`
                case ${VAL66} in
                "0") CALCPERCENTAGE2="((sbytes - fbytes)*100 / MAXSIZE) bused " ;;
                  *) CALCPERCENTAGE2="round(((sbytes - fbytes) / sbytes) * 100,2) bused " ;;
                esac

TBSCHK=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 termout off echo off feedback off 
col tablespace for A25
col "MAXSIZE MB" format 9999999
col x for 999999999 heading 'Allocated MB'
col y for 999999999 heading 'Free MB'
col z for 999999999 heading 'Used MB'
col bused for 999.99 heading '%Used'
--bre on report
spool ${LOG_DIR}/tablespaces_DBA_BUNDLE.log
select a.tablespace_name tablespace,bb.MAXSIZE/1024/1024 "MAXSIZE MB",sbytes/1024/1024 x,fbytes/1024/1024 y,
(sbytes - fbytes)/1024/1024 z,
$CALCPERCENTAGE1
--round(((sbytes - fbytes) / sbytes) * 100,2) bused
--((sbytes - fbytes)*100 / MAXSIZE) bused
from (select tablespace_name,sum(bytes) sbytes from dba_data_files group by tablespace_name ) a,
     (select tablespace_name,sum(bytes) fbytes,count(*) ext from dba_free_space group by tablespace_name) b,
     (select tablespace_name,sum(MAXBYTES) MAXSIZE from dba_data_files group by tablespace_name) bb
--where a.tablespace_name in (select tablespace_name from dba_tablespaces)
where a.tablespace_name = b.tablespace_name (+)
and a.tablespace_name = bb.tablespace_name
and round(((sbytes - fbytes) / sbytes) * 100,2) > 0
UNION ALL
select c.tablespace_name tablespace,dd.MAXSIZE/1024/1024 MAXSIZE_GB,sbytes/1024/1024 x,fbytes/1024/1024 y,
(sbytes - fbytes)/1024/1024 obytes,
$CALCPERCENTAGE2
from (select tablespace_name,sum(bytes) sbytes
      from dba_temp_files group by tablespace_name having tablespace_name in (select tablespace_name from dba_tablespaces)) c,
     (select tablespace_name,sum(bytes_free) fbytes,count(*) ext from v\$temp_space_header group by tablespace_name) d,
     (select tablespace_name,sum(MAXBYTES) MAXSIZE from dba_temp_files group by tablespace_name) dd
--where c.tablespace_name in (select tablespace_name from dba_tablespaces)
where c.tablespace_name = d.tablespace_name (+)
and c.tablespace_name = dd.tablespace_name
order by tablespace;
select tablespace_name,null,null,null,null,null||'100.00' from dba_data_files minus select tablespace_name,null,null,null,null,null||'100.00'  from dba_free_space;
spool off
exit;
EOF
)
        fi
TBSLOG=${LOG_DIR}/tablespaces_DBA_BUNDLE.log
TBSFULL=${LOG_DIR}/full_tbs.log
#cat ${TBSLOG}|awk '{ print $1" "$NF }'| while read OUTPUT2
cat ${TBSLOG}|egrep -v ${EXL_TBS} |awk '{ print $1" "$NF }'| while read OUTPUT2
   do
        PRCUSED=`echo ${OUTPUT2}|awk '{print $NF}'`
        TBSNAME=`echo ${OUTPUT2}|awk '{print $1}'`
        echo "[Relatado pelo script ${SCRIPT_NAME}]"               > ${TBSFULL}
        echo " "                                                >> ${TBSFULL}
        echo "Tablespace_name          %USADO"                   >> ${TBSFULL}
        echo "----------------------          --------------"   >> ${TBSFULL}
#       echo ${OUTPUT2}|awk '{print $1"                              "$NF}' >> ${TBSFULL}
        echo "${TBSNAME}                        ${PRCUSED}%"    >> ${TBSFULL}

# Converter PRCUSED de número flutuante para inteiro:
PRCUSED=${PRCUSED%.*}
        if [ -z ${PRCUSED} ]
         then
          PRCUSED=1
        fi
# Se o tablespace %USADO >= o limite definido, enviar um e-mail para cada tablespace:
               if [ ${PRCUSED} -ge ${TBSTHRESHOLD} ]
                 then
mail -s "ALERTA: TABLESPACE [${TBSNAME}] atingiu ${PRCUSED}% no banco de dados [${DB_NAME_UPPER}] no Servidor [${SRV_NAME}]" $MAIL_LIST < ${TBSFULL}
               fi
   done

rm -f ${LOG_DIR}/tablespaces_DBA_BUNDLE.log
rm -f ${LOG_DIR}/full_tbs.log


# ############################################
# Verificando Serviços Monitorados:
# ############################################

#case ${DB_NAME} in
#ORCL)


if [ ! -x ${SERVICEMON} ]
then
echo "Verificando Serviços Monitorados em [${ORACLE_SID}] ..."
VAL_SRVMON_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off;
prompt
select count(*) from GV\$ACTIVE_SERVICES where lower(NAME) in (${SERVICEMON}) or upper(NAME) in (${SERVICEMON});
exit;
EOF
) 
VAL_SRVMON=`echo ${VAL_SRVMON_RAW}| awk '{print $NF}'`
#echo $VAL_SRVMON_RAW
#echo $VAL_SRVMON
               if [ ${VAL_SRVMON} -lt 1 ]
                 then
VAL_SRVMON_EMAIL=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize 160 pages 0 echo off feedback off
spool ${LOG_DIR}/current_running_services.log
PROMPT
PROMPT Serviços em Execução no Momento: [Instância: ${ORACLE_SID}]
PROMPT ************************

select INST_ID,NAME from GV\$ACTIVE_SERVICES where NAME not in ('SYS\$BACKGROUND','SYS\$USERS');
spool off
exit;
EOF
)

mail -s "ALERTA: SERVIÇO ${SERVICEMON} Está INDISPONÍVEL no banco de dados [${DB_NAME_UPPER}] no Servidor [${SRV_NAME}]" $MAIL_LIST < ${LOG_DIR}/current_running_services.log
rm -f ${LOG_DIR}/current_running_services.log
                fi
fi

#;;
#esac

# ############################################
# Verificando SESSÕES BLOQUEADAS NO BANCO DE DADOS:
# ############################################

echo "Verificando Sessões Bloqueadas em [${ORACLE_SID}] ..."

VAL77=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off;
select count(*) from gv\$LOCK l1, gv\$SESSION s1, gv\$LOCK l2, gv\$SESSION s2
where s1.sid=l1.sid and s2.sid=l2.sid and l1.BLOCK=1 and l2.request > 0 and l1.id1=l2.id1 and l2.id2=l2.id2;
exit;
EOF
) 
VAL88=`echo $VAL77| awk '{print $NF}'`
               if [ ${VAL88} -ge ${BLOCKTHRESHOLD} ]
                 then
VAL99=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize 160 pages 0 echo off feedback off
col BLOCKING_STATUS for a90
spool ${LOG_DIR}/blocking_sessions.log
select 'User: '||s1.username || '@' || s1.machine || '(SID=' || s1.sid ||' ) running SQL_ID:'||s1.sql_id||'  is blocking
User: '|| s2.username || '@' || s2.machine || '(SID=' || s2.sid || ') running SQL_ID:'||s2.sql_id||' For '||s2.SECONDS_IN_WAIT||' sec
------------------------------------------------------------------------------
Warn user '||s1.username||' Or use the following statement to kill his session:
------------------------------------------------------------------------------
ALTER SYSTEM KILL SESSION '''||s1.sid||','||s1.serial#||''' immediate;' AS blocking_status
from gv\$LOCK l1, gv\$SESSION s1, gv\$LOCK l2, gv\$SESSION s2
 where s1.sid=l1.sid and s2.sid=l2.sid 
 and l1.BLOCK=1 and l2.request > 0
 and l1.id1 = l2.id1
 and l2.id2 = l2.id2
 order by s2.SECONDS_IN_WAIT desc;

prompt
prompt ----------------------------------------------------------------

Prompt Bloqueios de Objetos:
prompt ----------------------------------------------------------------

set linesize 160 pages 100 echo on feedback on
column OS_PID format A15 Heading "OS_PID"
column ORACLE_USER format A15 Heading "ORACLE_USER"
column LOCK_TYPE format A15 Heading "LOCK_TYPE"
column LOCK_HELD format A11 Heading "LOCK_HELD"
column LOCK_REQUESTED format A11 Heading "LOCK_REQUESTED"
column STATUS format A13 Heading "STATUS"
column OWNER format A15 Heading "OWNER"
column OBJECT_NAME format A35 Heading "OBJECT_NAME"
select  l.sid,
        ORACLE_USERNAME oracle_user,
        decode(TYPE,
                'MR', 'Media Recovery',
                'RT', 'Redo Thread',
                'UN', 'User Name',
                'TX', 'Transaction',
                'TM', 'DML',
                'UL', 'PL/SQL User Lock',
                'DX', 'Distributed Xaction',
                'CF', 'Control File',
                'IS', 'Instance State',
                'FS', 'File Set',
                'IR', 'Instance Recovery',
                'ST', 'Disk Space Transaction',
                'TS', 'Temp Segment',
                'IV', 'Library Cache Invalidation',
                'LS', 'Log Start or Switch',
                'RW', 'Row Wait',
                'SQ', 'Sequence Number',
                'TE', 'Extend Table',
                'TT', 'Temp Table', type) lock_type,
        decode(LMODE,
                0, 'None',
                1, 'Null',
                2, 'Row-S (SS)',
                3, 'Row-X (SX)',
                4, 'Share',
                5, 'S/Row-X (SSX)',
                6, 'Exclusive', lmode) lock_held,
        decode(REQUEST,
                0, 'None',
                1, 'Null',
                2, 'Row-S (SS)',
                3, 'Row-X (SX)',
                4, 'Share',
                5, 'S/Row-X (SSX)',
                6, 'Exclusive', request) lock_requested,
        decode(BLOCK,
                0, 'Not Blocking',
                1, 'Blocking',
                2, 'Global', block) status,
        OWNER,
        OBJECT_NAME
from    v\$locked_object lo,
        dba_objects do,
        v\$lock l
where   lo.OBJECT_ID = do.OBJECT_ID
AND     l.SID = lo.SESSION_ID
AND l.BLOCK='1';

prompt
prompt ----------------------------------------------------------------

Prompt Operações Longas no BANCO DE DADOS $ORACLE_SID:
prompt ----------------------------------------------------------------

col "USER | SID,SERIAL#" for a40
col MESSAGE for a80
col "%COMPLETE" for 999.99
col "SID|SERIAL#" for a12
        set linesize 200
        select USERNAME||' | '||SID||','||SERIAL# "USER | SID,SERIAL#",SQL_ID,START_TIME,SOFAR/TOTALWORK*100 "%COMPLETE",
        trunc(ELAPSED_SECONDS/60) MIN_ELAPSED, trunc(TIME_REMAINING/60) MIN_REMAINING,substr(MESSAGE,1,80)MESSAGE
        from v\$session_longops where SOFAR/TOTALWORK*100 <>'100'
        order by MIN_REMAINING;

spool off
exit;
EOF
)
mail -s "ALERTA: SESSÕES BLOQUEADAS detectadas no banco de dados [${DB_NAME_UPPER}] no Servidor [${SRV_NAME}]" $MAIL_LIST < ${LOG_DIR}/blocking_sessions.log
rm -f ${LOG_DIR}/blocking_sessions.log
                fi
  
# #########################
# Obtendo caminho do ALERTLOG:
# #########################

echo "Verificando ALERTLOG de [${ORACLE_SID}] ..."

VAL2=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT value from v\$parameter where NAME='background_dump_dest';
exit;
EOF
)
ALERTZ=`echo $VAL2 | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
ALERTDB=${ALERTZ}/alert_${ORACLE_SID}.log


# ###########################
# Verificando Erros do Banco de Dados:
# ###########################

# Determinar o caminho do ALERTLOG:
        if [ -f ${ALERTDB} ]
         then
          ALERTLOG=${ALERTDB}
        elif [ -f $ORACLE_BASE/admin/${ORACLE_SID}/bdump/alert_${ORACLE_SID}.log ]
         then
          ALERTLOG=$ORACLE_BASE/admin/${ORACLE_SID}/bdump/alert_${ORACLE_SID}.log
        elif [ -f $ORACLE_HOME/diagnostics/${DB_NAME}/diag/rdbms/${DB_NAME}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log ]
         then
          ALERTLOG=$ORACLE_HOME/diagnostics/${DB_NAME}/diag/rdbms/${DB_NAME}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log
        else
          ALERTLOG=`/usr/bin/find ${ORACLE_BASE} -iname alert_${ORACLE_SID}.log  -print 2>/dev/null`
        fi

# Renomear o log antigo gerado pelo script (se existir):
 if [ -f ${LOG_DIR}/alert_${ORACLE_SID}_new.log ]
  then
   mv ${LOG_DIR}/alert_${ORACLE_SID}_new.log ${LOG_DIR}/alert_${ORACLE_SID}_old.log
   # Criar novo log:
   tail -1000 ${ALERTLOG} > ${LOG_DIR}/alert_${ORACLE_SID}_new.log
   # Extrair novas entradas comparando logs antigos e novos:
   echo "[Relatado pelo script ${SCRIPT_NAME}]"    > ${LOG_DIR}/diff_${ORACLE_SID}.log
   echo " "                                     >> ${LOG_DIR}/diff_${ORACLE_SID}.log
   diff ${LOG_DIR}/alert_${ORACLE_SID}_old.log ${LOG_DIR}/alert_${ORACLE_SID}_new.log |grep ">" | cut -f2 -d'>' >> ${LOG_DIR}/diff_${ORACLE_SID}.log

   # Procurar por erros:

   ERRORS=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log | grep 'ORA-\|TNS-' |egrep -v ${EXL_ALERT_ERR}| tail -1`
   EXPFLAG=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log | grep 'DM00 ' | tail -1`
   ALTERSFLAG=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log | grep 'ALTER SYSTEM ' | tail -1`
   ALTERDFLAG=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log | grep 'Completed: ' | tail -1`
   STARTUPFLAG=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log | grep 'Starting ORACLE instance' | tail -1`
   SHUTDOWNFLAG=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log | grep 'Instance shutdown complete' | tail -1`

   FILE_ATTACH=${LOG_DIR}/diff_${ORACLE_SID}.log

 else
   # Criar novo log:
   echo "[Relatado pelo script ${SCRIPT_NAME}]"    > ${LOG_DIR}/alert_${ORACLE_SID}_new.log
   echo " "                                     >> ${LOG_DIR}/alert_${ORACLE_SID}_new.log
   tail -1000 ${ALERTLOG}                       >> ${LOG_DIR}/alert_${ORACLE_SID}_new.log

   # Procurar por erros:
   ERRORS=`cat ${LOG_DIR}/alert_${ORACLE_SID}_new.log | grep 'ORA-\|TNS-' |egrep -v ${EXL_ALERT_ERR}| tail -1`
   FILE_ATTACH=${LOG_DIR}/alert_${ORACLE_SID}_new.log
 fi

# Enviar e-mail caso existam erros:

        case "${ERRORS}" in
        *ORA-*|*TNS-*)
mail -s "ALERTA: Instância [${ORACLE_SID}] no Servidor [${SRV_NAME}] relatando erros: ${ERRORS}" ${MAIL_LIST} < ${FILE_ATTACH} 
echo "ALERTA: Instância [${ORACLE_SID}] no Servidor [${SRV_NAME}] relatando erros: ${ERRORS}"
	;;
        esac

                case ${PARANOIDMODE} in
                y|Y|yes|YES|Yes|true|TRUE|True|on|ON|On)

        case "${EXPFLAG}" in
        *'DM00'*)
mail -s "INFO: Operação de EXPORT/IMPORT Iniciada na Instância [${ORACLE_SID}] no Servidor [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo "INFO: Operação de EXPORT/IMPORT Iniciada na Instância [${ORACLE_SID}] no Servidor [${SRV_NAME}]"
        ;;
        esac

        case "${ALTERSFLAG}" in
        *'ALTER SYSTEM'*)
mail -s "INFO: Comando ALTER SYSTEM Executado Contra a Instância [${ORACLE_SID}] no Servidor [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo "INFO: Comando ALTER SYSTEM Executado Contra a Instância [${ORACLE_SID}] no Servidor [${SRV_NAME}]"
        ;;
        esac

        case "${ALTERDFLAG}" in
        *'Completed:'*)
mail -s "INFO: ATIVIDADE IMPORTANTE DO DB Concluída na Instância [${ORACLE_SID}] no Servidor [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo "INFO: ATIVIDADE IMPORTANTE DO DB Concluída na Instância [${ORACLE_SID}] no Servidor [${SRV_NAME}]"
        ;;
        esac

        case "${STARTUPFLAG}" in
        *'Starting ORACLE instance'*)
mail -s "ALERTA: Evento de Inicialização da Instância [${ORACLE_SID}] Disparado no Servidor [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo "ALERTA: Evento de Inicialização da Instância [${ORACLE_SID}] Disparado no Servidor [${SRV_NAME}]"
        ;;
        esac

        case "${SHUTDOWNFLAG}" in
        *'Instance shutdown complete'*)
mail -s "ALERTA: Evento de Desligamento da Instância [${ORACLE_SID}] Disparado no Servidor [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo "ALERTA: Evento de Desligamento da Instância [${ORACLE_SID}] Disparado no Servidor [${SRV_NAME}]"
        ;;
        esac

                ;;
                esac



# #####################
# Relatando Bancos de Dados Offline:
# #####################
# Popular ${LOG_DIR}/alldb_DBA_BUNDLE.log a partir do ORATAB:
# colocar todas as instâncias em execução em uma variável:
ALL_RUNNING_INSTANCES=`ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g"`
# Excluir todas as instâncias/bancos de dados em execução de serem verificadas ao ler o arquivo ORATAB:
grep -v '^\#' $ORATAB |egrep -v "${EXL_DB}"|egrep -v "${ALL_RUNNING_INSTANCES}"|grep -v "${DB_NAME_LOWER}:"| grep -v "${DB_NAME_UPPER}:"|  grep -v '^$' | grep "^" | cut -f1 -d':' > ${LOG_DIR}/alldb_DBA_BUNDLE.log

# Popular ${LOG_DIR}/updb_DBA_BUNDLE.log:
  echo ${ORACLE_SID}    >> ${LOG_DIR}/updb_DBA_BUNDLE.log
  echo ${DB_NAME}       >> ${LOG_DIR}/updb_DBA_BUNDLE.log

# Fim do loop para bancos de dados:
done

# Continuar Relatando Bancos de Dados Offline...
        case ${CHKOFFLINEDB} in
        Y|y|YES|yes|Yes)
echo "Verificando Bancos de Dados Offline ..."
# Ordenar as linhas alfabeticamente removendo duplicatas:
sort ${LOG_DIR}/updb_DBA_BUNDLE.log  | uniq -d                                  > ${LOG_DIR}/updb_DBA_BUNDLE.log.sort
sort ${LOG_DIR}/alldb_DBA_BUNDLE.log                                            > ${LOG_DIR}/alldb_DBA_BUNDLE.log.sort
diff ${LOG_DIR}/alldb_DBA_BUNDLE.log.sort ${LOG_DIR}/updb_DBA_BUNDLE.log.sort   > ${LOG_DIR}/diff_DBA_BUNDLE.sort
echo "As Seguintes Instâncias estão POSSIVELMENTE Offline/Travadas em [${SRV_NAME}]:"       > ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"       >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
grep "^< " ${LOG_DIR}/diff_DBA_BUNDLE.sort | cut -f2 -d'<'                      >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo " "                                                                        >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo "Se as instâncias acima estiverem permanentemente offline, adicione seus nomes ao parâmetro 'EXL_DB' na linha# 90 ou comente suas entradas no ${ORATAB} para que o script as ignore na próxima execução." >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
OFFLINE_DBS_NUM=`cat ${LOG_DIR}/offdb_DBA_BUNDLE.log| wc -l`
  
# Se OFFLINE_DBS não for nulo:
        if [ ${OFFLINE_DBS_NUM} -gt 4 ]
         then
echo ""                           >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo "Instâncias em Execução no Momento:" >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo "************************"   >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
ps -ef|grep pmon|grep -v grep     >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo ""                           >> ${LOG_DIR}/offdb_DBA_BUNDLE.log

VALX1=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 100;
spool ${LOG_DIR}/running_instances.log
set linesize 160
col BLOCKED for a7
col STARTUP_TIME for a19 
select instance_name INS_NAME,STATUS,DATABASE_STATUS DB_STATUS,LOGINS,BLOCKED,to_char(STARTUP_TIME,'DD-MON-YY HH24:MI:SS') STARTUP_TIME from v\$instance;
spool off
exit;
EOF
)
cat ${LOG_DIR}/running_instances.log >> ${LOG_DIR}/offdb_DBA_BUNDLE.log

mail -s "ALERTA: Banco de Dados Inacessível no Servidor: [$SRV_NAME]" $MAIL_LIST < ${LOG_DIR}/offdb_DBA_BUNDLE.log
        fi

# Limpando Logs:
#cat /dev/null >  ${LOG_DIR}/updb_DBA_BUNDLE.log
#cat /dev/null >  ${LOG_DIR}/alldb_DBA_BUNDLE.log
#cat /dev/null >  ${LOG_DIR}/updb_DBA_BUNDLE.log.sort
#cat /dev/null >  ${LOG_DIR}/alldb_DBA_BUNDLE.log.sort
#cat /dev/null >  ${LOG_DIR}/diff_DBA_BUNDLE.sort

rm -f ${LOG_DIR}/updb_DBA_BUNDLE.log
rm -f ${LOG_DIR}/alldb_DBA_BUNDLE.log
rm -f ${LOG_DIR}/updb_DBA_BUNDLE.log.sort
rm -f ${LOG_DIR}/alldb_DBA_BUNDLE.log.sort
rm -f ${LOG_DIR}/diff_DBA_BUNDLE.sort

        ;;
        esac

# ###########################
# Verificando logs de Listeners:
# ###########################
# Verificar se a flag de VERIFICAÇÃO DO LISTENER está em Y:

                case ${CHKLISTENER} in
                Y|y|YES|yes|Yes)
echo "Verificando Log do Listener de [${ORACLE_SID}] ..."
# Caso não haja Listeners em execução, enviar um (Alarme):
LSN_COUNT=$( ps -ef|grep -v grep|grep tnslsnr|wc -l )

 if [ $LSN_COUNT -eq 0 ]
  then
   echo "Os seguintes são os LISTENERS em execução pelo usuário ${ORA_USER} no servidor ${SRV_NAME}:"     > ${LOG_DIR}/listener_processes.log
   echo "************************************************************************************"  >> ${LOG_DIR}/listener_processes.log
   ps -ef|grep -v grep|grep tnslsnr                                                             >> ${LOG_DIR}/listener_processes.log
mail -s "ALERTA: Nenhum Listener Está em Execução no Servidor: $SRV_NAME !!!" $MAIL_LIST                    < ${LOG_DIR}/listener_processes.log
  
  # Caso haja listener em execução, analisar seu log:
  else
#        for LISTENER_NAME in $( ps -ef|grep -v grep|grep tnslsnr|awk '{print $(NF-1)}' )
         for LISTENER_NAME in $( ps -ef|grep -v grep|grep tnslsnr|awk '{print $(9)}' )
         do
#         LISTENER_HOME=`ps -ef|grep -v grep|grep tnslsnr|grep "${LISTENER_NAME} "|awk '{print $(NF-2)}' |sed -e 's/\/bin\/tnslsnr//g'|grep -v sed|grep -v "s///g"`
          LISTENER_HOME=`ps -ef|grep -v grep|grep tnslsnr|grep "${LISTENER_NAME} "|awk '{print $(8)}' |sed -e 's/\/bin\/tnslsnr//g'|grep -v sed|grep -v "s///g"`
          export LISTENER_HOME
          TNS_ADMIN=${LISTENER_HOME}/network/admin; export TNS_ADMIN
          export TNS_ADMIN
          LISTENER_LOGDIR=`${LISTENER_HOME}/bin/lsnrctl status ${LISTENER_NAME} |grep "Listener Log File"| awk '{print $NF}'| sed -e 's/\/alert\/log.xml//g'`
          export LISTENER_LOGDIR
          LISTENER_LOG=${LISTENER_LOGDIR}/trace/${LISTENER_NAME}.log
          export LISTENER_LOG

          # Determinar se o nome do listener está em maiúsculas/minúsculas:
                if [ ! -f  ${LISTENER_LOG} ]
                 then
                  # Nome do listener está em maiúsculas:
                  LISTENER_NAME=$( echo ${LISTENER_NAME} | awk '{print toupper($0)}' )
                  export LISTENER_NAME
                  LISTENER_LOG=${LISTENER_LOGDIR}/trace/${LISTENER_NAME}.log
                  export LISTENER_LOG
                fi
                if [ ! -f  ${LISTENER_LOG} ]
                 then
                  # Nome do listener está em minúsculas:
                  LISTENER_NAME=$( echo "${LISTENER_NAME}" | awk '{print tolower($0)}' )
                  export LISTENER_NAME
                  LISTENER_LOG=${LISTENER_LOGDIR}/trace/${LISTENER_NAME}.log
                  export LISTENER_LOG
                fi

    if [ -f  ${LISTENER_LOG} ]
        then
          # Renomear o log antigo (Se existir):
          if [ -f ${LOG_DIR}/alert_${LISTENER_NAME}_new.log ]
           then
              mv ${LOG_DIR}/alert_${LISTENER_NAME}_new.log ${LOG_DIR}/alert_${LISTENER_NAME}_old.log
            # Criar um novo log:
              tail -1000 ${LISTENER_LOG}                 > ${LOG_DIR}/alert_${LISTENER_NAME}_new.log
            # Obter as novas entradas:
              echo "[Relatado pelo script ${SCRIPT_NAME}]"  > ${LOG_DIR}/diff_${LISTENER_NAME}.log
              echo " "                                  >> ${LOG_DIR}/diff_${LISTENER_NAME}.log
              diff ${LOG_DIR}/alert_${LISTENER_NAME}_old.log  ${LOG_DIR}/alert_${LISTENER_NAME}_new.log | grep ">" | cut -f2 -d'>' >> ${LOG_DIR}/diff_${LISTENER_NAME}.log
            # Procurar por erros:
             #ERRORS=`cat ${LOG_DIR}/diff_${LISTENER_NAME}.log|grep "TNS-"|egrep -v "${EXL_LSNR_ERR}"|tail -1`
             ERRORS=`cat ${LOG_DIR}/diff_${LISTENER_NAME}.log|grep "TNS-"|egrep -v "${EXL_LSNR_ERR}"|tail -1`
             SRVC_REG=`cat ${LOG_DIR}/diff_${LISTENER_NAME}.log| grep "service_register" `
             FILE_ATTACH=${LOG_DIR}/diff_${LISTENER_NAME}.log

         # Se não houver logs antigos:
         else
            # Apenas criar um novo log sem fazer nenhuma comparação:
             echo "[Relatado pelo script ${SCRIPT_NAME}]"          > ${LOG_DIR}/alert_${LISTENER_NAME}_new.log
             echo " "                                   >> ${LOG_DIR}/alert_${LISTENER_NAME}_new.log
             tail -1000 ${LISTENER_LOG}                 >> ${LOG_DIR}/alert_${LISTENER_NAME}_new.log

            # Procurar por erros:
              #ERRORS=`cat ${LOG_DIR}/alert_${LISTENER_NAME}_new.log|grep "TNS-"|egrep -v "${EXL_LSNR_ERR}"|tail -1`
              ERRORS=`cat ${LOG_DIR}/alert_${LISTENER_NAME}_new.log|grep "TNS-"|egrep -v "${EXL_LSNR_ERR}"|tail -1`
              SRVC_REG=`cat ${LOG_DIR}/alert_${LISTENER_NAME}_new.log | grep "service_register" `
              FILE_ATTACH=${LOG_DIR}/alert_${LISTENER_NAME}_new.log
         fi

          # Relatar Erros TNS (Alerta)
            case "$ERRORS" in
            *TNS-*)
mail -s "ALERTA: Listener [${LISTENER_NAME}] no Servidor [${SRV_NAME}] relatando erros: ${ERRORS}" $MAIL_LIST < ${FILE_ATTACH}
            esac

          # Relatar Serviços Registrados no listener (Informação)
            case "$SRVC_REG" in
            *service_register*)
mail -s "INFO: Serviço Registrado no Listener [${LISTENER_NAME}] no Servidor [${SRV_NAME}] | Possibilidade de envenenamento TNS" $MAIL_LIST < ${FILE_ATTACH}
            esac
        else
         echo "Não foi possível encontrar o log do listener: <${LISTENER_LOG}> para o listener ${LISTENER_NAME} !"
    fi
        done
 fi

                esac

# ###########################
# Verificando Erros do Goldengate:
# ###########################
# Especificar manualmente a localização do arquivo de log do goldengate: [Caso o script falhe em encontrar sua localização]
ALERTGGPATH=

# Verificar se a flag de VERIFICAÇÃO DO GOLDENGATE está em Y:

                case ${CHKGOLDENGATE} in
                Y|y|YES|yes|Yes)
echo "Verificando log do GoldenGate ..."

# Determinar o caminho do log do goldengate:
        if [ ! -z ${ALERTGGPATH} ]
         then
          GGLOG=${ALERTGGPATH}
        else
          GGLOG=`/bin/ps -ef|grep ggserr.log|grep -v grep|tail -1|awk '{print $NF}'`
        fi

# Renomear o log antigo gerado pelo script (se existir):
 if [ -f ${LOG_DIR}/ggserr_new.log ]
  then
   mv ${LOG_DIR}/ggserr_new.log ${LOG_DIR}/ggserr_old.log
   # Criar novo log:
   tail -1000 ${GGLOG}                          > ${LOG_DIR}/ggserr_new.log

   # Extrair novas entradas comparando logs antigos e novos:
   echo "[Relatado pelo script ${SCRIPT_NAME}]"    > ${LOG_DIR}/diff_ggserr.log
   echo " "                                     >> ${LOG_DIR}/diff_ggserr.log
   diff ${LOG_DIR}/ggserr_old.log  ${LOG_DIR}/ggserr_new.log |grep ">" | cut -f2 -d'>' >> ${LOG_DIR}/diff_ggserr.log

   # Procurar por erros:
   #ERRORS=`cat ${LOG_DIR}/diff_ggserr.log | grep 'ERROR' |egrep -v ${EXL_GG_ERR}| tail -1`
   ERRORS=`cat ${LOG_DIR}/diff_ggserr.log | grep 'ERROR' | tail -1`

   FILE_ATTACH=${LOG_DIR}/diff_ggserr.log

 else
   # Criar novo log:
   echo "[Relatado pelo script ${SCRIPT_NAME}]"    > ${LOG_DIR}/ggserr_new.log
   echo " "                                     >> ${LOG_DIR}/ggserr_new.log
   tail -1000 ${GGLOG}                          >> ${LOG_DIR}/ggserr_new.log

   # Procurar por erros:
   #ERRORS=`cat ${LOG_DIR}/ggserr_new.log | grep 'ERROR' |egrep -v ${EXL_GG_ERR}| tail -1`
   ERRORS=`cat ${LOG_DIR}/ggserr_new.log | grep 'ERROR' | tail -1`
   FILE_ATTACH=${LOG_DIR}/ggserr_new.log
 fi

# Enviar e-mail caso existam erros:
        case ${ERRORS} in
        *ERROR*)
mail -s "Erro no Goldengate no Servidor [${SRV_NAME}]: ${ERRORS}" ${MAIL_LIST} < ${FILE_ATTACH}
        esac
                esac

# Desneutralizar arquivo login.sql:
# Se login.sql foi renomeado durante a execução do script, revertê-lo para seu nome original:
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

