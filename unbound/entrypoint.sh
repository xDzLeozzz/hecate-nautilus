#!/bin/sh
# Hécate Nautilus — Entrypoint Unbound
set -e

CONF_SRC="/config/unbound.conf"
HINTS_SRC="/config/root.hints"

CONF_DST="/etc/unbound/unbound.conf"
HINTS_DST="/etc/unbound/root.hints"
ROOTKEY="/etc/unbound/root.key"

# pastas e donos
mkdir -p /etc/unbound /var/run/unbound
chown -R unbound:unbound /etc/unbound /var/run/unbound

# 1) garantir que /etc/unbound/unbound.conf exista
if [ -f "$CONF_SRC" ]; then
  cp -f "$CONF_SRC" "$CONF_DST"
else
  # fallback mínimo (caso /config não esteja montado)
  cat > "$CONF_DST" <<'EOF'
server:
  username: "unbound"
  directory: "/etc/unbound/"
  auto-trust-anchor-file: "/etc/unbound/root.key"
  #root-hints: "/etc/unbound/root.hints"
  interface: 0.0.0.0
  port: 5335
  do-daemonize: no
  module-config: "validator iterator"
  verbosity: 1
EOF
fi

# hints (opcional)
[ -f "$HINTS_SRC" ] && cp -f "$HINTS_SRC" "$HINTS_DST" || true

# 2) criar/semear root.key se estiver ausente
if [ ! -s "$ROOTKEY" ]; then
  printf '%s\n' '. IN DS 20326 8 2 E06D44B80B8F1D39A95C0B0D7C65D08458E880409BBC683457104237C7F8EC8D' > "$ROOTKEY"
fi

# tentar refresh (não derruba se falhar por rede/tempo)
unbound-anchor -a "$ROOTKEY" -R -v || true
chown unbound:unbound "$ROOTKEY" || true

# 3) validar sintaxe agora que tudo existe
unbound-checkconf "$CONF_DST"

# 4) executar unbound (ele mesmo troca para o usuário "unbound" pela diretiva 'username')
exec /usr/sbin/unbound -d -c "$CONF_DST"
