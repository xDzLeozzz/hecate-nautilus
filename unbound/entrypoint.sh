#!/bin/sh
# Entrypoint Unbound - tolerante a bind mount do Windows
set -u

CONF_SRC="/config/unbound.conf"
HINTS_SRC="/config/root.hints"

CONF_DST="/etc/unbound/unbound.conf"
HINTS_DST="/etc/unbound/root.hints"

mkdir -p /etc/unbound /var/run/unbound

# chown pode falhar em volumes Windows: n??o abortar
chown -R unbound:unbound /etc/unbound /var/run/unbound 2>/dev/null || true

# Copia config se existir
if [ -s "$CONF_SRC" ]; then
  cp -f "$CONF_SRC" "$CONF_DST"
fi

# Copia hints se existir
if [ -s "$HINTS_SRC" ]; then
  cp -f "$HINTS_SRC" "$HINTS_DST"
fi

# Valida e sobe foreground
echo "[entrypoint] checkconf..."
unbound-checkconf "$CONF_DST" || { echo "[entrypoint] invalid conf"; exit 1; }
echo "[entrypoint] starting unbound..."
exec unbound -d -c "$CONF_DST"
