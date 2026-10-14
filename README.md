# G1-SSH
How to connect to G1 more easily

#!/bin/bash

# ==========================================
# CONFIGURAÇÃO DE REDES (Altere aqui se necessário)
# ==========================================
WIFI_IFACE="wlp1s0"          # Sua interface de rede Wi-Fi (verifique com 'ip a')
ETH_IFACE="enx00e04c68001a"  # Sua interface de rede cabeada/USB (verifique com 'ip a')
# ==========================================

echo "Ativando compartilhamento de internet para o robô G1..."

# Habilita o IP forwarding
sysctl -w net.ipv4.ip_forward=1

# Configura as regras do iptables (NAT)
iptables -t nat -A POSTROUTING -o "$WIFI_IFACE" -j MASQUERADE
iptables -A FORWARD -i "$ETH_IFACE" -o "$WIFI_IFACE" -j ACCEPT
iptables -A FORWARD -i "$WIFI_IFACE" -o "$ETH_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "Sucesso! Internet compartilhada de $WIFI_IFACE para $ETH_IFACE."

#!/bin/bash

# ==========================================
# CONFIGURAÇÃO DE REDES (Deve ser a mesma do ativador)
# ==========================================
WIFI_IFACE="wlp1s0"          # Sua interface de rede Wi-Fi
ETH_IFACE="enx00e04c68001a"  # Sua interface de rede cabeada/USB
# ==========================================

echo "Desativando compartilhamento de internet e limpando regras..."

# Remove as regras do iptables de forma segura
iptables -t nat -D POSTROUTING -o "$WIFI_IFACE" -j MASQUERADE 2>/dev/null
iptables -D FORWARD -i "$ETH_IFACE" -o "$WIFI_IFACE" -j ACCEPT 2>/dev/null
iptables -D FORWARD -i "$WIFI_IFACE" -o "$ETH_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null

# Desativa o IP forwarding
sysctl -w net.ipv4.ip_forward=0

echo "Compartilhamento desativado. Conexões livres!"

# Share Internet to Unitree G1 Robot

Scripts em Bash para compartilhar e desativar a conexão de internet (Wi-Fi) do computador host para o robô Unitree G1 via rede cabeada (Ethernet).

## ⚙️ Como Alterar as Redes
Antes de usar, abra os arquivos `share-to-robot.sh` e `stop-share.sh` e ajuste as variáveis no topo de cada arquivo de acordo com a sua máquina (você pode descobrir os nomes rodando o comando `ip a` no terminal):
* `WIFI_IFACE`: Nome da sua placa Wi-Fi (ex: `wlp1s0`).
* `ETH_IFACE`: Nome da sua placa de rede cabeada ou adaptador USB (ex: `enx00e04c68001a`).

## 🚀 Como Usar

### 1. Ativar o compartilhamento de internet para o robô:
```bash
sudo chmod +x share-to-robot.sh
sudo ./share-to-robot.sh

sudo chmod +x stop-share.sh
sudo ./stop-share.sh
