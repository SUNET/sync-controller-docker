FROM debian:bookworm-slim

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ARG DEBIAN_FRONTEND=noninteractive

RUN apt update && apt upgrade -y && apt install -y \
  curl \
  jq \
  mariadb-client

USER nobody:nogroup
ENV HOME /var/tmp/
WORKDIR /var/tmp/

ENTRYPOINT ["/entrypoint.sh"]
