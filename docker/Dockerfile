FROM registry.access.redhat.com/ubi8:8.0

RUN yum install -y --disableplugin=subscription-manager --nodocs nginx \
  && yum clean all

#RUN mkdir -p /wwww/files
COPY zip-files/* /www/files/
COPY nginx.conf /etc/nginx/nginx.conf

RUN touch /run/nginx.pid \
  && chgrp -R 0 /var/log/nginx /run/nginx.pid \
  && chmod -R g+rwx /var/log/nginx /run/nginx.pid

EXPOSE 8080
USER 1001

CMD nginx -g "daemon off;"

