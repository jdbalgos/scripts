#!/bin/bash
#The script was only tested on a CentOS machine, additional changes will be done in the future
#This is a deployment script for making a backup schedule every X days, the database data retention will be the latest X backups(depends on user preference in NUMBER_OF_BACKUPS), older backups will be deleted by the script 
#NOTE: Please make the script file only executable and accessible by the user, sample: chmod 700 dir_backup_deploy.sh

#NEEDED variables in order to run
BACKUP_NAME=
BACKUP_DIR=
if [[ ${BACKUP_DIR} == '' || ${BACKUP_NAME} == '']]
then
  echo "one of the needed variables is/are missing" 
  exit 1
fi
#If you want to ignore folders you need to add the filepath inside the parenthesis, NO COMMA(,) sample: IGNORE_DIRS=("/test1/ignore1" "/test1/.ignore2")
IGNORE_DIRS=()
# additional variables, can be change according to preference
#default backup directory where the script will dump the sql backup files, change if needed
BACKUP_OUT_DIR=/backup
#default directory for backup_scripts, change if needed
BACKUP_SCRIPTS_DIR=/opt/backup_scripts
# change to needed crontab spool file if needed
CRONTAB_SPOOL_FILE=/var/spool/cron/root
#default number of backups are 5, change if needed
NUMBER_OF_BACKUPS=5
#default number of times the script will run in crontab  * * * * * format, current setup is every week
CRONTAB="0 0 * * 0"

if ! command -v tar > /dev/null
then
  echo "tar client is not yet installed please install it!"
  echo "this script will try to install mysql client, please press Ctrl+C if you want it to install it yourselves"
  sleep 5
  dnf install -y tar
fi
if ! command -v gzip > /dev/null
then
  echo "gzip client is not yet installed please install it!"
  echo "this script will try to install mysql client, please press Ctrl+C if you want it to install it yourselves"
  sleep 5
  dnf install -y gzip
fi

BACKUP_SCRIPTS_DIR=`echo ${BACKUP_SCRIPTS_DIR} | sed 's|/$||'`
BACKUP_OUT_DIR=`echo ${BACKUP_OUT_DIR} | sed 's|/$||'`
NUMBER_OF_BACKUPS=$(( ${NUMBER_OF_BACKUPS} + 1))
EXCLUDE_DIRS=""
for DIRS in ${IGNORE_DIRS[@]}; do
  EXCLUDE_DIRS=`echo ${EXCLUDE_DIRS} --exclude \"${DIRS}\"`
done

if ! [[ -d ${BACKUP_SCRIPTS_DIR} ]]
then 
  echo "${BACKUP_SCRIPTS_DIR} directory does not exist"
  mkdir -p ${BACKUP_SCRIPTS_DIR}
fi
if ! [[ -d ${BACKUP_OUT_DIR} ]]
then 
  echo "${BACKUP_OUT_DIR} directory does not exist"
  mkdir -p ${BACKUP_OUT_DIR}
fi

if [[ $BACKUP_NAME = '' ]]; then
  BACKUP_NAME=`echo ${BACKUP_DIR} | sed 's|/||'`
  BACKUP_SCRIPT_FILEPATH=`echo ${BACKUP_SCRIPTS_DIR}/${BACKUP_NAME}_backup.sh`
else
  BACKUP_SCRIPT_FILEPATH=`echo ${BACKUP_SCRIPTS_DIR}/${BACKUP_NAME}_backup.sh`
fi

cat << EOF >${BACKUP_SCRIPT_FILEPATH}
BACKUP_FILE=${BACKUP_OUT_DIR}/${BACKUP_NAME}_\`date +%s\`.tgz
tar ${EXCLUDE_DIRS} -zcf \${BACKUP_FILE} ${BACKUP_DIR}
if [[ \$? -ne 0  ]]; then
  echo "\`date +%c failed to do backup\`"
else
  echo "successfully backup in: \${BACKUP_FILE}"
fi
find ${BACKUP_OUT_DIR} -name "${BACKUP_NAME}_*.tgz" | tac | tail -n +${NUMBER_OF_BACKUPS} | xargs rm -f
echo "Total number of backup file: \`find ${BACKUP_OUT_DIR} -name "${BACKUP_NAME}_*.tgz" | wc -l\`"
EOF

if ! [[ -f ${BACKUP_SCRIPT_FILEPATH} ]]; then
  echo "failed to create the backup script file, please check permissions"
  exit 1
else
  echo "created the backup script: ${BACKUP_SCRIPT_FILEPATH}"
fi

chmod 700 ${BACKUP_SCRIPT_FILEPATH}
echo "This script will try to run: ${BACKUP_SCRIPT_FILEPATH}"
bash ${BACKUP_SCRIPT_FILEPATH}


echo "trying to add the script to crontab" 
if [[ -f ${CRONTAB_SPOOL_FILE} ]]; then
  sed -i "/${BACKUP_NAME}_backup.sh/d" ${CRONTAB_SPOOL_FILE}
fi
echo "${CRONTAB} /bin/bash ${BACKUP_SCRIPT_FILEPATH} &> /dev/null"  >> ${CRONTAB_SPOOL_FILE}

exit 0
