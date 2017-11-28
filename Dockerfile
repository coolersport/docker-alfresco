# gui81/alfresco

FROM centos:centos7
MAINTAINER Lucas Johnson <lucasejohnson@netscape.net>

# install some necessary/desired RPMs and get updates
RUN yum update -y && \
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum install -y \
                   cairo \
                   cups-libs \
                   fontconfig \
                   java-1.8.0-openjdk \
                   libICE \
                   libSM \
                   libXext \
                   libXinerama \
                   libXrender \
                   mesa-libGLU \
                   patch \
                   rsync \
                   supervisor \
                   wget && \
    yum clean all && rm -rf /tmp/* /var/tmp/* /var/cache/yum/*

ENV ALF_DATA /alfresco/alf_data
ENV TZ Australia/Melbourne

#debug,info,warn,error,critical
ENV LOG_LEVEL warn
ENV BOOTSTRAP_DELAY 30
ENV BOOTSTRAP_USER apiUser
ENV BOOTSTRAP_PASSWORD somePassword
ENV ADMIN_PASSWORD adminPassw0rd

COPY rootfs /

RUN chmod u+x /tmp/*.sh && \
# install alfresco
    /tmp/install_alfresco.sh && \
# install mysql connector for alfresco
    /tmp/install_mysql_connector.sh && \
# this is for LDAP configuration
    unalias cp && \
    cp -r /alfresco-assets/* /alfresco/ && \
# backup alf_data so that it can be used in init.sh if necessary
    rsync -av $ALF_DATA /alf_data.install/ && \
# prepare to run as non-root user
    groupadd alfresco && useradd -g alfresco -s /bin/sh alfresco && \
    chown -R alfresco:alfresco /alfresco && \
    chown -R alfresco:alfresco /alf_data.install && \
# additional scripts
    chmod +x /*.sh && \
# clean up
    rm -rf /tmp/* /var/tmp/* /alfresco-assets

VOLUME /alfresco/alf_data
VOLUME /alfresco/tomcat/logs
VOLUME /content

EXPOSE 21 137 138 139 445 7070 8009 8080

ENTRYPOINT ["/entrypoint.sh"]
CMD ["sh", "-c", "/usr/bin/supervisord -c /etc/supervisord.conf -n -e ${LOG_LEVEL}"]
