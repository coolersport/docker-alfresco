#!/bin/bash
set -e

# set correct timezone
cp -f /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

for f in /content /alfresco/alf_data /alfresco/tomcat/logs
do
  if [ -d $f ] && [ "$( stat -c '%U:%G' $f )" != "alfresco:alfresco" ]
  then
    chown -R alfresco:alfresco $f
  fi
done

exec "$@"
