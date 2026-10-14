#!/usr/bin/env bash
# g1-internet.sh - Compartilha a internet do notebook (Linux + NetworkManager)
# com o Unitree G1 EDU via cabo Ethernet, de forma permanente.
#
# Uso:
#   ./g1-internet.sh install   # configura notebook + robo (o que voce quer na maioria das vezes)
#   ./g1-internet.sh host      # so o notebook
#   ./g1-internet.sh robot     # so o robo (via SSH)
#   ./g1-internet.sh status    # mostra o estado atual
#   ./g1-internet.sh remove    # remove o perfil de compartilhamento do notebook
#
# Variaveis opcionais (exemplo: CABO=enx123 ./g1-internet.sh install):
#   CABO        interface do cabo do robo   (auto-detecta enx*)
#   HOST_IP     IP do notebook na rede do robo  (192.168.123.99)
#   ROBOT_IP    IP do PC2/Jetson do robo        (192.168.123.164)
#   ROBOT_USER  usuario SSH do robo             (unitree)
#   DNS         DNS usados pelo robo            (8.8.8.8 1.1.1.1)
#   PROFILE     nome do perfil no notebook      (g1-share)

set -euo pipefail

HOST_IP="${HOST_IP:-192.168.123.99}"
ROBOT_IP="${ROBOT_IP:-192.168.123.164}"
ROBOT_USER="${ROBOT_USER:-unitree}"
DNS="${DNS:-8.8.8.8 1.1.1.1}"
PROFILE="${PROFILE:-g1-share}"
CABO="${CABO:-}"

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=8)

info() { printf '\033[1;34m[g1]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ok]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[erro]\033[0m %s\n' "$*" >&2; }

need() { command -v "$1" >/dev/null 2>&1 || { err "Comando '$1' nao encontrado."; exit 1; }; }

detect_cabo() {
  if [[ -n "$CABO" ]]; then return; fi
  if ip link show enx00e04c68001a >/dev/null 2>&1; then
    CABO="enx00e04c68001a"; return
  fi
  CABO="$(ip -o link show | awk -F': ' '$2 ~ /^enx/ {print $2; exit}')"
  if [[ -z "$CABO" ]]; then
    err "Nao achei o adaptador do cabo. Rode com: CABO=<interface> $0 $CMD"
    err "Interfaces disponiveis:"; ip -o link show | awk -F': ' '{print "  " $2}'
    exit 1
  fi
}

setup_host() {
  need nmcli
  detect_cabo
  info "Notebook: criando perfil '$PROFILE' na interface $CABO ($HOST_IP/24, NAT)"

  # Recria o perfil do zero (idempotente)
  if nmcli -g NAME connection show | grep -qx "$PROFILE"; then
    sudo nmcli connection delete "$PROFILE" >/dev/null
  fi

  sudo nmcli connection add type ethernet ifname "$CABO" con-name "$PROFILE" \
    ipv4.method shared ipv4.addresses "$HOST_IP/24" \
    ipv6.method ignore connection.autoconnect yes >/dev/null

  sudo nmcli connection up "$PROFILE" >/dev/null
  ok "Perfil ativo. Ele sobe sozinho sempre que o cabo for conectado."
  ip -4 -br addr show "$CABO" || true
  info "A internet do robo vem da conexao ativa do notebook (Wi-Fi, celular, outro cabo)."
  info "Para trocar de rede, basta trocar a conexao do notebook."
}

# Script que roda DENTRO do robo (com sudo)
robot_payload() {
cat << 'REMOTE'
#!/usr/bin/env bash
set -e
GW="$1"; ROBOT_IP="$2"; DNS="$3"

DEV="$(ip -o -4 addr show | awk -v ip="$ROBOT_IP" 'index($4, ip"/")==1 {print $2; exit}')"
if [[ -z "$DEV" ]]; then
  echo "[robo] Nenhuma interface com o IP $ROBOT_IP. Confira o ROBOT_IP." >&2
  exit 1
fi
echo "[robo] Interface do cabo: $DEV"

# Efeito imediato (temporario)
ip route replace default via "$GW" dev "$DEV" metric 100

# Persistente via NetworkManager
if command -v nmcli >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager; then
  CON="$(nmcli -g GENERAL.CONNECTION device show "$DEV" || true)"
  if [[ -n "$CON" && "$CON" != "--" ]]; then
    METHOD="$(nmcli -g ipv4.method connection show "$CON")"
    echo "[robo] Perfil: '$CON' (metodo: $METHOD)"
    if [[ "$METHOD" == "manual" ]]; then
      nmcli connection modify "$CON" ipv4.gateway "$GW" ipv4.dns "$DNS"
    else
      nmcli connection modify "$CON" ipv4.dns "$DNS"
    fi
    nmcli device reapply "$DEV" || true
    echo "[robo] Configuracao gravada no perfil (permanece apos reiniciar)."
  else
    echo "[robo] Sem perfil NetworkManager para $DEV." >&2
    NO_NM=1
  fi
else
  NO_NM=1
fi

if [[ "${NO_NM:-0}" == "1" ]]; then
  echo "[robo] ATENCAO: o robo nao usa NetworkManager para $DEV." >&2
  echo "[robo] A rota atual e temporaria. Grave de forma permanente em /etc/netplan/*.yaml:" >&2
  echo "         routes: [{to: default, via: $GW}]" >&2
  echo "         nameservers: {addresses: [${DNS// /, }]}" >&2
  echo "       e rode: sudo netplan apply" >&2
  # DNS temporario
  printf 'nameserver %s\n' $DNS > /etc/resolv.conf 2>/dev/null || true
fi

echo "[robo] Testando..."
ping -c 2 -W 3 8.8.8.8 >/dev/null && echo "[robo] ping 8.8.8.8 OK" || { echo "[robo] ping 8.8.8.8 FALHOU" >&2; exit 1; }
ping -c 2 -W 3 google.com >/dev/null && echo "[robo] DNS OK" || echo "[robo] DNS falhou (so o IP funciona)" >&2
REMOTE
}

setup_robot() {
  need ssh; need scp; need ssh-copy-id; need ssh-keygen
  info "Robo: conectando em $ROBOT_USER@$ROBOT_IP"

  if ! ping -c 1 -W 3 "$ROBOT_IP" >/dev/null 2>&1; then
    err "Robo nao responde em $ROBOT_IP. Ele esta ligado e o perfil '$PROFILE' esta ativo?"
    exit 1
  fi

  # Chave SSH (para nao pedir senha toda hora)
  if ! ls ~/.ssh/id_*.pub >/dev/null 2>&1; then
    info "Criando chave SSH ed25519..."
    ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519 >/dev/null
  fi
  if ! ssh "${SSH_OPTS[@]}" -o BatchMode=yes "$ROBOT_USER@$ROBOT_IP" true 2>/dev/null; then
    info "Enviando chave SSH ao robo (vai pedir a senha dele uma vez)..."
    ssh-copy-id "${SSH_OPTS[@]}" "$ROBOT_USER@$ROBOT_IP"
  fi

  local tmp; tmp="$(mktemp)"
  robot_payload > "$tmp"
  scp "${SSH_OPTS[@]}" -q "$tmp" "$ROBOT_USER@$ROBOT_IP:/tmp/g1-robot-net.sh"
  rm -f "$tmp"

  info "Aplicando configuracao no robo (pode pedir a senha do sudo dele)..."
  ssh -t "${SSH_OPTS[@]}" "$ROBOT_USER@$ROBOT_IP" \
    "sudo bash /tmp/g1-robot-net.sh '$HOST_IP' '$ROBOT_IP' '$DNS'; rm -f /tmp/g1-robot-net.sh"
  ok "Robo configurado."
}

status() {
  detect_cabo
  info "Notebook"
  nmcli -f NAME,DEVICE,STATE connection show --active | grep -E "NAME|$PROFILE" || echo "  perfil '$PROFILE' inativo"
  ip -4 -br addr show "$CABO" 2>/dev/null || true
  echo "  ip_forward = $(cat /proc/sys/net/ipv4/ip_forward)"
  info "Robo ($ROBOT_IP)"
  if ping -c 1 -W 2 "$ROBOT_IP" >/dev/null 2>&1; then
    ok "Robo responde"
    ssh "${SSH_OPTS[@]}" -o BatchMode=yes "$ROBOT_USER@$ROBOT_IP" \
      'ip route | grep default; ping -c 2 -W 3 8.8.8.8 >/dev/null && echo "internet OK" || echo "sem internet"' \
      2>/dev/null || echo "  (SSH sem chave: rode './g1-internet.sh robot')"
  else
    err "Robo nao responde"
  fi
}

remove() {
  need nmcli
  sudo nmcli connection delete "$PROFILE" && ok "Perfil '$PROFILE' removido."
}

CMD="${1:-help}"
case "$CMD" in
  install) setup_host; setup_robot ;;
  host)    setup_host ;;
  robot)   setup_robot ;;
  status)  status ;;
  remove)  remove ;;
  *) sed -n '2,19p' "$0" ;;
esac
