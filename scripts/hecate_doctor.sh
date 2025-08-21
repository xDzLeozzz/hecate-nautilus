#!/usr/bin/env bash
# Hécate Doctor: gera root.key no volume, valida DNSSEC e mostra diagnóstico
set +e
trap 'echo; echo "FIM. Pressione ENTER para sair..."; read -r _ || sleep 5' EXIT

REPO_DIR="$HOME/hecate-nautilus"
cd "$REPO_DIR" || exit 0

# escolher docker compose
if command -v docker-compose >/dev/null 2>&1; then DC="docker-compose"; else DC="docker compose"; fi

# arquivos de compose
CF="$REPO_DIR/docker-compose.yml"
OF="$REPO_DIR/docker-compose.override.yml"
ARGS=(-f "$CF"); [ -f "$OF" ] && ARGS+=(-f "$OF")

# 1) garantir unbound.conf correto (sem trust-anchor explícita; usa root.key)
CONF="unbound/config/unbound.conf"
if [ -f "$CONF" ]; then
  sed -i -E '/^[[:space:]]*trust-anchor:[[:space:]]*"\. DS /Id' "$CONF"
  grep -q '^ *auto-trust-anchor-file: "/var/lib/unbound/root.key"' "$CONF" \
    || sed -i -E 's|^ *auto-trust-anchor-file:.*|  auto-trust-anchor-file: "/var/lib/unbound/root.key"|' "$CONF"
  grep -qi '^\s*val-log-level:' "$CONF" || echo '  val-log-level: 2' >> "$CONF"
fi

# 2) parar unbound (evita loop de restart)
"$DC" "${ARGS[@]}" stop unbound >/dev/null 2>&1

# 3) garantir build da imagem
"$DC" "${ARGS[@]}" build unbound >/dev/null 2>&1

# 4) gerar root.key no MESMO volume do serviço (compose run anexa os volumes do serviço 'unbound')
echo "[*] Gerando /var/lib/unbound/root.key no volume..."
MSYS_NO_PATHCONV=1 "$DC" "${ARGS[@]}" run --rm --entrypoint sh unbound -lc '
  set -eu
  mkdir -p /var/lib/unbound
  rm -f /var/lib/unbound/root.key
  unbound-anchor -a /var/lib/unbound/root.key -v
  echo "--- head(root.key) ---"
  grep -v "^;" /var/lib/unbound/root.key | head -n 5 || true
'

# 5) subir unbound
"$DC" "${ARGS[@]}" up -d unbound
sleep 3

# 6) checagens
echo "== containers =="
docker ps --format '{{.Names}} {{.Status}}' | grep -E 'hecate-(unbound|adguard|redis)' || true

echo "== root.key dentro do container =="
MSYS_NO_PATHCONV=1 docker exec hecate-unbound sh -lc 'ls -l /var/lib/unbound/root.key || true'

echo "== DNS local (127.0.0.1:5335) =="
if command -v nslookup >/dev/null 2>&1; then
  nslookup -port=5335 example.com 127.0.0.1 >/dev/null 2>&1 \
    && echo "[OK] example.com" || echo "[FAIL] example.com"
  nslookup -port=5335 dnssec-failed.org 127.0.0.1 >/dev/null 2>&1 \
    && echo "[FAIL] dnssec-failed.org respondeu (era pra dar SERVFAIL)" \
    || echo "[OK] dnssec-failed.org = SERVFAIL (DNSSEC OK)"
else
  echo "(nslookup não encontrado no host; pulando testes locais)"
fi

echo "== Validação detalhada (no container) =="
MSYS_NO_PATHCONV=1 docker exec hecate-unbound sh -lc 'unbound-host -C /etc/unbound/unbound.conf -v -t A dnssec-failed.org || true'

echo "== Logs recentes do Unbound =="
docker logs --since 120s hecate-unbound | tail -n 150 || true
