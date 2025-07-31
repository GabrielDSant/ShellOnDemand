# #####################################################################
# Este script realiza um backup completo (FULL) do banco de dados usando RMAN.
# [Versão 4.0]
#						#   #     #
# Autor:	Mahmmoud ADEL	      	      # # # #   ###
# Criado em:	24-09-11	    	    #   #   # #   # 
# Modificado em:	31-12-13	     
#		Personalizado para rodar em
#		diversos ambientes.
#		12-03-16 Executa o comando RMAN em segundo plano
#         	         para evitar falhas no trabalho quando a sessão é encerrada.
#		23-08-16 Adicionada a opção de criptografia de backup.
#		17-11-16 Adicionado recurso de número de canais.
#		22-01-18 Adicionada a opção de backup compactado do arquivo de controle.
#
# #####################################################################

# ###########
# Descrição:
# ###########
# Este script realiza um backup completo do banco de dados Oracle usando RMAN.
# Ele verifica as instâncias disponíveis, permite a seleção do banco de dados,
# configura o ambiente necessário e cria um script RMAN para realizar o backup.
# O backup pode ser compactado e criptografado, dependendo das opções fornecidas pelo usuário.

echo
echo "==================================================="
echo "Este script realiza um backup completo (FULL) do banco de dados usando RMAN."
echo "==================================================="
echo
sleep 1

# ###########################
# Verificação da contagem de CPUs:
# ###########################

# Contagem de CPUs:
CPU_NUM=`cat /proc/cpuinfo|grep CPU|wc -l`
export CPU_NUM


# #######################################
# Instâncias Excluídas:
# #######################################
# Aqui você pode mencionar as instâncias que o script irá IGNORAR e NÃO será executado:
# Use o pipe "|" como separador entre cada nome de instância.
# Exemplo: Excluindo: -MGMTDB, instâncias ASM:

EXL_DB="\-MGMTDB|ASM"                           # Instâncias Excluídas [Não serão reportadas como offline].


# ##############################
# O MOTOR DO SCRIPT COMEÇA AQUI ............................................
# ##############################

# ###########################
# Listando Bancos de Dados Disponíveis:
# ###########################

# Contagem de Instâncias:
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|wc -l )

# Sair se nenhum banco de dados estiver em execução:
if [ $INS_COUNT -eq 0 ]
 then
   echo Nenhum Banco de Dados em Execução!
   exit
fi

# Se houver apenas um banco de dados, defini-lo como padrão sem solicitar seleção:
if [ $INS_COUNT -eq 1 ]
 then
   export ORACLE_SID=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )

# Se houver mais de um banco de dados, solicitar ao usuário que selecione:
elif [ $INS_COUNT -gt 1 ]
 then
    echo
    echo "Selecione o ORACLE_SID:[Digite o número]"
    echo ---------------------
    select DB_ID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
     do
        if [ -z "${REPLY##[0-9]*}" ]
         then
          export ORACLE_SID=$DB_ID
          echo Instância Selecionada:
          echo $DB_ID
          break
         else
          export ORACLE_SID=${REPLY}
          break
        fi
     done

fi
# Sair se o usuário selecionar um número não listado:
        if [ -z "${ORACLE_SID}" ]
         then
          echo "Você inseriu um ORACLE_SID INVÁLIDO"
          exit
        fi

# #########################
# Obtendo ORACLE_HOME
# #########################
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|egrep -v ${EXL_DB}|grep -v "\-MGMTDB"|awk '{print $1}'|tail -1`
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
# Sair se o usuário não for o proprietário do Oracle:
# ########################################
CURR_USER=`whoami`
	if [ ${ORA_USER} != ${CURR_USER} ]; then
	  echo ""
	  echo "Você está executando este script com o usuário: \"${CURR_USER}\" !!!"
	  echo "Por favor, execute este script com o usuário correto do sistema operacional: \"${ORA_USER}\""
	  echo "Script Encerrado!"
	  exit
	fi

# ###############################
# RMAN: Criação do Script:
# ###############################
# Última Informação de Backup RMAN:
# #####################
export NLS_DATE_FORMAT='DD-Mon-YYYY HH24:MI:SS'
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 170 pages 200
PROMPT DETALHES DOS BACKUPS RMAN DOS ÚLTIMOS 14 DIAS:
PROMPT ---------------------------------

set linesize 160
set feedback off
col START_TIME for a15
col END_TIME for a15
col TIME_TAKEN_DISPLAY for a10
col INPUT_BYTES_DISPLAY heading "TAMANHO DOS DADOS" for a10
col OUTPUT_BYTES_DISPLAY heading "Tamanho do Backup" for a11
col OUTPUT_BYTES_PER_SEC_DISPLAY heading "Velocidade/s" for a10
col output_device_type heading "Tipo_Dispositivo" for a11
SELECT to_char (start_time,'DD-MON-YY HH24:MI') START_TIME, to_char(end_time,'DD-MON-YY HH24:MI') END_TIME, time_taken_display, status,
input_type, output_device_type,input_bytes_display, output_bytes_display, output_bytes_per_sec_display,COMPRESSION_RATIO COMPRESS_RATIO
FROM v\$rman_backup_job_details
WHERE end_time > sysdate -14;

EOF

# Variáveis:
export NLS_DATE_FORMAT="DD-MON-YY HH24:MI:SS"

# Construindo o Script de Backup RMAN:
echo;echo 
echo Por favor, insira o local do backup: [exemplo: /backup/DB]
echo "================================"
while read BKPLOC1
	do
		/bin/mkdir -p ${BKPLOC1}/RMANBKP_${ORACLE_SID}/`date '+%F'`
		BKPLOC=${BKPLOC1}/RMANBKP_${ORACLE_SID}/`date '+%F'`

		if [ ! -d "${BKPLOC}" ]; then
        	 echo "O local de backup fornecido NÃO existe ou não é gravável!"
		 echo 
	         echo "Por favor, forneça um local de backup VÁLIDO:"
		 echo "--------------------------------------"
		else
		 break
        	fi
	done
echo
echo "O local do backup é: ${BKPLOC1}"
echo
echo "Quantos CANAIS você deseja alocar para este backup? [${CPU_NUM} CPUs disponíveis nesta máquina]"
echo "========================================================="
while read CHANNEL_NUM
	do
		integ='^[0-9]+$'
		if ! [[ ${CHANNEL_NUM} =~ $integ ]] ; then
   			echo "Erro: Não é um número válido!"
			echo
			echo "Por favor, insira um NÚMERO VÁLIDO:"
			echo "---------------------------"
		else
			break
		fi
	done
echo
echo "Número de Canais é: ${CHANNEL_NUM}"
echo
echo "---------------------------------------------"
echo "O BACKUP COMPACTADO alocará MENOS espaço"
echo "mas é um pouco mais LENTO que o BACKUP REGULAR."
echo "---------------------------------------------"
echo
echo "Você deseja um BACKUP COMPACTADO? [S|N]: [S]"
echo "================================"
while read COMPRESSED
	do
		case $COMPRESSED in  
		  ""|s|S|sim|SIM|Sim) COMPRESSED=" AS COMPRESSED BACKUPSET "; echo "BACKUP COMPACTADO HABILITADO.";break ;; 
		  n|N|não|NÃO|Não) COMPRESSED="";break ;; 
		  *) echo "Por favor, insira uma resposta VÁLIDA [S|N]" ;;
		esac
	done

echo
echo "Você deseja CRIPTOGRAFAR o BACKUP com senha? [Disponível apenas na edição Enterprise] [S|N]: [N]"
echo "=============================================="
while read ENCR_BY_PASS_ANS
        do
                case ${ENCR_BY_PASS_ANS} in
                  s|S|sim|SIM|Sim)
		  echo
		  echo "Por favor, insira a senha que será usada para criptografar o backup:"
		  echo "-----------------------------------------------------------------"
		  read ENCR_PASS
		  ENCR_BY_PASS="SET ENCRYPTION ON IDENTIFIED BY '${ENCR_PASS}' ONLY;"
		  export ENCR_BY_PASS
		  echo
		  echo "CRIPTOGRAFIA DE BACKUP HABILITADA."
		  echo
		  echo "Posteriormente, para RESTAURAR este backup, use o seguinte comando para DESCRIPTOGRAFÁ-LO, colocando-o antes do comando RESTORE:"
		  echo "  exemplo:"
		  echo "  SET DECRYPTION IDENTIFIED BY '${ENCR_PASS}';"
		  echo "  restore database ...."
		  echo
		  break ;;
                  ""|n|N|não|NÃO|Não) ENCR_BY_PASS="";break ;;
                  *) echo "Por favor, insira uma resposta VÁLIDA [S|N]" ;;
                esac
        done

RMANSCRIPT=${BKPLOC}/RMAN_FULL_${ORACLE_SID}.rman
RMANSCRIPTRUNNER=${BKPLOC}/RMAN_FULL_nohup.sh
RMANLOG=${BKPLOC}/rmanlog.`date '+%a'`

echo "${ENCR_BY_PASS}"      > ${RMANSCRIPT}
echo "run {" 		   >> ${RMANSCRIPT}
CN=1
while [[ ${CN} -le ${CHANNEL_NUM} ]]
do
echo "allocate channel C${CN} type disk;" >> ${RMANSCRIPT}
    ((CN = CN + 1))
done
echo "CHANGE ARCHIVELOG ALL CROSSCHECK;" >> ${RMANSCRIPT}
#echo "DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;" >> ${RMANSCRIPT}
echo "BACKUP ${COMPRESSED} INCREMENTAL LEVEL=0 FORMAT '${BKPLOC}/%d_%I_%t_%s_%p' TAG='FULLBKP'" >> ${RMANSCRIPT}
echo "FILESPERSET 100 DATABASE include current controlfile PLUS ARCHIVELOG;" >> ${RMANSCRIPT}
#echo "BACKUP FORMAT '${BKPLOC}/%d_%t_%s_%p.ctl' TAG='CONTROL_BKP' CURRENT CONTROLFILE;" >> ${RMANSCRIPT}
echo "BACKUP ${COMPRESSED} FORMAT '${BKPLOC}/CONTROLFILE_%d_%I_%t_%s_%p.bkp' REUSE TAG='CONTROL_BKP' CURRENT CONTROLFILE;" >> ${RMANSCRIPT}
echo "SQL \"ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS ''${BKPLOC}/controlfile.trc'' REUSE\";" >> ${RMANSCRIPT}
echo "SQL \"CREATE PFILE=''${BKPLOC}/init${ORACLE_SID}.ora'' FROM SPFILE\";" >> ${RMANSCRIPT}
echo "}" >> ${RMANSCRIPT}
echo "SCRIPT DE BACKUP RMAN CRIADO."
echo 
sleep 1
echo "O local do backup é: ${BKPLOC}"
echo
sleep 1
echo "Iniciando o trabalho de backup RMAN ..."
echo
sleep 1
echo "#!/bin/bash" > ${RMANSCRIPTRUNNER}
echo "nohup ${ORACLE_HOME}/bin/rman target / cmdfile=${RMANSCRIPT} | tee ${RMANLOG}  2>&1 &" >> ${RMANSCRIPTRUNNER}
chmod 740 ${RMANSCRIPTRUNNER}
source ${RMANSCRIPTRUNNER}
echo
echo " O trabalho de backup RMAN está sendo executado em segundo plano. Desconectar a sessão atual NÃO interromperá o trabalho de backup :-)"
echo " Agora, visualizando o log do trabalho de backup:"
echo
echo "O local do backup é: ${BKPLOC}"
echo "Verifique o ARQUIVO DE LOG: ${RMANLOG}"
echo

# #############
# FIM DO SCRIPT
# #############
# RELATE BUGS para: <mahmmoudadel@hotmail.com>.
# AVISO LEGAL: ESTE SCRIPT É DISTRIBUÍDO NA ESPERANÇA DE QUE SEJA ÚTIL, MAS SEM QUALQUER GARANTIA. ELE É FORNECIDO "COMO ESTÁ".
# BAIXE A VERSÃO MAIS RECENTE DO PACOTE DE ADMINISTRAÇÃO DE BANCO DE DADOS EM: 
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
