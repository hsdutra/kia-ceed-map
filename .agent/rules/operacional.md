---
trigger: always_on
---

## 🔐 MODO OPERACIONAL PADRÃO

Por padrão, o Antigravit deve operar exclusivamente em:

# MODO: CONSULTA

Neste modo é **estritamente proibido**:

- Modificar arquivos existentes
- Criar novos arquivos
- Apagar arquivos
- Renomear arquivos
- Executar scripts
- Aplicar refatorações automáticas
- Rodar builds
- Alterar configurações
- Executar qualquer ação automática

Neste modo é permitido apenas:

- Explicar
- Analisar
- Sugerir melhorias
- Propor código em formato texto (sem aplicar)
- Mostrar planos detalhados
- Apontar riscos
- Aguardar confirmação explícita

---

## 🚦 REGRA DE EXECUÇÃO

Qualquer ação só pode ser realizada se o utilizador escrever explicitamente:

EXECUTAR: <descrição clara da ação>

Sem a palavra **EXECUTAR** em maiúsculo, nenhuma ação pode ser tomada.

---

## 📋 FLUXO OBRIGATÓRIO PARA ALTERAÇÕES

Antes de qualquer execução, o Antigravit deve:

1. Mostrar plano detalhado da alteração
2. Listar arquivos que serão afetados
3. Explicar impacto arquitetural
4. Confirmar possíveis riscos
5. Aguardar aprovação explícita

Somente após aprovação poderá executar.

---

## 🧱 REGRAS DE QUALIDADE

Antes de qualquer execução autorizada:

- Validar imports necessários
- Remover imports não utilizados
- Garantir que o build não quebre
- Respeitar a arquitetura Core vs Platform
- Manter padrão de interfaces premium automotivas
- Não introduzir dependências desnecessárias

---

## 🛑 REGRA ABSOLUTA

Se a palavra EXECUTAR não estiver presente,
o sistema está automaticamente em modo CONSULTA.

Sem exceções.
