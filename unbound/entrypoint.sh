#!/bin/sh
set -eu

CONF_SRC="/config/unbound.conf"
HINTS_SRC="/config/root.hints"
CONF_DST="/etc/unbound/unbound.conf"
HINTS_DST="/etc/unbound/root.hints"

mkdir -p /etc/unbound /var/run/unbound

# Copia configs montadas
cp -f "$CONF_SRC"  "$CONF_DST"
cp -f "$HINTS_SRC" "$HINTS_DST"

echo "[entrypoint] validating..."
/usr/sbin/unbound-checkconf "$CONF_DST"

echo "[entrypoint] starting unbound..."
exec /usr/sbin/unbound -d -c "$CONF_DST"
