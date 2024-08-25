#!/bin/bash
#The script was only tested on a CentOS machine, additional changes will be done in the future
#This is a deployment script for making a backup schedule every X days, the database data retention will be the latest X backups(depends on user preference in NUMBER_OF_BACKUPS), older backups will be deleted by the script 
#NOTE: Please make the script file only executable and accessible by the user, sample: chmod 700 db_backup_deploy.sh

#NEEDED variables in order to run
BACKUP_NAME=
SQL_HOST=
SQL_PORT=
SQL_DB_NAME=
SQL_USER=
SQL_PASS=

if [[ ${SQL_HOST} == '' ]] || \
   [[ ${SQL_PORT} == '' ]] || \
   [[ ${SQL_DB_NAME} == '' ]] || \
   [[ ${SQL_USER} == '' ]] || \
   [[ ${SQL_PASS} == '' ]] || \
   [[ ${BACKUP_NAME} == '' ]] 
then
  echo "one of the needed variables is/are missing" 
  exit 1
fi
# additional variables, can be change according to preference
#default backup directory where the script will dump the sql backup files, change if needed
BACKUP_DIR=/backup
#default directory for backup_scripts, change if needed
BACKUP_SCRIPTS_DIR=/opt/backup_scripts
# change to needed crontab spool file if needed
CRONTAB_SPOOL_FILE=/var/spool/cron/root
#default number of backups are 5, change if needed
NUMBER_OF_BACKUPS=5
#default number of times the script will run in crontab  * * * * * format
CRONTAB="0 0 * * *"

if ! command -v mysqldump > /dev/null
then
  echo "mysql client is not yet installed please install it!"
  echo "this script will try to install mysql client, please press Ctrl+C if you want it to install it yourselves"
  sleep 5
  yum install -y mysql 
fi

BACKUP_SCRIPTS_DIR=`echo ${BACKUP_SCRIPTS_DIR} | sed 's|/$||'`
BACKUP_DIR=`echo ${BACKUP_DIR} | sed 's|/$||'`
NUMBER_OF_BACKUPS=$(( ${NUMBER_OF_BACKUPS} + 1))
if ! [[ -d ${BACKUP_SCRIPTS_DIR} ]]
then 
  echo "${BACKUP_SCRIPTS_DIR} directory does not exist"
  mkdir -p ${BACKUP_SCRIPTS_DIR}
fi
if ! [[ -d ${BACKUP_DIR} ]]
then 
  echo "${BACKUP_DIR} directory does not exist"
  mkdir -p ${BACKUP_DIR}
fi

cat << EOF >${BACKUP_SCRIPTS_DIR}/${BACKUP_NAME}_db_backup.sh
#!/bin/bash
SQL_FILE=${BACKUP_DIR}/${BACKUP_NAME}_\`date +%s\`.sql
mysqldump --no-tablespaces -h ${SQL_HOST} -P ${SQL_PORT} -u ${SQL_USER} -p${SQL_PASS} ${SQL_DB_NAME} > \${SQL_FILE}
if [[ \$? -ne 0 ]]
then
  echo "failed to access database, quitting"
  exit 1
else
  echo "successfully backup in: \${SQL_FILE}"
fi
find ${BACKUP_DIR} -name "${BACKUP_NAME}_*.sql" | tac | tail -n +${NUMBER_OF_BACKUPS} | xargs rm -f 
echo "Total number of backup file: \`find ${BACKUP_DIR} -name "${BACKUP_NAME}_*.sql" | wc -l\`"

EOF
if ! [[ -f ${BACKUP_SCRIPTS_DIR}/${BACKUP_NAME}_db_backup.sh ]]
then
  echo "failed to create the backup script file, please check permissions"
  exit 1
else
  echo "created the backup script: ${BACKUP_SCRIPTS_DIR}/${BACKUP_NAME}_db_backup.sh"
fi

chmod 700 ${BACKUP_SCRIPTS_DIR}/${BACKUP_NAME}_db_backup.sh
echo "This script will try to run: ${BACKUP_SCRIPTS_DIR}/${BACKUP_NAME}_db_backup.sh"
bash ${BACKUP_SCRIPTS_DIR}/${BACKUP_NAME}_db_backup.sh

echo "trying to add the script to crontab" 
if [[ -f ${CRONTAB_SPOOL_FILE} ]]; then
  sed -i "/${BACKUP_NAME}_db_backup.sh/d" ${CRONTAB_SPOOL_FILE}
fi
echo "${CRONTAB} /bin/bash ${BACKUP_SCRIPTS_DIR}/${BACKUP_NAME}_db_backup.sh &> /dev/null"  >> ${CRONTAB_SPOOL_FILE}

exit 0
