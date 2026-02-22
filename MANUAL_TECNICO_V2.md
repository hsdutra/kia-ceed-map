# MANUAL TÉCNICO CAN - KIA CEED 2015 (Radio & Media)
**Versão:** 2.0 (Atualizada com BT e Calibração AM)
**Autor:** Henrique Dutra / Antigravity AI
**Projeto:** CAN PRO Sync

---

## 1. Configuração do Barramento
- **Velocidade:** 100 kbps (Lawicel: `S3`)
- **Interface:** CANable v2.0 Pro (SLCAN)
- **IDs:** Standard (11 bits)
- **DLC:** 8 bytes

---

## 2. Controle de Fonte e Frequência (ID 0x114)
Este ID deve ser enviado continuamente a **10 Hz** para manter o display do cluster ativo.

### 2.1 Estrutura do Payload
`[Prefixo] 60 00 01 00 00 [Byte HH] [Byte LL]`

### 2.2 Prefixos de Modo
- **0x11**: Modo Rádio FM
- **0x14**: Modo Rádio AM
- **0x08**: Modo Bluetooth / Mídia

### 2.3 Cálculos de Frequência (Bytes HH LL)
- **FM (MHz)**:
  `Raw = (MHz - 87.5) * 320`  
  *(Ex: 93.6 MHz -> 0x07A0)*
- **AM (KHz)**:
  `Raw = (KHz - 517) * 1.7777` (ou `* 16 / 9`)  
  *(Fórmula calibrada para compensar o offset do cluster Kia)*

---

## 3. Display de Texto (Nomes de Estações e Músicas)
O cluster utiliza o protocolo **ISO-TP** (Multi-frame) para receber textos em **UTF-16LE**.

### 3.1 Modo Rádio (FM/AM) - ID 0x4E8
- **Tamanho:** Fixo em 16 caracteres (32 bytes).
- **Padding:** Preencher com espaços (`0x20 0x00`) até completar 32 bytes.
- **Protocolo:** FF (`10 20 ...`), seguido por CFs (`21...`, `22...`).

### 3.2 Modo Bluetooth/Mídia (BT) - ID 0x485
- **Diferencial:** O payload do texto deve ser precedido pelo byte **`0x03`**.
- **Tamanho:** Suporta comprimentos variáveis (pode ser maior que 16 caracteres).
- **Protocolo:** FF (`10 [Len] 03 [UTF...]`).

---

## 4. Resumo de IDs

| ID CAN | Função | Protocolo | Intervalo |
| :--- | :--- | :--- | :--- |
| **0x114** | Frequência e Modo | Cíclico | 100 ms |
| **0x4E8** | Nome da Estação (FM/AM) | ISO-TP | 400 ms |
| **0x485** | Metadados de Mídia (BT) | ISO-TP (+0x03) | 400 ms |
| **0x12F** | Estado Interno/Presets | Cíclico | Evento |

---

## 5. Exemplo de Frame ISO-TP (Manual)
Para enviar o nome "**CITY FM**" no ID 0x4E8:
1. **UTF-16LE:** `43 00 49 00 54 00 59 00 20 00 46 00 4D 00 20 00` ... (até 32 bytes)
2. **First Frame:** `10 20 43 00 49 00 44 00` (Envia os primeiros 6 bytes)
3. **Consecutive Frames:** `21 ...`, `22 ...` (Envia o restante)

---
*Este manual foi gerado com base em engenharia reversa de logs do rádio original e testes de calibração em tempo real.*
