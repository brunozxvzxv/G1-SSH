#!/usr/bin/env bash
# Executado DENTRO do robô: usa a base como gateway e configura o DNS.
#
# Uso:     ./setup_robot.sh <ip_da_base_no_cabo>
# Exemplo: ./setup_robot.sh 192.168.123.99
set -euo pipefail

HOST_IP="${1:-192.168.123.99}"
DNS_SERVER="${DNS_SERVER:-8.8.8.8}"

if [[ $EUID -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

echo "Configurando G1 para usar ${HOST_IP} como gateway..."

# 'replace' evita erro caso já exista uma rota default
ip route replace default via "$HOST_IP"
echo "nameserver ${DNS_SERVER}" > /etc/resolv.conf

echo "Testando conexão com a internet..."
ping -c 4 8.8.8.8
echo "Testando resolução de DNS..."
ping -c 2 google.com

echo "Internet configurada com sucesso no G1!"
