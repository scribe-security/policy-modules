FROM alpine

WORKDIR /opt/opa

COPY build/docker-entrypoint.sh /opt/opa/docker-entrypoint.sh
# COPY data/empty-input.json /var/opt/opa/input.json
COPY license-artifacts /opt/opa/
COPY build/install_opa.sh /var/opt/opa/


RUN apk --no-cache add curl &&\
    adduser -D opa &&\
    /var/opt/opa/install_opa.sh -d -s -b /opt/opa &&\
    chmod u+x /opt/opa/docker-entrypoint.sh &&\
    chown -R opa:opa /opt/opa &&\
    chown -R opa:opa /var/opt/opa

COPY modules /opt/opa/modules

VOLUME /var/opt/opa/

USER opa

ENTRYPOINT ["/opt/opa/docker-entrypoint.sh"]
CMD ["data.gh.eval"]
