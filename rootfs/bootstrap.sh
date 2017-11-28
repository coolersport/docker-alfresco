#!/bin/bash

# add api user
date +"%F %T,%3N Adding new user $BOOTSTRAP_USER (it may takes a while)..."
CODE=`curl --connect-timeout 600 -w %{http_code} -fs -o /dev/null -X POST \
  http://localhost:8080/alfresco/s/api/people \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -d '{
        "userName": "'"$BOOTSTRAP_USER"'",
        "firstName": "API",
        "lastName": "User",
        "email": "ttran@genixventures.com",
        "password": "'"$BOOTSTRAP_PASSWORD"'"
}'`

if [ "$CODE" == "200" ]
then
	# change admin password
	date +"%F %T,%3N Changing admin password..."
	curl -fs -X POST \
	  http://localhost:8080/alfresco/s/api/person/changepassword/admin \
	  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
	  -H 'cache-control: no-cache' \
	  -H 'content-type: application/json' \
	  -d '{
	        "newpw":"'"$ADMIN_PASSWORD"'",
	        "oldpw":"admin"
	}'

	date +"%F %T,%3N You should change the default admin password IMMEDIATELY!!!"
	exit 0
fi

# checking admin password
date +"%F %T,%3N Couldn't add $BOOTSTRAP_USER (http-code=$CODE). Now checking if admin password has been secured..."
AUTH=`echo -n "admin:$ADMIN_PASSWORD" | base64 -`
CODE=`curl -w %{http_code} -fs -o /dev/null -X POST \
  http://localhost:8080/alfresco/s/api/person/changepassword/admin \
  -H 'authorization: Basic '"$AUTH"'' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -d '{
        "newpw":"'"$ADMIN_PASSWORD"'",
        "oldpw":"'"$ADMIN_PASSWORD"'"
}'`

if [ "$CODE" == "200" ]
then
	date +"%F %T,%3N You should change the default admin password IMMEDIATELY!!!"
else
	date +"%F %T,%3N Bootstrap completed. All looks good."
fi

