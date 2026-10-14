# G1 Internet Sharing

Scripts para compartilhar a internet de uma máquina Linux (base) com um robô **Unitree G1** via cabo Ethernet, usando NAT/Masquerade. Útil para atualizações, clonagem de repositórios ROS 2 e instalação de pacotes direto no robô.

```
Internet ── Wi-Fi ── [ Base Linux ] ── cabo Ethernet ── [ G1 ]
                     192.168.123.99                    192.168.123.164
```

## Arquivos

| Arquivo | Função |
|---|---|
| `setup_host.sh` | Na base: habilita IP forwarding e configura o `iptables` (idempotente, com `--undo`). |
| `setup_robot.sh` | No robô: define a base como gateway padrão e configura o DNS (8.8.8.8). |
| `share-to-robot.sh` | Script principal: configura a base e executa o `setup_robot.sh` no G1 via SSH. |

## Como usar

```bash
git clone <url-do-repositorio>
cd g1-internet-sharing
chmod +x *.sh
./share-to-robot.sh
```

Conecte o cabo Ethernet entre a base e o G1 antes de rodar.

### Configuração

Os valores padrão podem ser sobrescritos por variáveis de ambiente:

```bash
WIFI=wlan0 CABO=eth1 ROBOT_IP=192.168.123.164 ./share-to-robot.sh
```

| Variável | Padrão | Descrição |
|---|---|---|
| `WIFI` | `wlp1s0` | Interface com acesso à internet na base |
| `CABO` | `enx00e04c68001a` | Interface Ethernet ligada ao robô |
| `MEU_IP_CABO` | `192.168.123.99` | IP da base na rede do robô |
| `ROBOT_IP` | `192.168.123.164` | IP do G1 |
| `ROBOT_USER` | `unitree` | Usuário SSH no G1 |

Descubra os nomes das interfaces com `ip -br link`.

### Uso manual

```bash
./setup_host.sh wlp1s0 enx00e04c68001a          # ativa na base
./setup_host.sh wlp1s0 enx00e04c68001a --undo   # desativa e remove as regras

# dentro do G1:
./setup_robot.sh 192.168.123.99
```

## Observações

- As regras de `iptables` e o `ip_forward` **não persistem** após reiniciar a base. Para persistir as regras: `sudo apt install iptables-persistent && sudo netfilter-persistent save`.
- A rota e o DNS configurados no robô também são temporários (somem ao reiniciar).
- Requer `sudo` na base e no robô.
