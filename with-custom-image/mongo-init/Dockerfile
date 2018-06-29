FROM alpine:3.7

RUN apk update && apk add bash openssl && wget -qO /peer-finder http://storage.googleapis.com/kubernetes-release/pets/peer-finder

COPY install.sh /
COPY on-start.sh /

RUN chmod -c 755 /install.sh /peer-finder /on-start.sh

ENTRYPOINT ["/install.sh"]
