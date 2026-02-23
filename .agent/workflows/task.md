---
description: Regras
---

# 📡 CAN Radio Simulation – Guia Oficial do Projeto

Este documento define a estrutura oficial do projeto, as regras técnicas obrigatórias e o workflow que deve ser seguido ao analisar, modificar ou gerar código. Este ficheiro é a referência estrutural e técnica principal.

---

# 📁 Estrutura Oficial de Pastas

- `/imagens` – Capturas do rádio OEM e presets.
- `/logs` – Capturas brutas do barramento CAN.
- `/simulador` – Implementação funcional (PowerShell/Scripts).
- `/docs/manual/` – Histórico de versões do manual técnico.
- `MANUAL_TECNICO.md` – Fonte de Verdade (Raiz).
- `README.md` – Visão geral do repositório.

---

# 📂 imagens/

Contém material visual utilizado para análise comportamental do rádio original.

## 📁 fm_presets

Estações FM mapeadas manualmente.

- **Regra**: Ao analisar mudanças de frequência, considerar apenas transições entre presets mapeados para eliminar ruído estatístico.

## 📁 prints

Capturas do ecrã original (AM / FM / Bluetooth / GPS).

- **Regra**: Sempre validar se a mudança visual no ecrã OEM corresponde a uma alteração detectável no frame CAN.

---

# 📂 logs/

Repositório de logs exportados do SavvyCAN (`.csv`).

## 📋 Regras de Nomenclatura

Os arquivos devem seguir o padrão: `AAAA-MM-DD_[MODO]_[EVENTO].csv`
_Exemplo: 2025-02-23_FM_PRESET_CHANGE_01.csv_

## 📋 Regras de Análise

- Filtrar ruído constante antes de tirar conclusões.
- Confirmar se a alteração ocorre em RX ou TX.
- **Identificar Cycle Time**: Determinar a frequência de repetição do ID (ex: 100ms, 500ms).
- Nunca concluir com base em evento isolado; aplicar validação de diferença de modo.

---

# 📂 simulador/

Pasta principal do simulador funcional.

**Regra Crítica**: Nunca alterar mapeamentos considerados **ESTÁVEIS** sem:

1. Log comparativo entre a versão anterior e a nova.
2. Confirmação de que o tempo de ciclo (timing) está correto.
3. Validação visual no cluster/painel.

---

# 📄 MANUAL_TECNICO.md (Fonte de Verdade)

Este é o manual oficial, único e vigente. Localizado na raiz do projeto.

## 🛠️ Classificação de Maturidade dos IDs

Todo ID mapeado deve receber um status:

- **HIPÓTESE**: ID identificado, comportamento observado mas não totalmente isolado.
- **ESTÁVEL**: ID com comportamento consistente, fórmulas validadas e timing preciso.
- **LEGACY**: ID que foi utilizado anteriormente mas provado incorreto ou substituído.

## 📚 Versionamento

- Versões anteriores (V1, V2, etc.) devem ser movidas para `/docs/manual/`.
- O manual na raiz é sempre a consolidação de todas as hipóteses validadas.

---

# 🔬 Diretrizes Técnicas Obrigatórias

1. **Constância**: Validar se o ID é constante (Heartbeat) ou originado por evento.
2. **Direção**: Confirmar se a alteração ocorre em RX ou TX.
3. **Isolamento**: Isolar o byte específico que sofre alteração antes de analisar o payload.
4. **Timing**: Documentar o tempo de ciclo para evitar "flickering" na simulação.
5. **Consistência**: Validar o comportamento em pelo menos 3 capturas diferentes.

---

# 🧪 Padrão Oficial de Análise (Workflow)

1. **Isolar Evento** (Acionar botão/função específica).
2. **Filtrar Ruído** (Remover IDs de tráfego comum).
3. **Identificar IDs** (Localizar candidatos e medir Cycle Time).
4. **Validar Consistência** (Repetir o evento e confirmar o padrão).
5. **Teste de Regressão** (Garantir que funções estáveis não foram quebradas).
6. **Comparar c/ Manual** (Verificar se entra em conflito com mapeamentos existentes).
7. **Documentar no Manual** (Atualizar status de Hipótese para Estável).

---

# 🎯 Objetivo Final do Projeto

Criar uma simulação fiel do comportamento CAN do rádio original do Kia Ceed 2015, permitindo que uma central Android reproduza exatamente o comportamento OEM na comunicação com o painel (cluster), com foco em precisão, estabilidade e evidência técnica.
