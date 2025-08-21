#!/bin/sh
set -e

CONF_SRC="/config/unbound.conf"
HINTS_SRC="/config/root.hints"
CONF_DST="/etc/unbound/unbound.conf"
HINTS_DST="/etc/unbound/root.hints"
ROOTKEY="/etc/unbound/root.key"

mkdir -p /etc/unbound /var/run/unbound
chown -R unbound:unbound /var/run/unbound || true

# Copia configs do volume somente-leitura /config -> /etc/unbound
if [ -f "$CONF_SRC" ]; then cp -f "$CONF_SRC" "$CONF_DST"; fi
if [ -f "$HINTS_SRC" ]; then cp -f "$HINTS_SRC" "$HINTS_DST"; fi

# 1) Garante root.key ANTES do checkconf (semeia DS se necessário)
if [ ! -s "$ROOTKEY" ]; then
  echo ">> Seed root.key com DS 20326 (KSK-2017)"
  printf '%s\n' '. IN DS 20326 8 2 E06D44B80B8F1D39A95C0B0D7C65D08458E880409BBC683457104237C7F8EC8D' > "$ROOTKEY"
fi

# 2) Tenta atualizar a âncora (não derruba se falhar, ex.: sem rede/tempo)
echo ">> Refresh root.key"
unbound-anchor -a "$ROOTKEY" -R -v || true

# 3) Valida a config agora que root.key existe
unbound-checkconf "$CONF_DST"

# 4) Sobe o Unbound
exec /usr/sbin/unbound -d -c "$CONF_DST"
