#!/usr/bin/env bash
# Configura a máquina base (Linux) para compartilhar internet com o robô via NAT.
#
# Uso:     ./setup_host.sh <interface_internet> <interface_cabo> [--undo]
# Exemplo: ./setup_host.sh wlp1s0 enx00e04c68001a
#          ./setup_host.sh wlp1s0 enx00e04c68001a --undo   # remove as regras
set -euo pipefail

INTERNET_IFACE="${1:-wlp1s0}"
ROBOT_IFACE="${2:-enx00e04c68001a}"
ACTION="up"
[[ "${3:-}" == "--undo" ]] && ACTION="down"

# Reexecuta com sudo se necessário
if [[ $EUID -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

for iface in "$INTERNET_IFACE" "$ROBOT_IFACE"; do
  if ! ip link show "$iface" &>/dev/null; then
    echo "Erro: interface '$iface' não encontrada. Veja as disponíveis com: ip -br link" >&2
    exit 1
  fi
done

# apply <tabela> <chain> <regra...>  (idempotente: não duplica regras)
apply() {
  local table=$1 chain=$2
  shift 2
  if [[ $ACTION == "up" ]]; then
    iptables -t "$table" -C "$chain" "$@" 2>/dev/null || iptables -t "$table" -A "$chain" "$@"
  else
    iptables -t "$table" -D "$chain" "$@" 2>/dev/null || true
  fi
}

echo "==========================================="
echo " Roteamento NAT (${ACTION})"
echo " Internet: ${INTERNET_IFACE} | Cabo: ${ROBOT_IFACE}"
echo "==========================================="

if [[ $ACTION == "up" ]]; then
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
else
  sysctl -w net.ipv4.ip_forward=0 >/dev/null
fi

apply nat    POSTROUTING -o "$INTERNET_IFACE" -j MASQUERADE
apply filter FORWARD     -i "$ROBOT_IFACE" -o "$INTERNET_IFACE" -j ACCEPT
apply filter FORWARD     -i "$INTERNET_IFACE" -o "$ROBOT_IFACE" \
                         -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

if [[ $ACTION == "up" ]]; then
  echo "Roteamento ativado na base!"
  echo "Nota: as regras se perdem ao reiniciar. Para persistir:"
  echo "  sudo apt install iptables-persistent && sudo netfilter-persistent save"
else
  echo "Roteamento desativado e regras removidas."
fi
