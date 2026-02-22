# 📡 Estrutura do Projeto (Guia para Antigravit)

Este documento define a organização oficial do projeto e as regras que devem ser seguidas pelo Antigravit ao analisar, modificar ou gerar código.

---

# 📁 Estrutura de Pastas

```
/imagens
    /fm presets
    /prints

/logs

/simulador

MANUAL_TECNICO_V2.md
```

---

# 📂 imagens/
Contém material visual utilizado para análise comportamental do rádio original.

## 📁 imagens/fm presets
Contém imagens das estações FM mapeadas manualmente.
**Regra:** Ao analisar mudanças de estação FM, considerar apenas transições entre presets mapeados para evitar ruído.

## 📁 imagens/prints
Contém prints do ecrã original do carro (AM/FM/Bluetooth).
**Regra:** Sempre validar se a mudança visual corresponde a uma mudança real de frame CAN.

---

# 📂 logs/
Pasta destinada aos logs exportados do SavvyCAN (.csv).
**Regra:** Sempre filtrar ruído antes de tirar conclusões. Priorizar análise por diferença de modo e estabilidade estatística.

---

# 📂 simulador/
Pasta principal do simulador funcional (PowerShell).
**Regra:** Nunca alterar mapeamentos estáveis sem validação por log comparativo.

---

# 📄 MANUAL_TECNICO_V2.md
Documento mestre consolidado com:
* IDs mapeados (0x114, 0x4E8, 0x485)
* Fórmulas de calibração AM/FM
* Protocolos ISO-TP e timing

**Regra:** Antes de criar nova hipótese ou modificar mapeamentos, consultar obrigatoriamente este manual.

---

# 🔬 Diretrizes Técnicas Obrigatórias

1. **Sempre validar:** Se o ID é constante ou variável e se a mudança ocorre em RX ou TX.
2. **Evitar conclusões precipitadas:** Confirmar mudanças de bytes com logs comparativos e prints visuais.
3. **Padrão de Análise:** Isolar evento -> Filtrar IDs repetitivos -> Validar consistência -> Confirmar com print visual.

---

# 🎯 Objetivo Final do Projeto
Criar uma simulação fiel do comportamento CAN do rádio original do Kia Ceed 2015, permitindo que uma central Android se comporte exatamente como o rádio OEM em termos de comunicação com o painel (cluster).
