#!/usr/bin/env bash
# Automação completa: configura a base e envia/executa a configuração no G1 via SSH.
#
# Valores padrão podem ser sobrescritos por variáveis de ambiente, ex.:
#   WIFI=wlan0 CABO=eth1 ./share-to-robot.sh
set -euo pipefail
cd "$(dirname "$0")"

WIFI="${WIFI:-wlp1s0}"
CABO="${CABO:-enx00e04c68001a}"
MEU_IP_CABO="${MEU_IP_CABO:-192.168.123.99}"
ROBOT_IP="${ROBOT_IP:-192.168.123.164}"
ROBOT_USER="${ROBOT_USER:-unitree}"

echo "1. Garantindo IP ${MEU_IP_CABO} no cabo (${CABO})..."
if ! ip -4 addr show dev "$CABO" | grep -q "inet ${MEU_IP_CABO}/"; then
  sudo ip addr add "${MEU_IP_CABO}/24" dev "$CABO"
fi
sudo ip link set "$CABO" up

echo "2. Configurando roteamento na máquina local..."
./setup_host.sh "$WIFI" "$CABO"

echo "3. Copiando script de rede para o G1 (${ROBOT_IP})..."
scp setup_robot.sh "${ROBOT_USER}@${ROBOT_IP}:/home/${ROBOT_USER}/"

echo "4. Executando configuração dentro do G1..."
# -t permite digitar a senha do sudo no robô, se pedida
ssh -t "${ROBOT_USER}@${ROBOT_IP}" "chmod +x setup_robot.sh && sudo ./setup_robot.sh ${MEU_IP_CABO}"

echo "==========================================="
echo " Processo finalizado! G1 online."
echo "==========================================="
