# g1-internet-sharing

Compartilha a internet do notebook Linux com o **Unitree G1 EDU** via cabo Ethernet,
de forma **permanente** (continua funcionando depois de reiniciar o robo).

## Como funciona

- **Notebook:** cria um perfil NetworkManager (`g1-share`) no adaptador do cabo,
  com IP `192.168.123.99` e modo `shared` (NAT + DHCP). Sobe sozinho ao conectar o cabo.
- **Robo (PC2/Jetson, `192.168.123.164`):** o script entra por SSH e grava gateway
  e DNS no perfil de rede dele, entao a configuracao sobrevive a reboots.
- **Trocar de internet:** basta trocar a conexao do notebook (Wi-Fi, celular, outro cabo).
  O robo acompanha sem mudar nada.

## Requisitos

- Linux com NetworkManager (`nmcli`), `ssh`, `ssh-copy-id`
- Robo ligado e cabo conectado

## Uso

```bash
chmod +x g1-internet.sh
./g1-internet.sh install    # notebook + robo
./g1-internet.sh status     # verifica tudo
./g1-internet.sh remove     # remove o perfil do notebook
```

Outros comandos: `host` (so notebook) e `robot` (so robo).

### Variaveis opcionais

```bash
CABO=enx00e04c68001a ROBOT_USER=unitree ROBOT_IP=192.168.123.164 ./g1-internet.sh install
```

| Variavel     | Padrao             | Descricao                          |
|--------------|--------------------|------------------------------------|
| `CABO`       | auto-detecta `enx*`| interface do cabo no notebook      |
| `HOST_IP`    | `192.168.123.99`   | IP do notebook na rede do robo     |
| `ROBOT_IP`   | `192.168.123.164`  | IP do PC2 (Jetson)                 |
| `ROBOT_USER` | `unitree`          | usuario SSH                        |
| `DNS`        | `8.8.8.8 1.1.1.1`  | DNS do robo                        |
| `PROFILE`    | `g1-share`         | nome do perfil no notebook         |

## Observacoes

- Altere apenas o **PC2**. Nao mexa na rede do PC1 (controle de movimento).
- Se o robo nao usar NetworkManager, o script avisa e mostra o trecho de netplan para gravar manualmente.
- Se o `ping 8.8.8.8` funciona mas `google.com` nao, o problema e so DNS.
