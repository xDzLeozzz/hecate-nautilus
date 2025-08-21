# Hecate-Nautilus: Unbound "WarSpec" Build
ARG UNBOUND_VERSION=1.19.3
ARG DEBIAN_FRONTEND=noninteractive

# ---- Builder Stage ----
FROM debian:bookworm-slim AS builder

ARG UNBOUND_VERSION
ARG DEBIAN_FRONTEND

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libssl-dev libexpat1-dev libevent-dev \
    libhiredis-dev wget gnupg dirmngr ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# Download and verify Unbound source
RUN wget -O unbound.tar.gz "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz"
RUN wget -O unbound.asc "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz.asc"

# --- CORREÇÃO DEFINITIVA ---
# Baixar a chave GPG diretamente e importar localmente
RUN wget -O nlnetlabs.asc "https://nlnetlabs.nl/downloads/nlnetlabs-key.asc"
RUN gpg --import nlnetlabs.asc
# -------------------------

RUN gpg --verify unbound.asc unbound.tar.gz

RUN tar xzf unbound.tar.gz

# Compile with extreme prejudice and Redis support
WORKDIR /tmp/unbound-${UNBOUND_VERSION}
RUN ./configure \
    --build=$(dpkg-architecture --query DEB_BUILD_GNU_TYPE) \
    --with-libevent \
    --with-libhiredis \
    --with-pthreads \
    --enable-dnscrypt \
    --enable-subnet \
    --with-ssl=/usr \
    --disable-static \
    CFLAGS="-O3 -march=native -flto"

RUN make && make install

# ---- Final Image ----
FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND

RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 libexpat1 libevent-2.1-7 libhiredis0.14 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy compiled binaries and essential files from builder
COPY --from=builder /usr/local/sbin/unbound* /usr/local/sbin/
COPY --from=builder /usr/local/etc/unbound/ /usr/local/etc/unbound/

# Create user and set permissions
RUN groupadd -g 53 unbound && \
    useradd -u 53 -g unbound -d /usr/local/etc/unbound -s /bin/false unbound && \
    mkdir -p /var/lib/unbound && \
    chown -R unbound:unbound /var/lib/unbound /usr/local/etc/unbound

STOPSIGNAL SIGTERM

# Run Unbound in the foreground
CMD ["/usr/local/sbin/unbound", "-d", "-c", "/usr/local/etc/unbound/unbound.conf"]