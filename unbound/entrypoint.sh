#!/bin/sh
# Hécate-Nautilus Unbound Entrypoint (com fallback de anchor)
set -e

CONF="/etc/unbound/unbound.conf"
ROOT="/etc/unbound"
KEY="$ROOT/root.key"

mkdir -p /var/run/unbound "$ROOT"
chown -R unbound:unbound /var/run/unbound "$ROOT"

# Tenta validar sintaxe já como 'unbound' (ambiente real)
gosu unbound unbound-checkconf "$CONF"

# Tenta (re)atualizar a âncora como 'unbound'
echo "Checking/Updating root trust anchor..."
if ! gosu unbound unbound-anchor -a "$KEY" -R -v; then
  echo "WARN: unbound-anchor falhou, vou usar DS estático." >&2
fi

# Fallback: se não existir ou ficou pequeno, grava DS estático do root (KSK-2017 id 20326)
if [ ! -s "$KEY" ] || [ "$(wc -c < "$KEY")" -lt 100 ]; then
  echo '. IN DS 20326 8 2 E06D44B80B8F1D39A95C0B0D7C65D08458E880409BBC683457104237C7F8EC8D' > "$KEY"
  chown unbound:unbound "$KEY"
fi

# Sobe o Unbound como 'unbound'
exec gosu unbound unbound -d -c "$CONF"
