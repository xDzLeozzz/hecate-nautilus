# ---------- BUILDER ----------
FROM debian:bookworm-slim AS builder

ARG UNBOUND_VERSION=1.19.3

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libssl-dev libexpat1-dev libevent-dev \
    libhiredis-dev wget gnupg dirmngr ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# Baixa tarball, checksum e assinatura da MESMA versão
RUN set -eux; \
  base="https://nlnetlabs.nl/downloads/unbound"; \
  wget -O "unbound-${UNBOUND_VERSION}.tar.gz"        "${base}/unbound-${UNBOUND_VERSION}.tar.gz"; \
  wget -O "unbound-${UNBOUND_VERSION}.tar.gz.sha256" "${base}/unbound-${UNBOUND_VERSION}.tar.gz.sha256"; \
  wget -O "unbound-${UNBOUND_VERSION}.tar.gz.asc"    "${base}/unbound-${UNBOUND_VERSION}.tar.gz.asc"

# Verificação por SHA256 (o .sha256 vem só com o hash)
RUN set -eux; \
  echo "$(cat unbound-${UNBOUND_VERSION}.tar.gz.sha256)  unbound-${UNBOUND_VERSION}.tar.gz" | sha256sum -c -

# Importa a chave do Wouter (GPG estrito) e verifica assinatura
# GPG key ID: 9F6F1C2D7E045F8D
RUN set -eux; \
  for ks in hkps://keys.openpgp.org hkps://keyserver.ubuntu.com hkps://pgp.surfnet.nl; do \
    gpg --keyserver "$ks" --recv-keys 9F6F1C2D7E045F8D && break; \
  done; \
  gpg --batch --verify "unbound-${UNBOUND_VERSION}.tar.gz.asc" "unbound-${UNBOUND_VERSION}.tar.gz"

# Compila e instala
RUN tar xzf "unbound-${UNBOUND_VERSION}.tar.gz" \
 && cd "unbound-${UNBOUND_VERSION}" \
 && ./configure --prefix=/usr --sysconfdir=/etc --disable-static \
 && make -j"$(nproc)" \
 && make install

# ---------- RUNTIME ----------
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 libexpat1 libevent-2.1-7 libhiredis0.14 ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Binários e libs
COPY --from=builder /usr/sbin/unbound /usr/sbin/unbound
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/

# Config será montada por volume (sem forwarders)
EXPOSE 53/udp
EXPOSE 53/tcp

ENTRYPOINT ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
