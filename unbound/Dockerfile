# ---------- BUILDER ----------
FROM debian:bookworm-slim AS builder
ARG UNBOUND_VERSION=1.19.3
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libssl-dev libexpat1-dev libevent-dev \
    libhiredis-dev wget gnupg dirmngr ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /tmp
RUN set -eux; base="https://nlnetlabs.nl/downloads/unbound"; \
  wget -O "unbound-${UNBOUND_VERSION}.tar.gz"        "${base}/unbound-${UNBOUND_VERSION}.tar.gz"; \
  wget -O "unbound-${UNBOUND_VERSION}.tar.gz.sha256" "${base}/unbound-${UNBOUND_VERSION}.tar.gz.sha256"; \
  wget -O "unbound-${UNBOUND_VERSION}.tar.gz.asc"    "${base}/unbound-${UNBOUND_VERSION}.tar.gz.asc"
RUN set -eux; echo "$(cat unbound-${UNBOUND_VERSION}.tar.gz.sha256)  unbound-${UNBOUND_VERSION}.tar.gz" | sha256sum -c -
RUN set -eux; \
  for ks in hkps://keys.openpgp.org hkps://keyserver.ubuntu.com hkps://pgp.surfnet.nl; do \
    gpg --keyserver "$ks" --recv-keys 9F6F1C2D7E045F8D && break; \
  done; \
  gpg --batch --verify "unbound-${UNBOUND_VERSION}.tar.gz.asc" "unbound-${UNBOUND_VERSION}.tar.gz"
RUN tar xzf "unbound-${UNBOUND_VERSION}.tar.gz" \
 && cd "unbound-${UNBOUND_VERSION}" \
 && ./configure --prefix=/usr --sysconfdir=/etc --disable-static --with-libevent \
 && make -j"$(nproc)" \
 && make install

# ---------- RUNTIME ----------
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 libexpat1 libevent-2.1-7 libhiredis0.14 ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# user/grupo e diretórios (já com owner certo)
RUN groupadd -r unbound && useradd -r -g unbound -s /usr/sbin/nologin -d /var/lib/unbound -M unbound \
 && mkdir -p /var/lib/unbound /var/run/unbound /etc/unbound \
 && chown -R unbound:unbound /var/lib/unbound /var/run/unbound /etc/unbound

# binários e libs
COPY --from=builder /usr/sbin/unbound /usr/sbin/unbound
COPY --from=builder /usr/sbin/unbound-anchor /usr/sbin/unbound-anchor
COPY --from=builder /usr/sbin/unbound-host /usr/sbin/unbound-host
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/

# entrypoint: inicializa root.key se faltar, como usuário unbound
RUN printf '%s\n' '#!/bin/sh' 'set -e' \
  'if [ ! -s /var/lib/unbound/root.key ]; then echo "Initializing root trust anchor..."; unbound-anchor -a /var/lib/unbound/root.key -v || true; fi' \
  'exec unbound -d -c /etc/unbound/unbound.conf' > /usr/local/bin/entrypoint.sh \
 && chmod +x /usr/local/bin/entrypoint.sh

USER unbound:unbound
EXPOSE 53/udp 53/tcp
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
