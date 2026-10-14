mkdir -p ~/g1-internet-sharing
cd ~/g1-internet-sharing

cat << 'EOF' > setup_host.sh
#!/bin/bash
# Uso: ./setup_host.sh <interface_wifi> <interface_cabo>
# Exemplo: ./setup_host.sh wlp1s0 enx00e04c68001a

INTERNET_IFACE=${1:-wlp1s0}
ROBOT_IFACE=${2:-enx00e04c68001a}

echo "==========================================="
echo " Configurando Base para Roteamento NAT"
echo " Wi-Fi: $INTERNET_IFACE \vert{} Cabo:$ROBOT_IFACE"
echo "==========================================="

sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -o $INTERNET_IFACE -j MASQUERADE
sudo iptables -A FORWARD -i $ROBOT_IFACE -o$INTERNET_IFACE -j ACCEPT
sudo iptables -A FORWARD -i $INTERNET_IFACE -o$ROBOT_IFACE -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "Roteamento ativado na base!"
echo "Nota: Para salvar permanentemente, rode 'sudo netfilter-persistent save'"
EOF

cat << 'EOF' > setup_robot.sh
#!/bin/bash
# Uso: ./setup_robot.sh <ip_da_base_no_cabo>
# Exemplo: ./setup_robot.sh 192.168.123.99

HOST_IP=${1:-192.168.123.99}

echo "Configurando G1 para usar $HOST_IP como gateway..."

sudo ip route add default via $HOST_IP
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null

echo "Testando a conexão com a internet..."
ping -c 4 8.8.8.8

echo "Internet configurada com sucesso no G1!"
EOF

cat << 'EOF' > share-to-robot.sh
#!/bin/bash
# Automação completa: Configura a base e envia os comandos via SSH para o G1

WIFI="wlp1s0"
CABO="enx00e04c68001a"
MEU_IP_CABO="192.168.123.99"
ROBOT_IP="192.168.123.164" 
ROBOT_USER="unitree"

echo "1. Configurando roteamento na máquina local..."
sudo ./setup_host.sh $WIFI$CABO

echo "2. Copiando script de rede para o G1 ($ROBOT_IP)..."
scp setup_robot.sh $ROBOT_USER@$ROBOT_IP:/home/$ROBOT_USER/

echo "3. Executando configuração dentro do G1..."
ssh $ROBOT_USER@$ROBOT_IP "chmod +x setup_robot.sh && sudo ./setup_robot.sh $MEU_IP_CABO"

echo "==========================================="
echo " Processo finalizado! G1 online."
echo "==========================================="
EOF

cat << 'EOF' > README.md
# G1 Internet Sharing

Scripts para roteamento automático de internet (NAT/Masquerade) de uma base Linux para robôs Unitree G1 via cabo Ethernet. Ideal para atualizações, clonagem de repositórios ROS 2 e instalação de pacotes diretamente no hardware do robô.

## Arquivos
* `setup_host.sh`: Habilita o IP Forwarding e configura o iptables na máquina base.
* `setup_robot.sh`: Define a base como gateway e configura o DNS (8.8.8.8) dentro do robô.
* `share-to-robot.sh`: Script principal que automatiza todo o processo via SSH.

## Como Usar
1. Clone o repositório na sua máquina base.
2. Dê permissão de execução: `chmod +x *.sh`
3. Conecte o cabo Ethernet entre a base e o G1 e rode: `./share-to-robot.sh`
EOF

chmod +x *.sh
echo "Arquivos criados com sucesso na pasta ~/g1-internet-sharing"
ls -la
