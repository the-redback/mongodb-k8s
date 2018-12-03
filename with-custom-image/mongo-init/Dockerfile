FROM alpine:3.7

RUN apk update && apk add bash openssl && wget -qO /peer-finder http://storage.googleapis.com/kubernetes-release/pets/peer-finder

COPY on-start.sh /

RUN chmod -c 755 /peer-finder /on-start.sh

ENTRYPOINT ["/install.sh"]
