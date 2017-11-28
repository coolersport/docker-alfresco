#!/usr/bin/env bash

# set correct timezone
unalias cp
cp -f /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# first check to see if alf_data has keystore directory, this is a crude way
# to determine if the mounted location has data or not, then we can bootstrap
# if it is the first time this is run
# let's copy data into the volume if it does not exist
if [ ! -d /alfresco/alf_data/keystore ]; then
  rsync -av --no-o --no-g /alf_data.install/alf_data /alfresco/

  echo
  echo 'Alfresco copied data from an original installation; ready for start up.'
  echo 'WARNING: if this was not expected, then you likely mounted a volume'
  echo '         that did not have the necessary files.  Please check your'
  echo '         volume paths.'
  echo
fi

ALF_HOME=/alfresco
ALF_BIN=$ALF_HOME/bin
ALF_SETUP=$ALF_HOME/setup
CATALINA_HOME=$ALF_HOME/tomcat

ALFRESCO_HOSTNAME=${ALFRESCO_HOSTNAME:-127.0.0.1}
ALFRESCO_PROTOCOL=${ALFRESCO_PROTOCOL:-http}
if [ "${ALFRESCO_PROTOCOL,,}" = "https" ]; then
  ALFRESCO_PORT=${ALFRESCO_PORT:-8443}
else
  ALFRESCO_PORT=${ALFRESCO_PORT:-8080}
fi


SHARE_HOSTNAME=${SHARE_HOSTNAME:-127.0.0.1}
SHARE_PROTOCOL=${SHARE_PROTOCOL:-http}
if [ "${SHARE_PROTOCOL,,}" = "https" ]; then
  SHARE_PORT=${SHARE_PORT:-8443}
else
  SHARE_PORT=${SHARE_PORT:-8080}
fi

DB_KIND=${DB_KIND:-postgresql}
DB_USERNAME=${DB_USERNAME:-alfresco}
DB_PASSWORD=${DB_PASSWORD:-admin}
DB_NAME=${DB_NAME:-alfresco}
DB_HOST=${DB_HOST:-localhost}
case "${DB_KIND,,}" in
  postgresql)
    DB_DRIVER=org.postgresql.Driver
    DB_PORT=${DB_PORT:-5432}
    ;;
  mysql)
    DB_DRIVER=org.gjt.mm.mysql.Driver
    DB_PORT=${DB_PORT:-3306}
    DB_CONN_PARAMS=${DB_CONN_PARAMS:-?useSSL=false}
    ;;
  *)
    echo "Database kind '$DB_KIND' not supported!"
    exit 1
esac

SYSTEM_SERVERMODE=${SYSTEM_SERVERMODE:-PRODUCTION}

MAIL_HOST=${MAIL_HOST:-localhost}
MAIL_PORT=${MAIL_PORT:-25}
MAIL_USERNAME=${MAIL_USERNAME:-}
MAIL_PASSWORD=${MAIL_PASSWORD:-}
MAIL_FROM_DEFAULT=${MAIL_FROM_DEFAULT:-alfresco@alfresco.org}
MAIL_PROTOCOL=${MAIL_PROTOCOL:-smtp}
MAIL_SMTP_AUTH=${MAIL_SMTP_AUTH:-false}
MAIL_SMTP_STARTTLS_ENABLE=${MAIL_SMTP_STARTTLS_ENABLE:-false}
MAIL_SMTPS_AUTH=${MAIL_SMTPS_AUTH:-false}
MAIL_SMTPS_STARTTLS_ENABLE=${MAIL_SMTPS_STARTTLS_ENABLE:-false}

FTP_PORT=${FTP_PORT:-21}

CIFS_ENABLED=${CIFS_ENABLED:-true}
CIFS_SERVER_NAME=${CIFS_SERVER_NAME:-localhost}
CIFS_DOMAIN=${CIFS_DOMAIN:-WORKGROUP}

NFS_ENABLED=${NFS_ENABLED:-true}

LDAP_ENABLED=${LDAP_ENABLED:-false}
LDAP_KIND=${LDAP_KIND:-ldap}
LDAP_AUTH_USERNAMEFORMAT=${LDAP_AUTH_USERNAMEFORMAT-uid=%s,cn=users,cn=accounts,dc=example,dc=com}
LDAP_URL=${LDAP_URL:-ldap://ldap.example.com:389}
LDAP_DEFAULT_ADMINS=${LDAP_DEFAULT_ADMINS:-admin}
LDAP_SECURITY_PRINCIPAL=${LDAP_SECURITY_PRINCIPAL:-uid=admin,cn=users,cn=accounts,dc=example,dc=com}
LDAP_SECURITY_CREDENTIALS=${LDAP_SECURITY_CREDENTIALS:-password}
LDAP_GROUP_SEARCHBASE=${LDAP_GROUP_SEARCHBASE:-cn=groups,cn=accounts,dc=example,dc=com}
LDAP_USER_SEARCHBASE=${LDAP_USER_SEARCHBASE:-cn=users,cn=accounts,dc=example,dc=com}
LDAP_USER_ATTRIBUTENAME=${LDAP_USER_ATTRIBUTENAME:-uid}
LDAP_GROUP_MEMBER_ATTRIBUTENAME=${LDAP_GROUP_MEMBER_ATTRIBUTENAME:-memberUid}

CONTENT_STORE=${CONTENT_STORE:-/content}

TOMCAT_CSRF_PATCH="${ALF_HOME}/disable_tomcat_CSRF.patch"
TOMCAT_CSRF_ENABLED=${TOMCAT_CSRF_ENABLED:-true}

function cfg_replace_option {
  grep "$1" "$2" > /dev/null
  if [ $? -eq 0 ]; then
    # replace option
    echo "replacing option  $1=$3  in  $2"
    sed -i "s#^\($1\s*=\s*\).*\$#\1$3#" $2
    if (( $? )); then
      echo "cfg_replace_option failed"
      exit 1
    fi
  else
    # add option if it does not exist
    echo "adding option  $1=$3  in  $2"
    echo "$1=$3" >> $2
  fi
}

function tweak_alfresco {
  ALFRESCO_GLOBAL_PROPERTIES=$CATALINA_HOME/shared/classes/alfresco-global.properties

  echo -e "\n" >> $ALFRESCO_GLOBAL_PROPERTIES # ensure new line at end of file

  #alfresco host+proto+port
  cfg_replace_option alfresco.host $ALFRESCO_GLOBAL_PROPERTIES $ALFRESCO_HOSTNAME
  cfg_replace_option alfresco.protocol $ALFRESCO_GLOBAL_PROPERTIES $ALFRESCO_PROTOCOL
  cfg_replace_option alfresco.port $ALFRESCO_GLOBAL_PROPERTIES $ALFRESCO_PORT

  #share host+proto+port
  cfg_replace_option share.host $ALFRESCO_GLOBAL_PROPERTIES $SHARE_HOSTNAME
  cfg_replace_option share.protocol $ALFRESCO_GLOBAL_PROPERTIES $SHARE_PROTOCOL
  cfg_replace_option share.port $ALFRESCO_GLOBAL_PROPERTIES $SHARE_PORT

  #set server mode
  cfg_replace_option system.serverMode $ALFRESCO_GLOBAL_PROPERTIES $SYSTEM_SERVERMODE

  #db.schema.update=true
  cfg_replace_option db.driver $ALFRESCO_GLOBAL_PROPERTIES $DB_DRIVER
  cfg_replace_option db.username $ALFRESCO_GLOBAL_PROPERTIES $DB_USERNAME
  cfg_replace_option db.password $ALFRESCO_GLOBAL_PROPERTIES $DB_PASSWORD
  cfg_replace_option db.name $ALFRESCO_GLOBAL_PROPERTIES $DB_NAME
  cfg_replace_option db.url $ALFRESCO_GLOBAL_PROPERTIES jdbc:${DB_KIND,,}://${DB_HOST}:${DB_PORT}/${DB_NAME}${DB_CONN_PARAMS}

  cfg_replace_option mail.host $ALFRESCO_GLOBAL_PROPERTIES $MAIL_HOST
  cfg_replace_option mail.port $ALFRESCO_GLOBAL_PROPERTIES $MAIL_PORT
  cfg_replace_option mail.username $ALFRESCO_GLOBAL_PROPERTIES $MAIL_USERNAME
  cfg_replace_option mail.password $ALFRESCO_GLOBAL_PROPERTIES $MAIL_PASSWORD
  cfg_replace_option mail.from.default $ALFRESCO_GLOBAL_PROPERTIES $MAIL_FROM_DEFAULT
  cfg_replace_option mail.protocol $ALFRESCO_GLOBAL_PROPERTIES $MAIL_PROTOCOL
  cfg_replace_option mail.smtp.auth $ALFRESCO_GLOBAL_PROPERTIES $MAIL_SMTP_AUTH
  cfg_replace_option mail.smtp.starttls.enable $ALFRESCO_GLOBAL_PROPERTIES $MAIL_SMTP_STARTTLS_ENABLE
  cfg_replace_option mail.smtps.auth $ALFRESCO_GLOBAL_PROPERTIES $MAIL_SMTPS_AUTH
  cfg_replace_option mail.smtps.starttls.enable $ALFRESCO_GLOBAL_PROPERTIES $MAIL_SMTPS_STARTTLS_ENABLE

  cfg_replace_option ftp.port $ALFRESCO_GLOBAL_PROPERTIES $FTP_PORT

  # @see https://forums.alfresco.com/en/viewtopic.php?f=8&t=20893
  # CIFS works, but you have to login as a native Alfresco account, like admin
  # because CIFS does not work with LDAP authentication
  cfg_replace_option cifs.enabled $ALFRESCO_GLOBAL_PROPERTIES $CIFS_ENABLED
  cfg_replace_option cifs.Server.Name $ALFRESCO_GLOBAL_PROPERTIES $CIFS_SERVER_NAME
  cfg_replace_option cifs.domain $ALFRESCO_GLOBAL_PROPERTIES $CIFS_DOMAIN
  cfg_replace_option cifs.hostannounce $ALFRESCO_GLOBAL_PROPERTIES "true"
  cfg_replace_option cifs.broadcast $ALFRESCO_GLOBAL_PROPERTIES "0.0.0.255"
  cfg_replace_option cifs.ipv6.enabled $ALFRESCO_GLOBAL_PROPERTIES "false"

  cfg_replace_option nfs.enabled $ALFRESCO_GLOBAL_PROPERTIES $NFS_ENABLED

  # authentication
  if [ "$LDAP_ENABLED" == "true" ]; then
    cfg_replace_option authentication.chain $ALFRESCO_GLOBAL_PROPERTIES "alfrescoNtlm1:alfrescoNtlm,ldap1:${LDAP_KIND}"

    # now make substitutions in the LDAP config file
    LDAP_CONFIG_FILE=$CATALINA_HOME/shared/classes/alfresco/extension/subsystems/Authentication/${LDAP_KIND}/ldap1/${LDAP_KIND}-authentication.properties

    cfg_replace_option "ldap.authentication.userNameFormat" "$LDAP_CONFIG_FILE" "$LDAP_AUTH_USERNAMEFORMAT"
    cfg_replace_option ldap.authentication.java.naming.provider.url $LDAP_CONFIG_FILE $LDAP_URL
    cfg_replace_option ldap.authentication.defaultAdministratorUserNames $LDAP_CONFIG_FILE $LDAP_DEFAULT_ADMINS
    cfg_replace_option ldap.synchronization.java.naming.security.principal $LDAP_CONFIG_FILE $LDAP_SECURITY_PRINCIPAL
    cfg_replace_option ldap.synchronization.java.naming.security.credentials $LDAP_CONFIG_FILE $LDAP_SECURITY_CREDENTIALS
    cfg_replace_option ldap.synchronization.groupSearchBase $LDAP_CONFIG_FILE $LDAP_GROUP_SEARCHBASE
    cfg_replace_option ldap.synchronization.userSearchBase $LDAP_CONFIG_FILE $LDAP_USER_SEARCHBASE
    cfg_replace_option ldap.synchronization.userIdAttributeName $LDAP_CONFIG_FILE $LDAP_USER_ATTRIBUTENAME
    cfg_replace_option ldap.synchronization.groupMemberAttributeName $LDAP_CONFIG_FILE $LDAP_GROUP_MEMBER_ATTRIBUTENAME
  else
    cfg_replace_option authentication.chain $ALFRESCO_GLOBAL_PROPERTIES "alfrescoNtlm1:alfrescoNtlm"
  fi

  # content store
  cfg_replace_option dir.contentstore $ALFRESCO_GLOBAL_PROPERTIES "${CONTENT_STORE}/contentstore"
  cfg_replace_option dir.contentstore.deleted $ALFRESCO_GLOBAL_PROPERTIES "${CONTENT_STORE}/contentstore.deleted"
}

tweak_alfresco

if [ -d "$AMP_DIR_ALFRESCO" ]; then
  echo "Installing Alfresco AMPs from $AMP_DIR_ALFRESCO..."
  $ALF_HOME/java/bin/java -jar $ALF_HOME/bin/alfresco-mmt.jar install $AMP_DIR_ALFRESCO $CATALINA_HOME/webapps/alfresco.war -directory -force -verbose
  $ALF_HOME/java/bin/java -jar $ALF_HOME/bin/alfresco-mmt.jar list $CATALINA_HOME/webapps/alfresco.war
fi

if [ -d "$AMP_DIR_SHARE" ]; then
  echo "Installing Share AMPs from $AMP_DIR_SHARE..."
  $ALF_HOME/java/bin/java -jar $ALF_HOME/bin/alfresco-mmt.jar install $AMP_DIR_SHARE $CATALINA_HOME/webapps/share.war -directory -force -verbose
  $ALF_HOME/java/bin/java -jar $ALF_HOME/bin/alfresco-mmt.jar list $CATALINA_HOME/webapps/share.war
fi

# setup environment
source $ALF_HOME/scripts/setenv.sh
export FONTCONFIG_PATH=/etc/fonts

# start internal postgres server only if the host is localhost
if [ "${DB_KIND,,}" == "postgresql" ] && [ "$DB_HOST" == "localhost" ]; then
  $ALF_HOME/postgresql/scripts/ctl.sh start
fi

#disable CSRF if needed
#rename the patch to prevent reuse
if [ "$TOMCAT_CSRF_ENABLED" == "false" ] && [ -f "$TOMCAT_CSRF_PATCH" ] ;then
  patch -Np0 < $TOMCAT_CSRF_PATCH
  [ $? == 0 ] && mv "$TOMCAT_CSRF_PATCH" "${TOMCAT_CSRF_PATCH}.done"
fi

if [ -f /callback/prestart.sh ]; then
  chmod u+x /callback/prestart.sh
  /callback/prestart.sh
fi

# start alfresco
$ALF_HOME/tomcat/scripts/ctl.sh start
