#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$HOME/hecate-nautilus"
cd "$REPO_DIR"

# escolhe docker compose
if command -v docker-compose >/dev/null 2>&1; then DC="docker-compose"; else DC="docker compose"; fi

CONF="unbound/config/unbound.conf"

# 1) normaliza EOL (CRLF -> LF) e garante chaves corretas no bloco server
sed -i 's/\r$//' "$CONF"

# força directory e auto-trust-anchor-file corretos
if grep -qi '^\s*directory:' "$CONF"; then
  sed -i -E 's|^\s*directory:.*|  directory: "/etc/unbound/"|i' "$CONF"
else
  awk '
    BEGIN{p=0}
    {print}
    /^server:\s*$/ && !p { print "  directory: \"/etc/unbound/\""; p=1 }
  ' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"
fi

if grep -qi '^\s*auto-trust-anchor-file:' "$CONF"; then
  sed -i -E 's|^\s*auto-trust-anchor-file:.*|  auto-trust-anchor-file: "/var/lib/unbound/root.key"|i' "$CONF"
else
  awk '
    BEGIN{p=0}
    {print}
    /^server:\s*$/ && !p { print "  auto-trust-anchor-file: \"/var/lib/unbound/root.key\""; p=1 }
  ' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"
fi

# remove qualquer trust-anchor explícita (evita duplicidade com root.key)
sed -i -E '/^\s*trust-anchor:\s*"\. DS /Id' "$CONF"

# 2) mostra resumo das linhas relevantes
echo "== linhas-chave do unbound.conf =="
grep -nE '^\s*(server:|directory:|auto-trust-anchor-file:|trust-anchor:)' "$CONF" || true
echo

# 3) sobe/reinicia unbound
if $DC ps | grep -q hecate-unbound; then
  $DC up -d unbound
else
  $DC up -d unbound
fi

# 4) confirma root.key e testa DNS/DNSSEC
sleep 3
echo "== root.key dentro do container =="
MSYS_NO_PATHCONV=1 docker exec hecate-unbound sh -lc 'ls -l /var/lib/unbound/root.key || true'

echo "== DNS local (127.0.0.1:5335) =="
nslookup -port=5335 example.com 127.0.0.1 >/dev/null 2>&1 && echo "[OK] example.com" || echo "[FAIL] example.com"
nslookup -port=5335 dnssec-failed.org 127.0.0.1 >/dev/null 2>&1 \
  && echo "[FAIL] dnssec-failed.org respondeu (era pra dar SERVFAIL)" \
  || echo "[OK] dnssec-failed.org = SERVFAIL (DNSSEC OK)"

echo "== Validação detalhada (container) =="
MSYS_NO_PATHCONV=1 docker exec hecate-unbound sh -lc 'unbound-host -C /etc/unbound/unbound.conf -v -t A dnssec-failed.org || true'

echo "== Logs recentes do Unbound =="
docker logs --since 120s hecate-unbound | tail -n 150 || true
