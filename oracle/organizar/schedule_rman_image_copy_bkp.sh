# ##############################################################################################
# Script para ser usado no crontab para agendar um backup RMAN Image/Copy
VER="[1.1]"
# ##############################################################################################
#                                       #   #     #
# Autor:        Mahmmoud ADEL         # # # #   ###
# Criado:       01-10-17            #   #   # #   #  
#
# Modificado:   02-10-17
#
#
#
# ##############################################################################################

# Este script realiza backups do banco de dados Oracle usando RMAN no formato Image/Copy.
# Ele também configura políticas de retenção, realiza manutenção de backups antigos e cria backups incrementais.
# O script é projetado para ser executado periodicamente via crontab.

# Seção de VARIÁVEIS: [Deve ser modificada para cada ambiente]
# #################

# Local do Backup: [Substitua /backup/rmancopy pelo caminho correto do local de backup]
export BACKUPLOC=/backup/rmancopy

# Retenção do Backup "Em Dias": [Backups mais antigos que essa retenção serão excluídos]
export BKP_RETENTION=7

# Retenção de Archives "Em Dias": [Archivelogs mais antigos que essa retenção serão excluídos]
export ARCH_RETENTION=7

# Nome da INSTÂNCIA: [Substitua ${ORACLE_SID} pelo SID da sua instância]
export ORACLE_SID=${ORACLE_SID}

# Local do ORACLE_HOME: [Substitua ${ORACLE_HOME} pelo caminho correto do ORACLE_HOME]
export ORACLE_HOME=${ORACLE_HOME}

# Local do LOG do Backup:
export RMANLOG=${BACKUPLOC}/rmancopy.log

# Mostrar os detalhes completos de DATA e HORA no log do backup:
export NLS_DATE_FORMAT='DD-Mon-YYYY HH24:MI:SS'

# Adicionar a data ao log do backup para cada execução do script:
echo "----------------------------" >> ${RMANLOG}
date                                >> ${RMANLOG}
echo "----------------------------" >> ${RMANLOG}

# ###################
# Seção do SCRIPT RMAN:
# ###################
${ORACLE_HOME}/bin/rman target /  msglog=${RMANLOG} append <<EOF
# Seção de Configuração:
# ---------------------
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
#CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '${BACKUPLOC}/%F';
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '${ORACLE_HOME}/dbs/snapcf_${ORACLE_SID}.f';
## Evitar excluir archivelogs que ainda não foram aplicados no standby: [Quando FORCE não é usado]
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;

# Seção de Manutenção:
# -------------------
## Verificar backups/cópias para identificar backups expirados que não estão fisicamente disponíveis na mídia:
#crosscheck backup completed before 'sysdate-${BKP_RETENTION}' device type disk;
#crosscheck copy completed   before 'sysdate-${BKP_RETENTION}' device type disk;
## Relatar e excluir backups obsoletos que não atendem à POLÍTICA DE RETENÇÃO:
#report obsolete RECOVERY WINDOW OF ${BKP_RETENTION} DAYS device type disk;
#DELETE NOPROMPT OBSOLETE RECOVERY WINDOW OF ${BKP_RETENTION} DAYS device type disk;
## Excluir todos os backups/cópias EXPIRADOS que não estão fisicamente disponíveis:
#DELETE NOPROMPT EXPIRED BACKUP COMPLETED BEFORE 'sysdate-${BKP_RETENTION}' device type disk;
#DELETE NOPROMPT EXPIRED COPY   COMPLETED BEFORE 'sysdate-${BKP_RETENTION}' device type disk;
## Verificar Archivelogs para evitar falha no backup:
#CHANGE ARCHIVELOG ALL CROSSCHECK;
#DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
## Excluir Archivelogs mais antigos que o número de dias definido em ARCH_RETENTION:
#DELETE NOPROMPT archivelog all completed before 'sysdate -${ARCH_RETENTION}';

# O script de backup Image Copy começa aqui: [Criar Image Copy e recuperá-lo]
# -------------------------------------
run{
allocate channel F1 type disk format '${BACKUPLOC}/%U';
allocate channel F2 type disk format '${BACKUPLOC}/%U';
allocate channel F3 type disk format '${BACKUPLOC}/%U';
allocate channel F4 type disk format '${BACKUPLOC}/%U';
BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 1 FOR RECOVER OF COPY WITH TAG 'DB_COPY_UPDTD_BKP'
DATABASE FORMAT '${BACKUPLOC}/%d_%t_%s_%p';						# Backup incremental nível 1 para recuperar a Image COPY.
RECOVER COPY OF DATABASE WITH TAG 'DB_COPY_UPDTD_BKP';					# Recuperar Image Copy com o backup incremental nível 1.
DELETE noprompt backup TAG 'DB_COPY_UPDTD_BKP';						# Excluir [apenas] o backup incremental usado para recuperação.
#DELETE noprompt backup TAG 'arc_for_image_recovery' completed before 'sysdate-1';	# Excluir backup de Archive para a recuperação anterior.
DELETE noprompt copy   TAG 'ctrl_after_image_reco';					# Excluir backup do Controlfile da execução anterior.
#sql 'alter system archive log current';
#BACKUP as compressed backupset archivelog from time not backed up 1 times
#format '${BACKUPLOC}/arc_%d_%t_%s_%p' tag 'arc_for_image_recovery';				# Backup de Archivelogs após a Image Copy.
BACKUP as copy current controlfile format '${BACKUPLOC}/ctl_%U' tag 'ctrl_after_image_reco';	# Backup do Controlfile como cópia.
sql "ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS ''${BACKUPLOC}/controlfile.trc'' reuse";	# Backup do Controlfile como trace.
sql "create pfile=''${BACKUPLOC}/init${ORACLE_SID}.ora'' from spfile";				# Backup do SPFILE.
}
EOF

