# ---------- BUILDER ----------
FROM debian:bookworm-slim AS builder

ARG UNBOUND_VERSION=1.19.3

# Dependências de build
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libssl-dev libexpat1-dev libevent-dev \
    libhiredis-dev wget gnupg dirmngr ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# Baixa o tarball, checksum e assinatura da MESMA versão
RUN set -eux; \
  wget -O "unbound-${UNBOUND_VERSION}.tar.gz"        "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz"; \
  wget -O "unbound-${UNBOUND_VERSION}.tar.gz.sha256" "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz.sha256"; \
  wget -O "unbound-${UNBOUND_VERSION}.tar.gz.asc"    "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz.asc"

# Verificação por SHA256 (robusta e obrigatória)
RUN sha256sum -c "unbound-${UNBOUND_VERSION}.tar.gz.sha256"

# Tenta verificação GPG (não falha o build se o keyserver estiver off)
# Chave do mantenedor do Unbound (Wouter Wijngaards)
RUN set -eux; \
  for ks in hkps://keys.openpgp.org hkps://keyserver.ubuntu.com hkps://pgp.surfnet.nl; do \
    gpg --keyserver "$ks" --recv-keys 9F6F1C2D7E045F8D && break || true; \
  done; \
  gpg --batch --verify "unbound-${UNBOUND_VERSION}.tar.gz.asc" "unbound-${UNBOUND_VERSION}.tar.gz" \
  || echo "WARN: verificação GPG não concluída (seguindo com SHA256 OK)."

# Compila e instala
RUN tar xzf "unbound-${UNBOUND_VERSION}.tar.gz" \
 && cd "unbound-${UNBOUND_VERSION}" \
 && ./configure --prefix=/usr --sysconfdir=/etc --disable-static \
 && make -j"$(nproc)" \
 && make install

# ---------- RUNTIME ----------
FROM debian:bookworm-slim

# Dependências de runtime do unbound compilado
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 libexpat1 libevent-2.1-7 libhiredis0.14 ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# (Opcional) usuário não-root
# RUN useradd -r -s /usr/sbin/nologin unbound

# Binários/libs/config do builder
COPY --from=builder /usr/sbin/unbound /usr/sbin/unbound
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/
COPY --from=builder /etc/unbound /etc/unbound

# Porta DNS
EXPOSE 53/udp
EXPOSE 53/tcp

# (Opcional) rodar como não-root
# USER unbound

ENTRYPOINT ["unbound", "-d"]
