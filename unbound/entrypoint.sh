#!/bin/sh
# Hécate Nautilus — Entrypoint Unbound com gosu (root.key antes do checkconf)
set -e

CONF_SRC="/config/unbound.conf"
HINTS_SRC="/config/root.hints"

CONF_DST="/etc/unbound/unbound.conf"
HINTS_DST="/etc/unbound/root.hints"
ROOTKEY="/etc/unbound/root.key"

mkdir -p /etc/unbound /var/run/unbound
chown -R unbound:unbound /etc/unbound /var/run/unbound

# sync /config (ro) -> /etc/unbound (rw)
[ -f "$CONF_SRC" ] && cp -f "$CONF_SRC" "$CONF_DST"
[ -f "$HINTS_SRC" ] && cp -f "$HINTS_SRC" "$HINTS_DST"
chown -R unbound:unbound /etc/unbound

# 1) root.key primeiro (se não existir, semeia com DS 20326 KSK-2017)
if [ ! -s "$ROOTKEY" ]; then
  echo ">> Seed root.key com DS 20326 (KSK-2017)"
  echo '. IN DS 20326 8 2 E06D44B80B8F1D39A95C0B0D7C65D08458E880409BBC683457104237C7F8EC8D' > "$ROOTKEY"
  chown unbound:unbound "$ROOTKEY"
fi

# 2) refresh/atualiza a âncora (não derruba se falhar)
echo ">> Refresh root.key"
gosu unbound unbound-anchor -a "$ROOTKEY" -R -v || true

# 3) agora sim: valida a config
gosu unbound unbound-checkconf "$CONF_DST"

# 4) inicia
echo ">> Start unbound"
exec gosu unbound unbound -d -c "$CONF_DST"
