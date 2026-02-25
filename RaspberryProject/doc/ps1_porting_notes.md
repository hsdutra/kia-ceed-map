# Porting Notes: PowerShell para Python (Kia Ceed CAN)

Este documento descreve como a lógica dos scripts `.ps1` originais (Windows) foi portada para o ambiente Raspberry Pi (Python).

## 1. Comunicação Serial (SLCAN)

- **PowerShell:** Utilizava `System.IO.Ports.SerialPort`.
- **Python:** Utiliza a biblioteca `pyserial`. A classe `CanRuntime` replica o protocolo Lawicel (`C`, `S3`, `O`, `t...`) de forma transparente.

## 2. Motor de Transmissão (Timing)

No PowerShell, usava-se `Start-Sleep -Milliseconds`. Em Python (`tx_engine.py`), implementamos um loop de alta precisão baseado em `time.time()` para garantir que os heartbeats de 10Hz não sofram deriva (drift) cumulativa, o que é crucial para manter os ícones do cluster acesos.

## 3. ISO-TP e UTF-16LE

A lógica de fragmentação de texto (ID `0x4E8` e `0x485`) foi portada fielmente:

- **Radio FM/AM:** Envia o texto em UTF-16LE (Little Endian).
- **Bluetooth:** Adiciona o prefixo `0x03` antes da carga útil, conforme detetado nos testes do `fake_radio_menu.ps1`.

## 4. Dual-Bus Time Sync

A sincronização de tempo (`fake_time_menu.ps1`) foi movida para uma função dedicada no `TxEngine` que injeta os IDs `0x5E2` e `0x12F` simultaneamente a casa 1 segundo, usando o relógio de sistema do Raspberry.

## 5. Auto-Introspecção

Diferente dos scripts originais que tinham valores _hardcoded_ (`$Port = "COM3"`), o ficheiro `project_introspector.py` analisa os metadados do projeto para encontrar o bitrate correto sem intervenção manual.
