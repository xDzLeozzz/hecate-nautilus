#!/usr/bin/env bash
set -Eeuo pipefail
log(){ printf '[%(%H:%M:%S)T] %s\n' -1 "$*"; }

REPO_DIR="$HOME/hecate-nautilus"
cd "$REPO_DIR"

log "[*] Sync com origin/main"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "repo inválido"; exit 1; }
git checkout -q main || true
git fetch origin || true
git merge -X ours --no-edit origin/main || true

log "[*] Dockerfile (sem chown em mounts RO; --with-ssl; anchor -R no start)"
mkdir -p unbound
cat > unbound/Dockerfile <<'EOF'
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
 && ./configure --prefix=/usr --sysconfdir=/etc --disable-static --with-libevent --with-ssl \
 && make -j"$(nproc)" \
 && make install

# ---------- RUNTIME ----------
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 libexpat1 libevent-2.1-7 libhiredis0.14 ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# usuário/diretórios (apenas onde é gravável)
RUN groupadd -r unbound && useradd -r -g unbound -s /usr/sbin/nologin -d /var/lib/unbound -M unbound \
 && mkdir -p /var/lib/unbound /var/run/unbound /etc/unbound \
 && chown -R unbound:unbound /var/lib/unbound /var/run/unbound

# binários/libs
COPY --from=builder /usr/sbin/unbound /usr/sbin/unbound
COPY --from=builder /usr/sbin/unbound-anchor /usr/sbin/unbound-anchor
COPY --from=builder /usr/sbin/unbound-host /usr/sbin/unbound-host
COPY --from=builder /usr/sbin/unbound-checkconf /usr/sbin/unbound-checkconf
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/

# entrypoint: inicializa/atualiza trust anchor (RFC5011) e inicia Unbound
RUN printf '%s\n' '#!/bin/sh' 'set -e' \
  'mkdir -p /var/lib/unbound /var/run/unbound' \
  'chown -R unbound:unbound /var/lib/unbound /var/run/unbound' \
  'if [ ! -s /var/lib/unbound/root.key ]; then echo "Initializing root trust anchor..."; unbound-anchor -a /var/lib/unbound/root.key -v || true; chown unbound:unbound /var/lib/unbound/root.key || true; fi' \
  'echo "Refreshing root trust anchor ..."; unbound-anchor -a /var/lib/unbound/root.key -R -v || true' \
  'exec /usr/sbin/unbound -d -c /etc/unbound/unbound.conf' > /usr/local/bin/entrypoint.sh \
 && chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 53/udp 53/tcp
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
EOF

log "[*] unbound.conf (DNSSEC estrito, sem forwarders, logs em stderr)"
mkdir -p unbound/config
cat > unbound/config/unbound.conf <<'CONF'
server:
  username: "unbound"
  directory: "/etc/unbound/"
  auto-trust-anchor-file: "/var/lib/unbound/root.key"
  root-hints: "/etc/unbound/root.hints"

  interface: 127.0.0.1
  port: 5335

  do-daemonize: no
  verbosity: 2
  use-syslog: no
  logfile: ""
  pidfile: "/var/run/unbound/unbound.pid"

  do-ip4: yes
  do-ip6: yes
  prefer-ip6: no
  edns-buffer-size: 1232

  # cache / performance
  msg-cache-size: 128m
  rrset-cache-size: 256m
  cache-min-ttl: 0
  cache-max-ttl: 86400
  prefetch: yes
  prefetch-key: yes

  # DNSSEC + hardening
  module-config: "validator iterator"
  val-permissive-mode: no
  aggressive-nsec: yes
  harden-below-nxdomain: yes
  harden-dnssec-stripped: yes
  harden-glue: yes
  qname-minimisation: yes
  hide-identity: yes
  hide-version: yes

  # buffers
  so-reuseport: yes
  so-rcvbuf: 0
  so-sndbuf: 0

  # ajuste fino
  num-threads: 2
  outgoing-range: 4096
  num-queries-per-thread: 1024
  outgoing-num-tcp: 64
  incoming-num-tcp: 64

remote-control:
  control-enable: no
CONF

# root.hints se faltar
[ -f unbound/config/root.hints ] || curl -fsSL https://www.internic.net/domain/named.root -o unbound/config/root.hints

# commit/push
git add -A
git commit -m "fix: dnssec estrito; anchor refresh; sem chown em mounts RO; sem forwarders" || true
git push origin main || true

# subir Unbound
if command -v docker-compose >/dev/null 2>&1; then DC="docker-compose"; else DC="docker compose"; fi
log "[*] buildando e subindo Unbound"
$DC build --no-cache unbound
$DC up -d unbound

# testes
echo "== unbound -V (features) =="
docker exec hecate-unbound unbound -V || true

echo "== nslookup (127.0.0.1:5335) =="
if command -v nslookup >/dev/null 2>&1; then
  nslookup -port=5335 example.com 127.0.0.1 >/dev/null 2>&1 && echo "[OK] example.com" || echo "[FAIL] example.com"
  nslookup -port=5335 dnssec-failed.org 127.0.0.1 >/dev/null 2>&1 && echo "[FAIL] dnssec-failed.org respondeu (era pra falhar)" || echo "[OK] dnssec-failed.org falhou (DNSSEC OK)"
fi

echo "== unbound-host dentro do container =="
docker exec hecate-unbound unbound-host -C /etc/unbound/unbound.conf -v -t A cloudflare.com || true
docker exec hecate-unbound unbound-host -C /etc/unbound/unbound.conf -v -t A dnssec-failed.org || true

echo "== logs recentes =="
docker logs --since 3m hecate-unbound | tail -n 120 || true

echo
echo "FIM: veja o log em scripts/auto_fix_and_test.log"
