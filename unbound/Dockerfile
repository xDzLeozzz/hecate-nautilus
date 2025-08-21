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
  wget -O "unbound-${UNBOUND_VERSION}.tar.gz.asc"    "${base}/unbound-${UNBOUND_VERSION}.tar.gz.asc"

# Verificação forte por SHA256
RUN set -eux; echo "$(cat unbound-${UNBOUND_VERSION}.tar.gz.sha256)  unbound-${UNBOUND_VERSION}.tar.gz" | sha256sum -c -

# GPG opcional (não falha o build se o keyserver estiver off)
RUN set -eux; for ks in hkps://keys.openpgp.org hkps://keyserver.ubuntu.com hkps://pgp.surfnet.nl; do \
      gpg --keyserver "$ks" --recv-keys 9F6F1C2D7E045F8D && break || true; done; \
  gpg --batch --verify "unbound-${UNBOUND_VERSION}.tar.gz.asc" "unbound-${UNBOUND_VERSION}.tar.gz" || true

RUN tar xzf "unbound-${UNBOUND_VERSION}.tar.gz" \
 && cd "unbound-${UNBOUND_VERSION}" \
 && ./configure --prefix=/usr --sysconfdir=/etc --disable-static --with-libevent --with-ssl \
 && make -j"$(nproc)" && make install

# ---------- RUNTIME ----------
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
  libssl3 libexpat1 libevent-2.1-7 ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Usuário e diretórios de estado
RUN groupadd -r unbound && useradd -r -g unbound -s /usr/sbin/nologin -d /var/lib/unbound -M unbound \
 && mkdir -p /var/lib/unbound /var/run/unbound /etc/unbound \
 && chown -R unbound:unbound /var/lib/unbound /var/run/unbound

# Binários
COPY --from=builder /usr/sbin/unbound /usr/sbin/unbound
COPY --from=builder /usr/sbin/unbound-anchor /usr/sbin/unbound-anchor
COPY --from=builder /usr/sbin/unbound-host /usr/sbin/unbound-host
COPY --from=builder /usr/sbin/unbound-checkconf /usr/sbin/unbound-checkconf
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/

# Entrypoint: cria/atualiza o root.key e sobe o Unbound
RUN printf '%s\n' '#!/bin/sh' 'set -e' \
 'mkdir -p /var/run/unbound /etc/unbound' \
 'chown -R unbound:unbound /var/run/unbound || true' \
 '' \
 '# cria o root.key se estiver ausente ou vazio' \
 'if [ ! -s /etc/unbound/root.key ]; then' \
 '  echo "Initializing root trust anchor...";' \
 '  unbound-anchor -a /etc/unbound/root.key -v || {' \
 '    echo "WARN: unbound-anchor falhou; semeando DS 20326 localmente";' \
 '    printf "%s\n" ". IN DS 20326 8 2 E06D44B80B8F1D39A95C0B0D7C65D08458E880409BBC683457104237C7F8EC8D" > /etc/unbound/root.key;' \
 '  };' \
 '  chown unbound:unbound /etc/unbound/root.key || true;' \
 'fi' \
 '' \
 '# sempre tenta refrescar a âncora' \
 'echo "Refreshing root trust anchor ...";' \
 'unbound-anchor -a /etc/unbound/root.key -R -v || true' \
 '' \
 '# valida sintaxe antes de subir' \
 'unbound-checkconf /etc/unbound/unbound.conf' \
 '' \
 'exec /usr/sbin/unbound -d -c /etc/unbound/unbound.conf' \
 > /usr/local/bin/entrypoint.sh \
 && chmod +x /usr/local/bin/entrypoint.sh

# Exponha a porta que você usa no unbound.conf
EXPOSE 5335/tcp 5335/udp

# Healthcheck simples (consulta recursiva ao root)
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD unbound-host -C /etc/unbound/unbound.conf -t NS . >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
