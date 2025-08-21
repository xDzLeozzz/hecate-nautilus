# ---------- BUILDER ----------
FROM debian:bookworm-slim AS builder
ARG UNBOUND_VERSION=1.19.3

RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential libssl-dev libexpat1-dev libevent-dev \
  wget gnupg dirmngr ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN set -eux; base="https://nlnetlabs.nl/downloads/unbound"; \
  wget -O "unbound-${UNBOUND_VERSION}.tar.gz"        "${base}/unbound-${UNBOUND_VERSION}.tar.gz"; \
  wget -O "unbound-${UNBOUND_VERSION}.tar.gz.sha256" "${base}/unbound-${UNBOUND_VERSION}.tar.gz.sha256"; \
  wget -O "unbound-${UNBOUND_VERSION}.tar.gz.asc"    "${base}/unbound-${UNBOUND_VERSION}.tar.gz.asc"; \
  echo "$(cat unbound-${UNBOUND_VERSION}.tar.gz.sha256)  unbound-${UNBOUND_VERSION}.tar.gz" | sha256sum -c -

RUN tar xzf "unbound-${UNBOUND_VERSION}.tar.gz" \
 && cd "unbound-${UNBOUND_VERSION}" \
 && ./configure --prefix=/usr --sysconfdir=/etc --disable-static --with-libevent --with-ssl \
 && make -j"$(nproc)" && make install

# ---------- RUNTIME ----------
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 libexpat1 libevent-2.1-7 ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# usuário e pastas
RUN groupadd -r unbound && useradd -r -g unbound -s /usr/sbin/nologin -d /var/lib/unbound -M unbound \
 && mkdir -p /var/run/unbound /etc/unbound \
 && chown -R unbound:unbound /var/run/unbound /etc/unbound

# binários do builder
COPY --from=builder /usr/sbin/unbound /usr/sbin/unbound
COPY --from=builder /usr/sbin/unbound-host /usr/sbin/unbound-host
COPY --from=builder /usr/sbin/unbound-checkconf /usr/sbin/unbound-checkconf
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/

# entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER root
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
