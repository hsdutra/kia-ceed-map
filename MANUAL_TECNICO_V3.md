# MANUAL TÉCNICO CAN - KIA CEED 2015 (Radio & Media)
**Versão:** 3.0 (Consolidado: Estabilidade, Visibilidade e Tempo)
**Autor:** Henrique Dutra / Antigravity AI
**Projeto:** CAN PRO Sync

---

## 1. Configuração do Barramento
- **Velocidade:** 100 kbps (Lawicel: `S3`)
- **Interface:** CANable v2.0 Pro (SLCAN)
- **IDs:** Standard (11 bits)

---

## 2. Visibilidade e Estabilidade das Abas (Cluster)
Para que os ícones de **Mídia (Nota)** e **GPS (Seta)** apareçam e funcionem sem travar, é necessário injetar um conjunto de IDs continuamente.

### 2.1 Controle de Presença (Menu Visibility)
Estes IDs dizem ao cluster quais abas mostrar na lista de menus:
| ID CAN | Valor (Hex) | Descrição |
| :--- | :--- | :--- |
| **0x169** | `40` (Audio), `80` (Nav), `C0` (Ambos) | Habilita os slots de apps no menu. |
| **0x1EB** | `01` (Audio), `02` (Nav), `03` (Ambos) | Confirma a presença dos módulos. |
| **0x44D** | `40 02 00 00 00 00 FF FF` | Indica "Sistema de Áudio Ligado". |

### 2.2 Bundle de Estabilidade (No Loading)
Para evitar que as abas fiquem presas em "Loading", envie estes IDs a **10 Hz**:
| ID CAN | Payload Recomendado | Função |
| :--- | :--- | :--- |
| **0x100** | `62 00 00 04 00 00 00 00` | Heartbeat Vital do Rádio. |
| **0x114** | `[Modo] 60 00 01 00 00 [HH] [LL]` | Status de Frequência/Modo (Ver seção 3). |
| **0x115** | `08 00 00 00 00 00 00 00` | Heartbeat Auxiliar de Áudio. |
| **0x506** | `FF FF FF FF FF FF 0F 00` | Status de Configuração do Cluster. |
| **0x120** | `00 00 00 00` | Heartbeat Vital de Navegação (GPS). |

---

## 3. Controle de Fonte e Frequência (ID 0x114)
### 3.1 Prefixos de Modo
- **0x11**: Modo Rádio FM
- **0x14**: Modo Rádio AM
- **0x08**: Modo Bluetooth / Mídia

### 3.2 Cálculos de Bytes HH LL
- **FM (MHz)**: `Raw = (MHz - 87.5) * 320`  
- **AM (KHz)**: `Raw = (KHz - 517) * 16 / 9`

---

## 4. Display de Texto (ISO-TP)
### 4.1 Rádio (FM/AM) - ID 0x4E8
- 16 caracteres UTF-16LE fixos.
- Intervalo de envio recomendado: 400ms.

### 4.2 Bluetooth/Mídia - ID 0x485
- **Regra:** O payload deve ser precedido pelo byte **`0x03`**.
- Formato: `First Frame (10 [Len] 03 [UTF...])`.

---

## 5. Sincronização de Tempo (Relógio)
O cluster KIA CEED 2015 sincroniza o tempo via barramento CAN utilizando dois IDs principais.

| ID CAN | Escopo | Bytes Principais |
| :--- | :--- | :--- |
| **0x5E2** | Master Time | `[HH] [MM] [SS] [DD] [MM*4+1] [YY-2000]` |
| **0x12F** | Sync Time | Similar ao 0x5E2, usado para confirmação. |

**Cálculo do Mês:**
`Byte_Mês = (Mês_Real * 4) + 1` (Ex: Janeiro = 5, Dezembro = 49).

---

*Este manual é o resultado consolidado de engenharia reversa e testes reais realizados. Última atualização em 22/02/2026.*
