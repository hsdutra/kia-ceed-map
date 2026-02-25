# KIA CEED 2015 - CAN Node A (Raspberry Pi)

Este projeto simula o comportamento do rádio e do relógio do Kia Ceed via barramento CAN, utilizando um CANable v2.0 Pro S.

## Pré-requisitos (Raspberry Pi)

1. **Python 3.x** e pip.
2. **Dependências:**
   ```bash
   pip install pyserial
   ```

## Estrutura do Projeto

- `main.py`: Ponto de entrada.
- `config.py`: Configurações centralizadas e toggles (RADIO/CLOCK).
- `project_introspector.py`: Deteta automaticamente bitrate e interface analisando o projeto.
- `tx_engine.py`: Motor de envio (Heartbeats, ISO-TP, Time Sync).

## Como Executar

Simplesmente execute:

```bash
python3 main.py
```

O programa irá:

1. Ler os manuais e logs do diretório pai para detetar bitrate (100 kbps).
2. Tentar abrir o CANable em `/dev/ttyACM0` (Heurística Raspberry).
3. Iniciar a emissão de dados conforme configurado em `config.py`.

## Configuração Centralizada

Edite o ficheiro `config.py` para:

- Ativar/Desativar módulos: `ENABLE_RADIO_EMISSION` / `ENABLE_CLOCK_EMISSION`.
- Forçar porta ou bitrate: Altere `OVERRIDE_PORT` ou `OVERRIDE_BITRATE`.
