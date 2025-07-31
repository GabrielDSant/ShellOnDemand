# ##############################################################################################
# Script para ser usado no crontab para agendar um Backup Completo com RMAN
VER="[1.1]"
# ##############################################################################################
#                                       #   #     #
# Autor:        Mahmmoud ADEL         # # # #   ###
# Criado:       04-10-17            #   #   # #   #  
#
# Modificado:
#
#
#
# ##############################################################################################

# ##############################################################
# VARIÁVEIS a serem modificadas pelo usuário para adequar ao ambiente:
# ##############################################################

# Nome da INSTÂNCIA: [Substitua ${ORACLE_SID} pelo SID da sua instância]
ORACLE_SID=${ORACLE_SID}

# Localização do ORACLE_HOME: [Substitua ${ORACLE_HOME} pelo caminho correto do ORACLE_HOME]
ORACLE_HOME=${ORACLE_HOME}

# Localização do Backup: [Substitua /backup/rmanfull pelo caminho do local de backup]
BACKUPLOC=/backup/rmanfull

# Opção de BACKUP COMPACTADO: [Y|N] [Padrão HABILITADO]
COMPRESSION=Y

# Realizar Manutenção: [Y|N] [Padrão HABILITADO]
MAINTENANCEFLAG=Y

# Retenção do Backup "Em Dias": [Backups mais antigos que esta retenção serão excluídos]
BKP_RETENTION=7

# Retenção de Arquivos de Log "Em Dias": [Arquivos de log arquivados mais antigos que esta retenção serão excluídos]
ARCH_RETENTION=7

# ##################
# VARIÁVEIS GENÉRICAS: [Podem ser deixadas sem modificação]
# ##################

# Tamanho Máximo da Peça de Backup: [Deve ser MAIOR que o tamanho do maior datafile no banco de dados]
MAX_BKP_PIECE_SIZE=33g

# Localização do LOG do Backup:
RMANLOG=${BACKUPLOC}/rmanfull.log

# Mostrar os detalhes completos de DATA e HORA no log do backup:
NLS_DATE_FORMAT='DD-Mon-YYYY HH24:MI:SS'

export ORACLE_SID
export ORACLE_HOME
export BACKUPLOC
export COMPRESSION
export BKP_RETENTION
export ARCH_RETENTION
export MAX_BKP_PIECE_SIZE
export RMANLOG
export NLS_DATE_FORMAT
export MAINTENANCEFLAG

# Verificar a opção de COMPACTAÇÃO selecionada:
	case ${COMPRESSION} in
	Y|y|YES|Yes|yes|ON|on)
	COMPRESSED_BKP="AS COMPRESSED BACKUPSET"
	export COMPRESSED_BKP
	*)
	COMPRESSED_BKP=""
	export COMPRESSED_BKP
	esac

# Verificar a opção de MANUTENÇÃO selecionada:
        case ${MAINTENANCEFLAG} in
        Y|y|YES|Yes|yes|ON|on)
        HASH_MAINT=""
        export HASH_MAINT
        *)
        HASH_MAINT="#"
        export COMPRESSED_BKP
        esac

# Adicionar a data ao log do backup para cada execução do script:
echo "----------------------------" >> ${RMANLOG}
date                                >> ${RMANLOG}
echo "----------------------------" >> ${RMANLOG}

# ###################
# Seção do Script RMAN:
# ###################

${ORACLE_HOME}/bin/rman target /  msglog=${RMANLOG} append | tee ${RMANLOG}.tee <<EOF
# Seção de Configuração:
# ---------------------
${HASH_MAINT}CONFIGURE BACKUP OPTIMIZATION ON;
${HASH_MAINT}CONFIGURE CONTROLFILE AUTOBACKUP ON;
${HASH_MAINT}CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '${BACKUPLOC}/%F';
${HASH_MAINT}CONFIGURE SNAPSHOT CONTROLFILE NAME TO '${ORACLE_HOME}/dbs/snapcf_${ORACLE_SID}.f';
## Evitar excluir arquivos de log arquivados que ainda não foram aplicados no standby: [Quando FORCE não é usado]
#CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;

# Seção de Manutenção:
# -------------------
## Verificar backups/cópias para identificar backups expirados que não estão fisicamente disponíveis no meio:
${HASH_MAINT}crosscheck backup completed before 'sysdate-${BKP_RETENTION}' device type disk;
${HASH_MAINT}crosscheck copy completed   before 'sysdate-${BKP_RETENTION}' device type disk;
## Relatar e excluir backups obsoletos que não atendem à política de retenção:
${HASH_MAINT}REPORT OBSOLETE RECOVERY WINDOW OF ${BKP_RETENTION} DAYS device type disk;
${HASH_MAINT}DELETE NOPROMPT OBSOLETE RECOVERY WINDOW OF ${BKP_RETENTION} DAYS device type disk;
## Excluir todos os backups/cópias expirados que não estão fisicamente disponíveis:
${HASH_MAINT}DELETE NOPROMPT EXPIRED BACKUP COMPLETED BEFORE 'sysdate-${BKP_RETENTION}' device type disk;
${HASH_MAINT}DELETE NOPROMPT EXPIRED COPY   COMPLETED BEFORE 'sysdate-${BKP_RETENTION}' device type disk;
## Verificar arquivos de log arquivados para evitar falha no backup:
${HASH_MAINT}CHANGE ARCHIVELOG ALL CROSSCHECK;
${HASH_MAINT}DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
## Excluir arquivos de log arquivados mais antigos que o período de retenção:
${HASH_MAINT}DELETE NOPROMPT archivelog all completed before 'sysdate -${ARCH_RETENTION}';

# O script de Backup Completo começa aqui: [Compactado+Controlfile+Arquivos de Log]
# ------------------------------
run{
allocate channel F1 type disk;
allocate channel F2 type disk;
allocate channel F3 type disk;
allocate channel F4 type disk;
sql 'alter system archive log current';
BACKUP ${COMPRESSED_BKP}
MAXSETSIZE ${MAX_BKP_PIECE_SIZE}
NOT BACKED UP SINCE TIME 'SYSDATE-2/24'
INCREMENTAL LEVEL=0
FORMAT '${BACKUPLOC}/%d_%t_%s_%p.bkp' 
FILESPERSET 100
TAG='FULLBKP'
DATABASE include current controlfile PLUS ARCHIVELOG NOT BACKED UP SINCE TIME 'SYSDATE-2/24';
## Backup do controlfile separadamente:
BACKUP ${COMPRESSED_BKP} CURRENT CONTROLFILE FORMAT '${BACKUPLOC}/CONTROLFILE_%d_%I_%t_%s_%p.bkp' TAG='CONTROLFILE_BKP' REUSE ;
## Backup de controle e SPFILE em trace:
SQL "ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS ''${BACKUPLOC}/controlfile.trc'' REUSE";
SQL "CREATE PFILE=''${BACKUPLOC}/init${ORACLE_SID}.ora'' FROM SPFILE";
}
EOF

# Este script é usado para agendar backups completos do banco de dados Oracle usando o RMAN. Ele inclui opções para compactação, manutenção de backups antigos e exclusão de arquivos de log arquivados antigos. O script é configurado para ser executado automaticamente via crontab.

