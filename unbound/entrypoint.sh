#!/bin/sh
# Hecate-Nautilus Entrypoint

# Saia imediatamente se um comando falhar
set -e

# Valida o arquivo de configuração antes de prosseguir
echo "Validating Unbound configuration..."
unbound-checkconf /etc/unbound/unbound.conf

# Corrige as permissões da pasta de configuração para o usuário 'unbound'
echo "Setting ownership for /etc/unbound..."

# Entrega o controle para o processo principal do Unbound,
# rodando como o usuário 'unbound'
exec gosu unbound unbound -d -c /etc/unbound/unbound.conf