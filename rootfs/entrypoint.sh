#!/bin/bash
set -e

for f in /content /alfresco/alf_data /alfresco/tomcat/logs
do
  if [ -d $f ] && [ "$( stat -c '%U:%G' $f )" != "alfresco:alfresco" ]
  then
    chown -R alfresco:alfresco $f
  fi
done

exec "$@"
