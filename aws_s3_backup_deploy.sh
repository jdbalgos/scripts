#!/bin/bash
#The script was only tested on a CentOS machine, additional changes will be done in the future
#This is a deployment script for automating the process of uploading the backup file into cloud(AWS)
#DO NOT use underscore(_) on AWS_DIR_NAME a please use dash(-)
#To prevent the script from accidental deleting files in the cloud, please make the AWS
#Please make AWS_DIR_NAME unique
AWS_DIR_NAME=""
AWS_ACCESS_KEY_ID=""
AWS_SECRET_ACCESS_KEY=""
AWS_DEFAULT_REGION=""
DIR_TO_BACKUP="/backup"
if [[ ${AWS_DIR_NAME} = "" || \
      ${AWS_ACCESS_KEY_ID} = "" || \
      ${AWS_SECRET_ACCESS_KEY} = "" || \
      ${AWS_DEFAULT_REGION} = "" || \
      ${DIR_TO_BACKUP} = "" ]]; then
  echo "one of the needed variables is/are missing"; exit 1
fi
#Additional configurations, leave it as it is but you can change if necessary
#default location of the backup script that will be deployed
BACKUP_SCRIPTS_DIR=/opt/backup_scripts
#CRONTAB location for root
CRONTAB_SPOOL_FILE=/var/spool/cron/root
#CRONTAB default schedule, default is everyday
CRONTAB="0 0 * * *"

if ! command -v aws &> /dev/null; then
  echo "aws command could not be found, will automatically install aws cli... Ctrl+C to quit"
  yum install -y zip unzip
  sleep 5
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  mkdir -p /tmp/awscli
  unzip /tmp/awscliv2.zip -d /tmp/awscli
  bash /tmp/awscli/aws/install
  if ! command -v aws &> /dev/null; then
    echo "aws failed to install"; exit 1
  fi
fi

AWS_PATH=`which aws`
S3_DIR=s3://${AWS_DIR_NAME}

echo "AWS S3 bucket name is: ${AWS_DIR_NAME}"

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

if ! aws s3 ls ${S3_DIR} &> /dev/null; then
  echo "s3 dir cannot be found, creating..."
  aws s3 mb ${S3_DIR}
  if [[ $? -ne 0 ]]; then
    echo "failed to create s3 bucket, quitting"; exit 1
  fi
fi
BACKUP_SCRIPTS_DIR=`echo ${BACKUP_SCRIPTS_DIR} | sed 's|/$||'`
if [[ -d ${BACKUP_SCRIPTS_DIR} ]]; then
  mkdir -p ${BACKUP_SCRIPTS_DIR}
  if [[ $? -ne 0 ]]; then
    echo "cannot create directory: ${BACKUP_SCRIPTS_DIR}, quitting"; exit 1
  fi
fi

AWS_SCRIPT_FILEPATH=${BACKUP_SCRIPTS_DIR}/${AWS_DIR_NAME}_aws.sh

cat << EOF > ${AWS_SCRIPT_FILEPATH}
#!/bin/bash
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
${AWS_PATH} s3 sync ${DIR_TO_BACKUP} ${S3_DIR}
if [[ \$? -eq 0 ]]; then
  echo "\$(date): BACKUP SUCCESSFUL"
else
  echo "\$(date): BACKUP FAILED"
fi
EOF

if ! [[ -f ${AWS_SCRIPT_FILEPATH} ]]; then
  echo "failed to create the backup script file, please check permissions"
  exit 1
else
  echo "created the backup script: ${AWS_SCRIPT_FILEPATH}"
fi

chmod 700 ${AWS_SCRIPT_FILEPATH}
echo "This script will try to run: ${AWS_SCRIPT_FILEPATH}"
bash ${AWS_SCRIPT_FILEPATH}

echo "trying to add the script to crontab" 
if [[ -f ${CRONTAB_SPOOL_FILE} ]]; then
  sed -i "/${AWS_DIR_NAME}_aws.sh/d" ${CRONTAB_SPOOL_FILE}
fi
echo "${CRONTAB} /bin/bash ${AWS_SCRIPT_FILEPATH} &> /dev/null"  >> ${CRONTAB_SPOOL_FILE}

exit 0
