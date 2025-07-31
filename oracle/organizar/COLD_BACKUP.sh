# #################################################
# Script de Backup COLD do Banco de Dados.
#                                       #   #     #
# Autor:        Mahmmoud ADEL         # # # #   ###
# Criado:       22-12-13            #   #   # #   #  
#
# Modificado:   16-05-14 Aumentado o tamanho da linha
#               para evitar quebra de linha.
#
# #################################################

# #################################################
# Este script realiza um backup COLD de um banco de dados Oracle.
# Ele verifica as instâncias disponíveis, permite ao usuário selecionar
# uma instância, valida o ambiente, cria scripts de backup e restauração,
# e executa o backup. O backup é feito enquanto o banco de dados está desligado.
# #################################################

# ###########
# Descrição:
# ###########
echo
echo "==============================================="
echo "Este script realiza um BACKUP COLD de um banco de dados."
echo "==============================================="
echo
sleep 1


# #######################################
# Instâncias Excluídas:
# #######################################
# Aqui você pode mencionar as instâncias que o script irá IGNORAR e NÃO será executado:
# Use o caractere pipe "|" como separador entre os nomes das instâncias.
# Exemplo de exclusão: -MGMTDB, instâncias ASM:

EXL_DB="\-MGMTDB|ASM"                           # Instâncias Excluídas [Não serão reportadas como offline].

# ###########################
# Listando Bancos de Dados Disponíveis:
# ###########################

# Contar o Número de Instâncias:
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
	  echo
	  echo "********"
          echo $DB_ID
          echo "********"
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
          echo "Script Terminado!"
          exit
        fi

# Neutralizar o arquivo login.sql:
# #########################
# A existência do arquivo login.sql no diretório de trabalho atual elimina muitas funções durante a execução deste script:

        if [ -f ./login.sql ]
         then
mv ./login.sql   ./login.sql_NeutralizedBy${SCRIPT_NAME}
        fi

# ################################
# Criando Script de Backup e Restauração:
# ################################
echo 
echo "Digite o local do Backup: [Caminho Completo]"
echo "-------------------------"
while read LOC1
        do
                EXTEN=${ORACLE_SID}_`date '+%F'`
                LOC2=${LOC1}/COLDBACKUP_${EXTEN}
                /bin/mkdir -p ${LOC2}

                if [ ! -d "${LOC2}" ]; then
                 echo "O local de backup fornecido NÃO existe ou não é gravável!"
                 echo
                 echo "Por favor, forneça um local de backup VÁLIDO:"
		 echo "---------------------------------------"
                else
                 echo
                 sleep 1
                 echo "Local de Backup Validado."
                 echo
                 break
                fi
        done
BKPSCRIPT=${LOC2}/Cold_Backup.sh
RSTSCRIPT=${LOC2}/Restore_Cold_Backup.sh
BKPSCRIPTLOG=${LOC2}/Cold_Backup.log
RSTSCRIPTLOG=${LOC2}/Restore_Cold_Backup.log

# Criando o script de Backup Cold:
echo
echo "Criando Scripts de Backup Cold e Restauração Cold ..."
sleep 1
cd ${LOC2}
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 
set termout off echo off feedback off linesize 400;
spool Cold_Backup.sh
PROMPT echo "Desligando o Banco de Dados $ORACLE_SID ... [Ctrl+c para CANCELAR]"
PROMPT echo "[5]"
PROMPT sleep 1
PROMPT echo "[4]"
PROMPT sleep 1
PROMPT echo "[3]"
PROMPT sleep 1
PROMPT echo "[2]"
PROMPT sleep 1
PROMPT echo "[1]"
PROMPT sleep 1
PROMPT echo "DESLIGANDO AGORA ..."
PROMPT sleep 3
PROMPT echo ""
PROMPT ${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
PROMPT shutdown immediate;
PROMPT EOF
PROMPT echo "Banco de Dados DESLIGADO COM SUCESSO."
PROMPT sleep 1
PROMPT echo
PROMPT echo "Iniciando cópia dos ARQUIVOS do BD ..."
PROMPT echo
PROMPT echo "************************"
PROMPT echo "NÃO FECHE ESTA SESSÃO. Assim que o TRABALHO DE BACKUP for CONCLUÍDO, você será retornado ao PROMPT."
PROMPT echo "************************"
PROMPT echo
PROMPT sleep 1
PROMPT
PROMPT echo -ne '...'
select 'cp -vpf '||name||' $LOC2 ; echo ' ||'-ne '''||'...''' from v\$controlfile
union
select 'cp -vpf '||name||' $LOC2 ; echo ' ||'-ne '''||'...''' from v\$datafile
union
select 'cp -vpf '||member||' $LOC2 ; echo ' ||'-ne '''||'...''' from v\$logfile;
PROMPT touch $LOC2/verifier.log
PROMPT echo

spool off
EOF
chmod 700 ${BKPSCRIPT}
# Criando o Script de Restauração:
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 termout off echo off feedback off linesize 400;
spool Restore_Cold_Backup.sh
PROMPT echo ""
PROMPT echo "Restaurando o Banco de Dados $ORACLE_SID do Backup Cold [${EXTEN}] ..."
PROMPT sleep 1
PROMPT echo ""
PROMPT echo "VOCÊ TEM CERTEZA QUE DESEJA RESTAURAR O BANCO DE DADOS [${ORACLE_SID}]? [Y|N] [N]"
PROMPT while read ANS
PROMPT  do
PROMPT          case \$ANS in
PROMPT                  y|Y|yes|YES|Yes) echo "TRABALHO DE RESTAURAÇÃO INICIADO ...";break ;;;
PROMPT                  ""|n|N|no|NO|No) echo "Script Terminado.";exit;break ;;;
PROMPT                  *) echo "Por favor, insira uma resposta VÁLIDA [Y|N]" ;;;
PROMPT          esac
PROMPT  done
PROMPT ORACLE_SID=${ORACLE_SID}
PROMPT export ORACLE_SID
PROMPT echo "Desligando o Banco de Dados ${ORACLE_SID} ... [Ctrl+c para CANCELAR]"
PROMPT echo "[5]"
PROMPT sleep 1
PROMPT echo "[4]"
PROMPT sleep 1
PROMPT echo "[3]"
PROMPT sleep 1
PROMPT echo "[2]"
PROMPT sleep 1
PROMPT echo "[1]"
PROMPT sleep 1
PROMPT echo "DESLIGANDO AGORA ..."
PROMPT sleep 3
PROMPT echo ""
PROMPT ${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
PROMPT shutdown immediate;
PROMPT EOF
PROMPT 
PROMPT echo "Trabalho de Restauração Iniciado ..."
PROMPT echo ""
PROMPT echo -ne '...'
select 'cp -vpf $LOC2/'||SUBSTR(name, INSTR(name,'/', -1,1)+1)||'  '||name||' ; echo ' ||'-ne '''||'...''' from v\$controlfile
union
select 'cp -vpf $LOC2/'||SUBSTR(name, INSTR(name,'/', -1,1)+1)||'  '||name||' ; echo ' ||'-ne '''||'...''' from v\$datafile
union
select 'cp -vpf $LOC2/'||SUBSTR(member, INSTR(member,'/', -1,1)+1)||'  '||member||' ; echo ' ||'-ne '''||'...''' from v\$logfile;
PROMPT echo
PROMPT ${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
PROMPT startup
PROMPT PROMPT
PROMPT PROMPT Adicionando TEMPFILES AOS TABLESPACES TEMPORÁRIOS...
select 'ALTER DATABASE TEMPFILE '''||file_name||''' DROP;' from dba_temp_files;
select 'ALTER TABLESPACE '||tablespace_name||' ADD TEMPFILE '''||file_name||''' REUSE;' from dba_temp_files;
PROMPT EOF
PROMPT VAL1=\$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
PROMPT set heading off echo off feedback off termout off
PROMPT select status from v\\\$instance;;
PROMPT EOF
PROMPT )
PROMPT VAL2=\`echo \$VAL1 | perl -lpe'\$_ = reverse' |awk '{print \$1}'|perl -lpe'\$_ = reverse'\`
PROMPT case \${VAL2} in "OPEN")
PROMPT echo "******************************************************"
PROMPT echo "Banco de Dados [$ORACLE_SID] foi Restaurado com Sucesso."
PROMPT echo "Banco de Dados [$ORACLE_SID] está ATIVO."
PROMPT echo "******************************************************"
PROMPT echo 
PROMPT echo ;;;
PROMPT *)
PROMPT echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
PROMPT echo "Banco de Dados [$ORACLE_SID] NÃO PODE SER ABERTO!"
PROMPT echo "Por favor, verifique o ALERTLOG e investigue."
PROMPT echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
PROMPT echo 
PROMPT echo ;;;
PROMPT esac
spool off
EOF

chmod 700 ${RSTSCRIPT}

        if [ ! -f "${BKPSCRIPT}" ]; then
          echo ""
          echo "Os Scripts de Backup e Restauração NÃO puderam ser Criados."
          echo "O Script Falhou ao Criar o trabalho de Backup Cold!"
          echo "Por favor, verifique as permissões do Local de Backup."
          exit
        fi

echo
echo "--------------------------------------------------------"
echo "Os Scripts de Backup e Restauração foram Criados com Sucesso."
echo "--------------------------------------------------------"
echo
echo
sleep 1

# ############################
# Executando o Script de Backup Cold:
# ############################
# Verificando se mais de uma instância está em execução: [RAC]
echo "Verificando Outras instâncias ABERTAS [RAC]."
sleep 1
VAL3=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set heading off echo off feedback off termout off
select count(*) from gv\$instance;
EOF
)
VAL4=`echo $VAL3 | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
                if [ ${VAL4} -gt 1 ]
                 then
                  echo
                  echo "AVISO:"
                  echo "-------"
                  echo "Por favor, DESLIGUE TODAS as outras INSTÂNCIAS RAC, EXCETO a que está no NÓ ATUAL."
                  echo "Em seguida, execute novamente o script COLD_BACKUP.sh."
                  echo ""
                  exit
                fi
echo
echo "VERIFICADO: Apenas UMA INSTÂNCIA está em execução para o Banco de Dados [${ORACLE_SID}]."
echo
sleep 1
echo "VOCÊ TEM CERTEZA QUE DESEJA DESLIGAR O BANCO DE DADOS [${ORACLE_SID}] E INICIAR O TRABALHO DE BACKUP COLD? [Y|N] [N]"
while read ANS
 do
         case $ANS in
                 y|Y|yes|YES|Yes) echo;echo "PROCEDIMENTO DE BACKUP COLD INICIADO ...";break ;;
                 ""|n|N|no|NO|No) echo;echo "Script Terminado.";exit;break ;;
                 *) echo "Por favor, insira uma resposta VÁLIDA [Y|N]" ;;
         esac
 done
echo
echo "O Banco de Dados [${ORACLE_SID}] será DESLIGADO em [5 Segundos] ... [Para CANCELAR pressione [Ctrl+c]]"
echo "[5]"
sleep 1
echo "[4]"
sleep 1
echo "[3]"
sleep 1
echo "[2]"
sleep 1
echo "[1]"
sleep 1
echo ""
echo "Desligando o Banco de Dados [${ORACLE_SID}] ..."
echo "Os Arquivos de Backup serão Copiados para: [${LOC2}] ..."
echo
sleep 1
exec ${BKPSCRIPT} |tee  ${BKPSCRIPTLOG}

 VAL11=$LOC2/verifier.log
 if [ ! -f ${VAL11} ]
  then
   echo 
   echo "xxxxxxxxxxxxxxxxxxx"
   echo "Trabalho de Backup Falhou!"
   echo "xxxxxxxxxxxxxxxxxxx"
   echo
  else
   echo
   echo "Backup Cold do Banco de Dados CONCLUÍDO."
   echo "Por favor, observe que os ARQUIVOS TEMPORAIS não estão incluídos neste Backup."
   echo
   echo "****************************************************************"
   echo "Os arquivos de BACKUP COLD estão localizados em: ${LOC2}"
   echo "****************************************************************"
   echo
   echo "****************************************************************"
   echo "Posteriormente, para restaurar o banco de dados ${DB_ID} a partir deste BACKUP COLD,"
   echo "use este script para realizar o trabalho automaticamente:"
   echo "${RSTSCRIPT}"
   echo "****************************************************************"
 fi

rm -f ${VAL11}
echo
echo "Você deseja INICIAR o Banco de Dados [${ORACLE_SID}]? [Y|N] [Y]"
echo "==========================================="
while read ANS
 do
         case $ANS in
                 ""|y|Y|yes|YES|Yes) echo "INICIANDO O BANCO DE DADOS [${ORACLE_SID}] ..."
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
STARTUP
EOF
echo
break ;;
                 n|N|no|NO|No) echo;echo "Script CONCLUÍDO."
echo "Para restaurar este banco de dados a partir do BACKUP COLD, execute o Script: [${RSTSCRIPT}]"
exit
break ;;
                 *) echo "Por favor, insira uma resposta VÁLIDA [Y|N]" ;;
         esac
 done

# Desneutralizar o arquivo login.sql:
# ############################
# Se o login.sql foi renomeado durante a execução do script, revertê-lo para o nome original:
        if [ -f ./login.sql_NeutralizedBy${SCRIPT_NAME} ]
         then
mv ./login.sql_NeutralizedBy${SCRIPT_NAME}  ./login.sql
        fi

# #############
# FIM DO SCRIPT
# #############
# RELATE BUGS para: <mahmmoudadel@hotmail.com>.
# AVISO LEGAL: ESTE SCRIPT É DISTRIBUÍDO NA ESPERANÇA DE QUE SEJA ÚTIL, MAS SEM QUALQUER GARANTIA. ELE É FORNECIDO "COMO ESTÁ".
# BAIXE A VERSÃO MAIS RECENTE DO PACOTE DE ADMINISTRAÇÃO DE BANCO DE DADOS EM: 
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
