# PASSO A PASSO: Implementação no Raspberry Pi (Node A)

Este guia orienta a configuração completa do Node A no Raspberry Pi para interagir com o Kia Ceed.

---

## 1. Preparação do Hardware

1.  **Ligar o CANable:** Ligue o CANable v2.0 Pro S numa das portas USB do Raspberry Pi.
2.  **Cablagem CAN:** Ligue os pinos **CAN High (H)** e **CAN Low (L)** ao barramento do veículo (ou Node B).
3.  **Terminação:** Garanta que existe uma resistência de 120 ohms no barramento. No CANable Pro S, ative o jumper interno para este fim.
4.  **Alimentação:** Utilize uma fonte de alimentação estável (mínimo 3A) para evitar erros de barramento CAN devidos a quebras de tensão.

---

## 2. Acesso Remoto (SSH)

Se o seu Raspberry Pi estiver sem monitor ("Headless"):

1.  **Habilitar SSH:**
    - No PC, abra o cartão SD do Raspberry.
    - Na partição `boot`, crie um ficheiro vazio chamado `ssh` (sem extensão).
2.  **Configurar Wi-Fi (Opcional):**
    - Crie um ficheiro `wpa_supplicant.conf` na partição `boot` com as suas credenciais.
3.  **Conetar via Terminal (Windows/Linux/Mac):**

    ```bash
    # Se souber o IP:
    ssh pi@192.168.x.x

    # Se usar o hostname padrão:
    ssh pi@raspberrypi.local
    ```

    - _Senha padrão (se não alterada):_ `raspberry`

---

## 3. Preparação do Sistema (OS)

1.  **Atualizar Repositórios:**
    ```bash
    sudo apt update && sudo apt upgrade -y
    ```
2.  **Instalar Ambiente de Execução:**
    ```bash
    sudo apt install python3 python3-pip python3-serial -y
    ```
3.  **Permissões de Hardware (Crítico):**
    O utilizador precisa de permissão para ler/escrever na porta serial (`/dev/ttyACM0`):
    ```bash
    sudo usermod -a -G dialout $USER
    ```
    _Nota: É necessário fazer Logout e Login (ou reboot) para que a permissão seja aplicada._

---

## 4. Instalação do Software

1.  **Criar Diretório de Trabalho:**
    ```bash
    mkdir -p ~/KiaCeedCAN/RaspberryProject
    cd ~/KiaCeedCAN/RaspberryProject
    ```
2.  **Transferir Ficheiros:**
    Utilize `scp` ou FileZilla para copiar a pasta `RaspberryProject` para o Raspberry Pi.
    - _Nota: Os ficheiros `.ps1` e a pasta `logs` já não são necessários no Raspberry, pois os dados foram centralizados no `config.py`._
    ```bash
    # Exemplo via terminal Windows:
    scp -r .\RaspberryProject\* pi@raspberrypi.local:~/KiaCeedCAN/RaspberryProject/
    ```

---

## 5. Configuração e Execução

1.  **Validar Auto-Configuração:**
    O programa tentará ler `MANUAL_TECNICO_V3.md` e logs na pasta acima (`..`). Certifique-se de que a estrutura de pastas foi mantida.
2.  **Modularização:** Edite `config.py` para ativar/desativar o que deseja:
    ```python
    ENABLE_RADIO_EMISSION = True
    ENABLE_CLOCK_EMISSION = True
    ```
3.  **Instalar Dependências:**

    ```bash
    # Se estiver a usar o ambiente virtual (venv) como no seu caso:
    pip install pyserial

    # Caso contrário (sistema global):
    pip3 install pyserial
    ```

4.  **Executar Manualmente:**
    ```bash
    python3 main.py
    ```

---

## 6. Automação via Systemd (Serviço)

Para que o programa inicie sozinho ao ligar o Raspberry:

1.  **Criar Ficheiro de Serviço:**
    ```bash
    sudo nano /etc/systemd/system/kiacan.service
    ```
2.  **Configuração Sugerida:**

    ```ini
    [Unit]
    Description=Kia Ceed CAN Simulator Node A
    After=network.target

    [Service]
    Type=simple
    User=pi
    WorkingDirectory=/home/pi/KiaCeedCAN/RaspberryProject
    ExecStart=/usr/bin/python3 main.py
    Restart=always
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
    ```

3.  **Comandos de Gestão:**
    ```bash
    sudo systemctl daemon-reload
    sudo systemctl enable kiacan.service   # Ativa no boot
    sudo systemctl start kiacan.service    # Inicia agora
    sudo systemctl status kiacan.service   # Verifica saúde
    sudo journalctl -u kiacan.service -f   # Vê os logs em tempo real
    ```

---

## 7. Notas Importantes (Troubleshooting)

### Sincronização de Tempo

Se o relógio do Raspberry Pi voltar à hora real mesmo após um comando CAN:

1.  **Desativar Sincronismo de Rede (NTP):** O Linux tenta corrigir a hora via internet. Desative com:
    ```bash
    sudo timedatectl set-ntp false
    ```
2.  **Permissões:** Garanta que corre o programa com `sudo python3 main.py`.
