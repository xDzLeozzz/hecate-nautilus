#!/usr/bin/env bash
set -euo pipefail
log(){ printf '[%(%H:%M:%S)T] %s\n' -1 "$*"; }

log "[*] Branch main e sync"
git checkout -q main || true
git fetch origin || true
git merge -X ours --no-edit origin/main || true

log "[*] Dockerfile do Unbound (build + libevent + SHA256 + GPG + user)"
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
 && ./configure --prefix=/usr --sysconfdir=/etc --disable-static --with-libevent \
 && make -j"$(nproc)" \
 && make install

# ---------- RUNTIME ----------
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 libexpat1 libevent-2.1-7 libhiredis0.14 ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN groupadd -r unbound && useradd -r -g unbound -s /usr/sbin/nologin -d /var/lib/unbound -M unbound \
 && mkdir -p /var/lib/unbound /var/run/unbound /etc/unbound \
 && chown -R unbound:unbound /var/lib/unbound /var/run/unbound
COPY --from=builder /usr/sbin/unbound /usr/sbin/unbound
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/
EXPOSE 53/udp 53/tcp
ENTRYPOINT ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
EOF

log "[*] unbound.conf (recursivo/validante; 127.0.0.1:5335; trust-anchor gravável)"
mkdir -p unbound/config
cat > unbound/config/unbound.conf <<'EOF'
server:
  username: "unbound"
  directory: "/etc/unbound/"
  auto-trust-anchor-file: "/var/lib/unbound/root.key"
  root-hints: "/etc/unbound/root.hints"

  interface: 127.0.0.1
  port: 5335

  do-daemonize: no
  verbosity: 1
  pidfile: "/var/run/unbound/unbound.pid"

  do-ip4: yes
  do-ip6: yes
  prefer-ip6: no
  edns-buffer-size: 1232

  msg-cache-size: 128m
  rrset-cache-size: 256m
  cache-min-ttl: 0
  cache-max-ttl: 86400
  prefetch: yes
  prefetch-key: yes

  aggressive-nsec: yes
  harden-below-nxdomain: yes
  harden-dnssec-stripped: yes
  harden-glue: yes
  qname-minimisation: yes
  hide-identity: yes
  hide-version: yes

  so-reuseport: yes
  so-rcvbuf: 0
  so-sndbuf: 0

  num-threads: 2
  outgoing-range: 4096
  num-queries-per-thread: 1024
  outgoing-num-tcp: 64
  incoming-num-tcp: 64

remote-control:
  control-enable: no
EOF

log "[*] root.hints (se faltar, baixa da IANA)"
[ -f unbound/config/root.hints ] || curl -fsSL https://www.internic.net/domain/named.root -o unbound/config/root.hints

log "[*] docker-compose (host-net) + volume de estado da trust-anchor"
mkdir -p adguard/work adguard/config redis/data
cat > docker-compose.yml <<'EOF'
services:
  unbound:
    build:
      context: ./unbound
    container_name: hecate-unbound
    restart: unless-stopped
    network_mode: "host"
    volumes:
      - ./unbound/config/unbound.conf:/etc/unbound/unbound.conf:ro
      - ./unbound/config/root.hints:/etc/unbound/root.hints:ro
      - unbound_state:/var/lib/unbound

  adguard:
    image: adguard/adguardhome:latest
    container_name: hecate-adguard
    restart: unless-stopped
    network_mode: "host"
    volumes:
      - ./adguard/work:/opt/adguardhome/work
      - ./adguard/config:/opt/adguardhome/conf

  redis:
    image: redis:7-alpine
    container_name: hecate-redis
    restart: unless-stopped
    ports:
      - "127.0.0.1:6379:6379"
    volumes:
      - ./redis/data:/data
    command: ["redis-server","--appendonly","no"]

volumes:
  unbound_state:
EOF

log "[*] hygiene git e push"
printf '* text=auto\n*.sh text eol=lf\n*.conf text eol=lf\n*.yml text eol=lf\nDockerfile text eol=lf\n' > .gitattributes
printf '\nunbound/config/*.bak\n' >> .gitignore
git add -A
git commit -m "Mês 1: baseline estável (recursivo/validante, host-net, trust-anchor em /var/lib)" >/dev/null 2>&1 || true
git push origin main >/dev/null 2>&1 || true

log "[*] subir serviços (tentativa host-net)"
UP_OK=1
docker-compose up -d --build unbound adguard redis || UP_OK=0
if [ "$UP_OK" -eq 0 ]; then
  log "[!] host networking pode não estar habilitado; aplicando fallback por ports"
  cat > docker-compose.override.yml <<'OVR'
services:
  unbound:
    ports:
      - "127.0.0.1:5335:5335/udp"
      - "127.0.0.1:5335:5335/tcp"
  adguard:
    ports:
      - "53:53/udp"
      - "53:53/tcp"
OVR
  docker-compose up -d --build unbound adguard redis
fi

log "[*] checando config dentro do container"
docker exec hecate-unbound unbound-checkconf || true

log "[*] healthcheck"
# testa Unbound direto (porta 5335) e Redis
if command -v nslookup >/dev/null 2>&1; then
  nslookup -port=5335 example.com 127.0.0.1 >/dev/null 2>&1 && log "[OK] Unbound resolveu example.com (127.0.0.1:5335)" || log "[WARN] Unbound não respondeu example.com (5335)"
  nslookup -port=5335 dnssec-failed.org 127.0.0.1 >/dev/null 2>&1 && log "[WARN] dnssec-failed.org respondeu (DNSSEC?)" || log "[OK] dnssec-failed.org falhou (DNSSEC OK)"
fi
docker exec hecate-redis redis-cli -p 6379 PING 2>/dev/null | grep -q PONG && log "[OK] Redis PONG" || log "[WARN] Redis sem PONG"

log "[*] logs recentes do Unbound"
docker logs --since 2m hecate-unbound 2>&1 | tail -n 50 || true

log "[*] month1_fix concluído."
