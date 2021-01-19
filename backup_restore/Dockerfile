FROM postgres:12-alpine

RUN apk --no-cache add openssh-client

COPY ./bin/backup.sh /backup.sh
COPY ./bin/restore.sh /restore.sh
COPY ./bin/dropdbconnections.sh /dropdbconnections.sh

ENV PGUSER=postgres
ENV PGHOST=db
ENV DB=labkey
ENV BACKUP_ROOT=/backups
ENV FILES_SRC=/usr/local/labkey/files

CMD ["/backup.sh"]
