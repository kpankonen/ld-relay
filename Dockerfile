FROM alpine:3.4

RUN apk --update upgrade \
 && apk add curl ca-certificates \
 && update-ca-certificates \
 && rm -rf /var/cache/apk/*

COPY ldr /usr/bin/
COPY docker-entrypoint.sh /usr/bin/

ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 8030
CMD ["ldr"]
