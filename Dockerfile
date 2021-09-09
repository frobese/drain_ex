FROM alpine

# ENV DRAIN_BIND=127.0.0.1:6986
# ENV DRAIN_DISCOVER=
# ENV DRAIN_GROUP=default
# ENV DRAIN_PEER=

COPY priv/stormdrain-x86_64-unknown-linux-musl /opt/

ENTRYPOINT [ "/opt/stormdrain-x86_64-unknown-linux-musl" ]