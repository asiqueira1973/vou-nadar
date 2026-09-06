# Vou Nadar — Especificação de Software (SDD)

App de natação para iPhone e Apple Watch. **Produto novo, sem nenhuma ligação com o Swim Builder** — repositório próprio, bundle próprio, ficha própria na App Store, sem migração de dados e sem código compartilhado.

| | |
|---|---|
| **Versão do documento** | 1.1 |
| **Responsável de produto** | Alexandre Siqueira (Dab Lab) |
| **Status** | rascunho — aguardando revisão da seção 24 |
| **Data** | 06/09/2026 |
| **Plataformas** | iOS 18.0+ e watchOS 11.0+ |
| **Consome este documento** | Claude Code, em repositório novo e vazio |

---

## Como usar este documento

Este é o spec completo de um produto novo. Não há código anterior a respeitar, não há usuário instalado, não há compatibilidade a manter. Isso é liberdade: o modelo de dados nasce já com o que o produto precisa, em vez de ser espremido numa migração.

Três avisos antes da primeira linha de código:

1. **Revise a seção 24 (Assunções declaradas).** Assunção não revisada vira verdade no minuto em que o agente começa a implementar.
2. **Onde o agente cruzar com um item da seção 25 (Perguntas abertas), ele pergunta — não assume.**
3. **A relação com o Swim Builder é de cópia única, não de dependência.** O arquivo `catalogo_exercicios.json` é copiado uma vez do Swim Builder e passa a viver aqui com vida própria. Não há package compartilhado, não há submódulo, não há sincronização. Os dois apps vão divergir com o tempo, e isso é a decisão — não um efeito colateral. Ver 4.4.

A numeração das seções é estável e será referenciada em conversas futuras ("regra 11.4", "épico 8.8"). Não renumere.

---

## 0. Princípios não-negociáveis

| # | Princípio | O que significa na prática |
|---|---|---|
| 0.1 | **A água manda** | Com Water Lock ligado o Apple Watch **ignora toque na tela**, e ele liga sozinho ao iniciar um treino aquático. Nenhuma ação obrigatória pode depender do dedo entre o início e o fim do treino. Qualquer fluxo que precise de um toque dentro d'água está errado por construção. |
| 0.2 | **O treino é um programa, não uma sugestão** | Todo bloco sai com descanso definido. É exatamente isso que separa este app de um gerador de lista: sem tempo de descanso não existe tela de borda, não existe contagem regressiva e não existe execução guiada. |
| 0.3 | **A borda é o contexto de uso** | Molhado, sem óculos, com 20 segundos de parada. Uma informação em destaque por tela, tipografia grande, contraste alto. Legibilidade vence densidade em toda decisão. |
| 0.4 | **Zero backend, zero custo recorrente** | Nenhuma funcionalidade de treino depende de rede. Sem conta, sem servidor, sem SDK de terceiro. Catálogo muda por release da App Store. Exceção única e declarada: comprar e restaurar falam com a App Store. |
| 0.5 | **O relógio não depende do telefone** | Gerar, executar, encerrar e gravar funcionam com o iPhone desligado, longe e sem internet. O iPhone é conforto, nunca requisito. |
| 0.6 | **O treino salvo é imutável** | Um treino guardado hoje abre igual daqui a dois anos, com os mesmos exercícios e os mesmos descansos, mesmo que o catálogo ou a tabela de descanso mudem numa release futura. Isso obriga snapshot, não referência. |
| 0.7 | **Simplicidade antes de complexidade prematura** | Um usuário-alvo e zero base instalada. Sem camada de sync genérica, sem motor de regras configurável, sem abstração para escala que não existe. Código legível ganha de código genérico. |

---

## 1. Visão e problema

O nadador amador de piscina sabe nadar, mas não sabe montar treino. Quando encontra um treino pronto — num app, num papel, num grupo de WhatsApp — esbarra no problema seguinte: **o treino fica no celular, dentro do armário, e ele entra na água sozinho.** Na borda, entre séries, o que ele precisa saber é quanto falta de descanso e o que vem agora. Nenhuma dessas duas informações está no pulso dele.

O Vou Nadar monta o treino no iPhone e o executa no Apple Watch. O relógio mostra a série atual, conta o descanso regressivamente entre as repetições, avisa por vibração quando é hora de sair, e ao final grava o treino no app Saúde com a distância que foi realmente nadada.

**Anti-escopo — o que o Vou Nadar não é:**

- **Não é treinador.** Não prescreve periodização, não avalia técnica, não mede evolução, não dá feedback de desempenho.
- **Não é rede social.** Sem perfil, sem seguidor, sem ranking, sem desafio, sem feed.
- **Não é app de águas abertas.** O v1 é exclusivamente piscina — o descanso e o avanço dependem de volta contada, que só existe em raia.
- **Não é plataforma.** Nenhuma versão prevista introduz backend, conta ou servidor.
- **Não é o Swim Builder e não conversa com ele.** Não importa treino, não migra dado, não compartilha assinatura nem compra. Quem tem os dois tem dois apps separados.

---

## 2. Personas e cenários de uso

**Persona única: o nadador amador com rotina.** Nada de 2 a 4 vezes por semana em piscina de clube, academia ou condomínio. Consegue ler `4×50 com 20s` e executar. Não é federado, não tem treinador, não sabe o próprio pace e não quer saber. Já tem Apple Watch — é o público do portfólio com maior penetração do aparelho.

**O momento que define a arquitetura inteira.** Ele terminou o terceiro dos quatro 100 metros. Está na borda, respirando forte, óculos embaçados, touca escorregando. Levanta o pulso. Precisa de duas coisas, nessa ordem: **quanto falta pra sair** e **o que é a próxima**. Não pode tocar na tela — o Water Lock está ligado. Não tem paciência pra procurar. Tem cerca de dois segundos de atenção.

Toda a tela de execução (épico 8.8) é desenhada para esse instante. O resto do app existe para chegar até ele.

**Cenário secundário: o vestiário sem sinal.** Onde o treino é escolhido ou gerado, com o dedo seco e pressa. Precisa caber em três toques.

---

## 3. Escopo do MVP

### 3.1 Dentro

- Catálogo de 226 exercícios embarcado, copiado do Swim Builder (ver 4.4).
- Tabela de descanso derivada de distância, intensidade e modo, com ajuste global do usuário.
- Geração de treino no iPhone: faixa de distância, equipamento, educativos e pernada.
- Configuração de piscina (comprimento da raia) — **obrigatória, e antes de gerar**, não só antes de nadar (ver 11.3).
- Favoritar, listar e apagar treinos no iPhone.
- Copiar o treino como texto para a área de transferência, pronto para colar no WhatsApp (seção 14).
- Sincronização iPhone → Watch de favoritos, preferências, piscina e direito de compra.
- Geração de treino no próprio relógio, sem iPhone.
- Execução guiada no relógio com `HKWorkoutSession` de natação em piscina: avanço por repetição, contagem regressiva de descanso, háptico.
- Gravação do `HKWorkout` ao final.
- Histórico e volume semanal no iPhone, lidos do HealthKit.
- Paywall StoreKit 2, compra única.
- Complication mínima.

### 3.2 Fora

| Item | Destino | Motivo / dependência |
|---|---|---|
| Intervalo de saída (*sai a cada 1:20*) | **v2** (28.1) | Decisão do v1 é descanso fixo. Intervalo de saída exige que o nadador conheça o próprio pace, o que a persona não tem |
| Pace base e tempo estimado do treino | **v2** (28.2) | Depende de calibragem com dados reais; sozinho é um épico |
| Editar o descanso bloco a bloco | **v2** (28.3) | O v1 confia na tabela. Se ela errar na prática, corrige-se a tabela numa release, não a UI |
| Editar o treino exercício por exercício | **Descartado** | Viola o princípio 0.2 — treino montado à mão perde a garantia de estrutura. Se o usuário quer montar, o produto é outro |
| Outros nados (costas, peito, borboleta, medley) | **v2** (28.4) | O catálogo copiado é 100% crawl. Depende de produzir conteúdo |
| Águas abertas | **Descartado no v1**, reavaliar (28.5) | Sem raia não há volta contada, e sem volta não há descanso nem avanço. É outro produto |
| Jardas | **Descartado** | Público brasileiro, piscina métrica. Não existe caso de uso |
| Sincronização por iCloud (CloudKit) | **v2** (28.6) | Contradiz 0.7 enquanto houver um aparelho só em uso real |
| Compartilhar treino em **imagem** | **Descartado** | É o território do Swim Builder. Duplicar aqui só criaria confusão entre os dois produtos. Copiar como **texto** entra no v1 (seção 14) e resolve o caso real — mandar no WhatsApp |
| iPad | **Descartado** | Ninguém leva iPad para a borda |
| Inglês | **Descartado** | Público brasileiro. A arquitetura fica pronta (`Localizable.xcstrings`, zero string em `View`), o conteúdo não |

---

## 4. Arquitetura

### 4.1 Stack

| Camada | Escolha | Observação |
|---|---|---|
| Linguagem | Swift 6, concorrência estrita | `SWIFT_STRICT_CONCURRENCY: complete`, warning como erro |
| UI | SwiftUI | |
| Persistência | SwiftData, **um store por aparelho** | Sem CloudKit no v1 |
| iOS | 18.0+ | iPhone apenas, retrato apenas |
| watchOS | 11.0+ | Series 6 e SE 2ª geração em diante |
| Saúde | HealthKit — `HKWorkoutSession` + `HKLiveWorkoutBuilder` | Só no target watchOS; o iPhone só lê |
| Sincronização | WatchConnectivity (`WCSession`) | Só iPhone → Watch (ver 0.7 e regra 11.12) |
| Compra | StoreKit 2, não-consumível | |
| Geração do projeto | **XcodeGen** (`project.yml`) | O `.xcodeproj` **não** é versionado |
| Dependências de terceiro | **nenhuma** | Zero SPM externo é critério de aceite (8.1) |
| Backend / rede | **nenhum** | Exceto App Store para compra |

### 4.2 Estrutura do repositório

```
vou-nadar/
├── project.yml                    ← fonte de verdade do build (XcodeGen)
├── VouNadar.xcconfig
├── CLAUDE.md
├── DOCUMENTACAO-TECNICA.md
├── README.md
├── spec-vou-nadar.md
├── modelo-vou-nadar.dbml
├── VouNadar/                      ← target iOS
│   ├── App/
│   ├── Features/
│   │   ├── Home/                  (gerar treino)
│   │   ├── Favorites/
│   │   ├── WorkoutDetail/
│   │   ├── History/
│   │   ├── Settings/
│   │   └── Paywall/
│   ├── Data/
│   │   ├── Catalog/               (DTOs + CatalogStore)
│   │   ├── Enums/
│   │   ├── Models/                (entidades SwiftData)
│   │   ├── Repositories/
│   │   └── Schema/                (versionamento + plano de migração)
│   ├── Domain/
│   │   ├── Generation/            (WorkoutGenerator, função pura)
│   │   └── Rest/                  (tabela de descanso, função pura)
│   ├── Connectivity/
│   ├── DesignSystem/
│   └── Resources/                 (catalogo_exercicios.json, tipos_equipamento.json)
├── VouNadarWatch/                 ← target watchOS
│   ├── App/
│   ├── Features/
│   │   ├── Home/
│   │   ├── Generate/
│   │   ├── Favorites/
│   │   ├── Preview/
│   │   ├── PoolSettings/
│   │   └── Session/               (execução — épico 8.8)
│   ├── Connectivity/
│   ├── Health/
│   ├── Storage/
│   └── DesignSystem/
├── VouNadarWatchComplication/     ← extensão WidgetKit
└── VouNadarTests/
```

**Compartilhamento entre targets.** Não há Swift Package. `Domain/`, `Data/Catalog/`, `Data/Enums/` e `Data/Models/` são declarados como fontes **dos dois targets** no `project.yml`. É a solução mais simples que funciona (princípio 0.7) e evita a cerimônia de um package local num projeto de um app só. O critério de aceite 8.1 verifica que esses arquivos não importam `SwiftUI`, `HealthKit` nem `WatchKit`, que é o que garante que continuem compiláveis nos dois lados.

### 4.3 Decisões, com o porquê e a alternativa descartada

| Decisão | Por quê | Alternativa descartada |
|---|---|---|
| **App novo em vez de target no Swim Builder** | O modelo de dados é diferente na origem: descanso por bloco e tamanho de raia não existem lá. Enfiar isso no Swim Builder seria migração de schema, catálogo v2 e reescrita do gerador num app publicado, estável e com paywall funcionando | Target watchOS dentro do Swim Builder. Risco alto num produto que já dá certo, para entregar o que é, na prática, outro produto |
| **Descanso fixo em vez de intervalo de saída** | O nadador amador não sabe o próprio pace. "Descanse 30s" ele executa; "saia a cada 1:45" ele não sabe se é fácil ou impossível | Intervalo de saída, que é como treinador pensa e como o MySwimPro faz. Fica na v2, quando houver pace (28.1 e 28.2) |
| **Descanso derivado de tabela, não gravado no catálogo** | Zero trabalho de conteúdo antes de existir app, e o `catalogo_exercicios.json` fica byte a byte idêntico ao do Swim Builder — cópia limpa, auditável, sem fork de conteúdo no dia um | Preencher `descanso_seg` nos 226 exercícios à mão. Melhor calibragem, mas trava o início da implementação |
| **Descanso vira snapshot na série gerada** | Princípio 0.6: o treino favoritado hoje abre com os mesmos descansos daqui a dois anos, mesmo que a tabela mude numa release | Recalcular a tabela toda vez que o treino é aberto. O favorito mudaria sozinho depois de uma atualização |
| **Dois stores SwiftData + WatchConnectivity** | Mantém a promessa de "sem conta, sem internet" e não exige iCloud ligado. Custo zero | SwiftData + CloudKit. Melhor a longo prazo, mas obriga todo atributo opcional ou com default e política de conflito. Vai para 28.6 |
| **Motor de geração embarcado no relógio** | Único caminho que honra o princípio 0.5. O motor é função pura e o catálogo é estático — o custo é tamanho de bundle | Relógio pedir o treino ao iPhone. Quebra exatamente no cenário que justifica o produto |
| **HealthKit como canal do que foi nadado** | O HealthKit sincroniza sozinho entre Watch e iPhone. O dado mais importante atravessa sem uma linha de sync e ainda aparece no app Saúde | Sync próprio das sessões. Mais código, mais estado, e o dado não apareceria no Saúde |
| **watchOS 11 como mínimo** | O corte não é por aparelho: watchOS 11 e 26 rodam nos mesmos modelos (Series 6+, SE 2ª geração+). O corte do 11 é por *atualização*, e o nadador amador é quem menos atualiza. O v1 não usa nenhuma API exclusiva do 26 | watchOS 26 — nada a ganhar. E watchOS 27, que aí sim corta: só Series 9, SE 3ª geração, Ultra 2 e mais novos |
| **XcodeGen** | O `.xcodeproj` deixa de existir como arquivo versionado, e o agente de código pode adicionar arquivo sem tocar em XML gerado. Ferramenta de desenvolvimento, não dependência do app | Manter o `.xcodeproj` versionado. É a origem clássica de conflito de merge e de target quebrado |

### 4.4 A relação com o Swim Builder — cópia, não dependência

`catalogo_exercicios.json` e `tipos_equipamento.json` são **copiados uma vez** do Swim Builder (`versao_catalogo` 1, 226 exercícios) e passam a viver neste repositório. A partir da cópia:

- Não há package compartilhado, submódulo git, dependência ou sincronização.
- Os dois catálogos **vão divergir**, e isso é a decisão consciente, não um efeito colateral.
- Correção feita num app não chega ao outro. Se um dia isso incomodar, o caminho é um repositório de conteúdo comum — e aí é outro projeto.
- Nada mais é copiado: nem modelos, nem repositórios, nem telas, nem design system.

**A ser confirmado (Q1):** copiar também o `WorkoutGenerator` do Swim Builder ou reescrever. Copiar poupa o algoritmo já validado por testes de propriedade; reescrever permite que a geração leve o descanso em conta desde o começo. A assunção 24.2 escolhe copiar e adaptar.

### 4.5 Premissas a validar antes de codar

- **P1** — o nome "Vou Nadar" está disponível na App Store. Uma busca não encontrou conflito óbvio, mas a única prova é reservar o nome no App Store Connect. **Faça isso antes de escrever código**, porque o nome entra em bundle ID, `project.yml` e design.
- **P2** — o `catalogo_exercicios.json` do Swim Builder pode ser copiado sem restrição (é conteúdo próprio do Alexandre). Assumido verdadeiro.
- **P3** — a tabela de descanso da regra 11.5 produz valores de 10s a 75s no ritmo normal sobre os 226 exercícios reais, sem extremos absurdos. **Verificado** contra o catálogo antes de escrever este spec.

---

## 5. Perfis de usuário e matriz de permissões

**Não se aplica.** App single-user, sem conta, sem login, sem perfil, sem dado compartilhado. Não existe autorização a especificar. Registrado e vazio de propósito, para não parecer esquecimento.

## 6. Autenticação e identidade

**Não se aplica** — não há login, portanto não há senha nem recuperação de senha. O único direito do sistema é o da compra, verificado localmente por `Transaction.currentEntitlements` do StoreKit 2, válido para a Apple Account do usuário em todos os aparelhos dela. Restaurar compra é oferecido explicitamente na tela de paywall e nos Ajustes, como a App Store exige.

---

## 7. Modelo de dados

### 7.0 Convenção de idioma

**Banco em português, `snake_case`.** Os nomes persistidos de entidades e propriedades são em português, preservados por `@Attribute(originalName:)`; a propriedade Swift usa a mesma palavra em lowerCamelCase. Os `rawValue` dos enums também são português em snake_case, porque fazem parte do schema persistido e das chaves do JSON do catálogo. O código que consome isso — funções, variáveis, nomes de arquivo — é em inglês. A fronteira de idioma fica na camada de acesso a dados.

### 7.1 Diagrama de relacionamento

```
  CATÁLOGO (JSON no bundle, read-only, nunca no SwiftData)
  ┌────────────────────────────────────────────┐
  │ exercicio_catalogo   (226 registros)       │
  │ tipo_equipamento     (5 registros)         │
  └────────────────────────────────────────────┘
                    │ o gerador sorteia e tira snapshot
                    ▼
  treino  1 ────< 4  secao_treino  1 ────< n  serie_treino
     │
     │ 1
     └────< n  sessao_natacao  ──0..1──> HKWorkout (HealthKit, fora do SwiftData)

  preferencias            (singleton, 1 linha)
  equipamento_selecionado (0..4 linhas)
```

### 7.2 `exercicio_catalogo` — catálogo embarcado (JSON, não persistido)

Copiado do Swim Builder sem alteração. Objeto com quatro chaves de topo: `versao_catalogo`, `gerado_em`, `origem`, `exercicios`.

| Campo | Tipo | Observação |
|---|---|---|
| `exercicio_id` | texto | Chave. Prefixos: `WU_` aquecimento, `CD_` soltura, `FS_` nado/braçada, `KI_` pernada, `ED_` educativo |
| `nome` | texto | Exibido, português, até 45 caracteres |
| `descricao` | texto | Uma ou duas frases de instrução. Nunca vazio |
| `repeticoes` | inteiro | > 0. **166 dos 226 têm valor maior que 1** — são os que ganham descanso interno |
| `distancia_m` | inteiro | Metros por repetição. Valores presentes: 25 a 1500 |
| `metros_totais` | inteiro | `repeticoes × distancia_m`, materializado para o arquivo ser auditável. Igualdade verificada na carga |
| `intensidade` | enum | `aquecimento` (58), `aerobico` (57), `variavel` (39), `resistencia` (34), `moderado` (23), `soltura` (15) |
| `tipo_controle` | enum | `constante` (174), `continuo` (19), `progressivo` (13), `crescente` (10), `split_negativo` (8), `intervalo_fixo` (2) |
| `equipamento_exigido` | texto | `nenhum` (168), `pull_buoy` (24), `prancha` (15), `palmares` (10), `nadadeiras` (9). Um só por exercício |
| `modo` | enum | `nado` (148), `educativo` (32), `bracada` (26), `pernada` (20) |
| `nado` | enum | Todos `livre` na versão 1. Os outros quatro casos existem para a v2 não migrar enum |
| `ativo` | booleano | Exercício desativado fica no arquivo mas nunca é sorteado |
| `adicionado_na_versao` | inteiro | |

> **Não há campo de descanso no catálogo.** O descanso é calculado pela regra 11.5 no momento da geração e gravado como snapshot em `serie_treino.descanso_seg`. Ver a decisão em 4.3.

### 7.3 `tipo_equipamento` — catálogo embarcado (JSON, não persistido)

| Campo | Tipo | Observação |
|---|---|---|
| `equipamento_id` | texto | `nenhum`, `pull_buoy`, `palmares`, `nadadeiras`, `prancha` |
| `nome` | texto | Exibido |
| `icone_sf` | texto | SF Symbol |
| `ordem` | inteiro | `nenhum` tem ordem 0 e **não aparece na tela** — é a ausência de equipamento, não uma opção |

### 7.4 `treino`

| Campo | Tipo | Nulo? | Default | Observação |
|---|---|---|---|---|
| `id` | UUID | não | `UUID()` | `@Attribute(.unique)` |
| `titulo` | texto | **sim** | `nil` | Nulo enquanto não favoritado; exibido como "Treino de {data curta}". Ao favoritar vira obrigatório, 1 a 60 caracteres, não só espaços (regra 11.14) |
| `origem` | `origem_treino` | não | `gerado` | `gerado_iphone` ou `gerado_watch` |
| `distancia_total_m` | inteiro | não | — | Soma de `metros_totais` de todas as séries |
| `distancia_min_solicitada_m` | inteiro | não | — | Faixa pedida na geração, guardada para o histórico fazer sentido depois |
| `distancia_max_solicitada_m` | inteiro | não | — | |
| `tamanho_raia_m` | inteiro | não | — | **Congelado na geração.** O treino foi montado para uma piscina específica (regra 11.3); mudar de piscina não reescreve treino salvo |
| `ritmo_descanso_usado` | `ritmo_descanso` | não | `normal` | Congelado na geração, junto com os descansos das séries (princípio 0.6) |
| `com_educativos` | booleano | não | `false` | Estado do interruptor na geração |
| `com_pernada` | booleano | não | `false` | Idem |
| `favorito` | booleano | não | `false` | Define o que vai para o relógio (regra 11.12) |
| `vezes_executado` | inteiro | não | `0` | Contador **denormalizado**, atualizado na mesma transação de toda inserção e remoção de sessão (regra 11.13). Existe porque a lista de Favoritos exibe o contador em toda linha, e contar relação por linha no SwiftData é lento o bastante para ser percebido |
| `ultima_execucao_em` | data | **sim** | `nil` | Nulo enquanto nunca executado |
| `criado_em` | data | não | `.now` | |
| `atualizado_em` | data | não | `.now` | Chave de ordenação da lista de Favoritos |
| `arquivado_em` | data | **sim** | `nil` | **Soft delete.** Nulo = ativo. Preenchido, some das listas, mas as sessões continuam no Histórico e no volume (regra 11.15) |
| `secoes` | `[secao_treino]` | não | `[]` | Sempre 4, cascade |
| `sessoes` | `[sessao_natacao]` | não | `[]` | 0..n, cascade |

`enum origem_treino: gerado_iphone, gerado_watch`
`enum ritmo_descanso: curto, normal, longo`

### 7.5 `secao_treino`

| Campo | Tipo | Nulo? | Default | Observação |
|---|---|---|---|---|
| `id` | UUID | não | `UUID()` | |
| `tipo_secao` | `tipo_secao` | não | — | |
| `ordem` | inteiro | não | — | 1 a 4, única por treino |
| `distancia_alvo_m` | inteiro | não | — | Meta do algoritmo na geração. Guardada para depuração |
| `descanso_pos_secao_seg` | inteiro | não | — | Descanso entre esta seção e a próxima (regra 11.6). Zero na última seção |
| `treino` | `treino?` | sim | — | Inverse |
| `series` | `[serie_treino]` | não | `[]` | 0..n, ordem contígua a partir de 1, cascade |

`enum tipo_secao: aquecimento, progressao, principal, soltura` — sempre as quatro, nessa ordem, inclusive quando alguma fica vazia em treino curto.

### 7.6 `serie_treino`

Guarda **snapshot** dos dados do exercício, não referência (princípio 0.6). `exercicio_id` é referência lógica, **sem chave estrangeira**: pode apontar para exercício removido numa release futura e nada quebra.

| Campo | Tipo | Nulo? | Default | Observação |
|---|---|---|---|---|
| `id` | UUID | não | `UUID()` | |
| `exercicio_id` | texto | não | — | Referência lógica ao catálogo, sem FK |
| `repeticoes` | inteiro | não | — | Snapshot |
| `distancia_m` | inteiro | não | — | **Distância real por repetição, já adaptada à raia** (regra 11.3): `voltas_por_repeticao × tamanho_raia_m`. É o que a interface exibe |
| `distancia_catalogo_m` | inteiro | não | — | Snapshot do que o catálogo pedia, antes da adaptação. Existe só para rastreabilidade e depuração; a interface nunca mostra |
| `metros_totais` | inteiro | não | — | `repeticoes × distancia_m` — sobre a distância **real**, nunca a do catálogo |
| **`descanso_seg`** | inteiro | não | — | **Snapshot do descanso ENTRE as repetições**, calculado pela regra 11.5 na geração. É o número que vira a contagem regressiva no relógio |
| **`descanso_pos_serie_seg`** | inteiro | não | — | Descanso entre esta série e a próxima da mesma seção (regra 11.6). Zero na última série da seção — ali vale o `descanso_pos_secao_seg` |
| **`voltas_por_repeticao`** | inteiro | não | — | `max(1, arredonda(distancia_catalogo_m / tamanho_raia_m))`. Calculado na geração e **congelado**. É o contador que o relógio usa para saber que a repetição acabou (regras 11.3 e 11.7) |
| `nome_snapshot` | texto | não | — | |
| `descricao_snapshot` | texto | não | — | |
| `equipamento_exigido` | texto | não | `nenhum` | Snapshot. Desenha o ícone na linha |
| `modo` | `modo_exercicio` | não | `nado` | Snapshot. Desenha o selo "braçada", "pernada" ou "técnica" |
| `intensidade` | `intensidade` | não | — | Snapshot. Usado pela cor semântica da linha |
| `ordem` | inteiro | não | — | ≥ 1, contígua dentro da seção |
| `secao` | `secao_treino?` | sim | — | Inverse |

### 7.7 `preferencias` — singleton, exatamente uma linha

| Campo | Tipo | Nulo? | Default | Observação |
|---|---|---|---|---|
| `id` | UUID | não | `UUID()` | |
| `distancia_min_m` | inteiro | não | `1500` | Piso da faixa pedida |
| `distancia_max_m` | inteiro | não | `2500` | Teto. **Pode ser igual ao piso** — faixa fechada é caso de uso legítimo |
| `incluir_educativos` | booleano | não | `false` | |
| `incluir_pernada` | booleano | não | `false` | |
| **`tamanho_raia_m`** | inteiro | não | `25` | Comprimento da raia. Aceita **10 a 50** — piscina de condomínio e academia costuma ter 12, 15, 16, 18 ou 20 m, e o app precisa servi-las. Alimenta o `lapLength` do HealthKit e a adaptação da regra 11.3 |
| **`raia_confirmada`** | booleano | não | `false` | Falso até o usuário confirmar uma vez. Enquanto falso, **não é possível gerar treino** (regra 11.3) |
| **`ritmo_descanso`** | `ritmo_descanso` | não | `normal` | Multiplicador global da tabela de descanso (regra 11.5) |
| `versao_catalogo_visto` | inteiro | não | `0` | Default de schema. O seed grava a versão embarcada, para instalação nova não ver banner de novidade no primeiro dia |
| `atualizado_em` | data | não | `.now` | Decide quem vence na sincronização (regra 11.12) |
| `criado_em` | data | não | `.now` | |

Criada na primeira abertura por `PreferencesRepository.seedPreferencesIfNeeded()` com estes defaults. Nunca apagada, exceto por "Apagar todos os dados".

### 7.8 `equipamento_selecionado`

Zero linhas é estado válido e comum: nadador sem equipamento nenhum. Nesse caso a geração usa só exercícios com `equipamento_exigido = nenhum`.

| Campo | Tipo | Nulo? | Default | Observação |
|---|---|---|---|---|
| `id` | UUID | não | `UUID()` | |
| `equipamento_id` | texto | não | — | `@Attribute(.unique)`. Referência lógica ao JSON, sem FK |
| `selecionado_em` | data | não | `.now` | |

### 7.9 `sessao_natacao` — a execução real

Nasce no relógio. É o registro do que aconteceu na água, distinto do treino planejado.

| Campo | Tipo | Nulo? | Default | Observação |
|---|---|---|---|---|
| `id` | UUID | não | `UUID()` | `@Attribute(.unique)` |
| `treino` | `treino?` | **sim** | `nil` | Nulo em sessão livre, sem treino associado |
| `titulo_snapshot` | texto | **sim** | `nil` | Cópia no momento da execução, para o histórico sobreviver ao arquivamento do treino |
| `iniciada_em` | data | não | — | Indexado — o Histórico ordena por ele |
| `encerrada_em` | data | **sim** | `nil` | Nulo enquanto em andamento ou pausada |
| `distancia_planejada_m` | inteiro | não | `0` | Zero em sessão livre |
| `distancia_real_m` | inteiro | não | `0` | Medida pelo HealthKit. **É o que vai para o `HKWorkout`, nunca o planejado** |
| `series_concluidas` | inteiro | não | `0` | |
| `repeticoes_concluidas` | inteiro | não | `0` | Granularidade fina, para o resumo dizer "parou no meio do 3º de 4×100" |
| `healthkit_workout_uuid` | UUID | **sim** | `nil` | Nulo até gravar com sucesso, e permanentemente nulo se a gravação falhar |
| `tamanho_raia_m` | inteiro | não | — | Congelado no início. Trocar de piscina depois não altera histórico |
| `motivo_encerramento` | `motivo_encerramento?` | **sim** | `nil` | Nulo enquanto em andamento |

`enum motivo_encerramento: concluido, encerrado_antes, descartado_curto, falhou`

### 7.10 Estratégia de exclusão

| Entidade | Estratégia | Motivo |
|---|---|---|
| `treino` | **Soft delete** por `arquivado_em` | Há sessões apontando para ele; apagar apagaria histórico de volume |
| `secao_treino`, `serie_treino` | **Cascade** a partir do treino | Não têm significado fora dele |
| `sessao_natacao` | **Hard delete**, só pelo iPhone | O usuário registrou errado e quer desfazer. O `HKWorkout` correspondente **não** é apagado junto — é dado de saúde do usuário, sai pelo app Saúde |
| `preferencias` | Nunca deletada | Singleton |
| `equipamento_selecionado` | **Hard delete** | Estado de configuração, não histórico |

### 7.11 Constraints, índices e invariantes

- `treino.id`, `sessao_natacao.id`, `equipamento_selecionado.equipamento_id`: `@Attribute(.unique)`.
- `preferencias`: unicidade garantida por código no acesso (busca-o-primeiro-ou-cria) — SwiftData não expressa "no máximo uma linha".
- `preferencias.tamanho_raia_m`: validar `10...50` na camada de acesso.
- `preferencias.distancia_min_m ≤ distancia_max_m`: validado no repositório.
- `secao_treino.ordem`: 1 a 4, única por treino; um registro por `tipo_secao` por treino. **Invariantes que o repositório preserva, porque o SwiftData não as declara.**
- `serie_treino.ordem`: contígua a partir de 1 dentro da seção.
- Índice em `sessao_natacao.iniciada_em`.

### 7.12 Schema versionado e migração

O schema nasce como `VouNadarSchemaV1` com `SchemaMigrationPlan` declarado desde o v1, mesmo sem nenhuma migração ainda. É baratíssimo fazer agora e caro fazer depois de ter usuário instalado.

### 7.13 Dados de seed

O catálogo **não é seed de banco** — é recurso estático no bundle, nunca entra no SwiftData. `preferencias` nasce no primeiro acesso com os defaults de 7.7. `equipamento_selecionado` nasce vazio.

---

## 8. Épicos e critérios de aceite

Ordem de implementação obrigatória: 8.1 → 8.12.

### 8.1 Fundação do projeto

**Objetivo:** projeto compila nos dois targets, catálogo carrega e é validado.

**Critérios de aceite:**
- [ ] `project.yml` declara os targets `VouNadar` (iOS 18, iPhone, retrato), `VouNadarWatch` (watchOS 11), `VouNadarWatchComplication` e `VouNadarTests`; `xcodegen generate` produz projeto que compila.
- [ ] `.xcodeproj` está no `.gitignore`.
- [ ] Zero dependência SPM de terceiro; não existe `Package.resolved`.
- [ ] Build sem nenhum warning, com warning tratado como erro, Swift 6 em concorrência estrita.
- [ ] `catalogo_exercicios.json` e `tipos_equipamento.json` copiados do Swim Builder e carregando nos dois targets.
- [ ] Teste de integridade do catálogo: 226 exercícios, `metros_totais == repeticoes × distancia_m` em todos, todo `equipamento_exigido` existe em `tipos_equipamento`, todo `exercicio_id` é único.
- [ ] Arquivos de `Domain/`, `Data/Catalog/`, `Data/Enums/` e `Data/Models/` não importam `SwiftUI`, `HealthKit`, `UIKit` nem `WatchKit` — teste verifica isso.

### 8.2 Tabela de descanso

**Objetivo:** existe uma função pura que, dado um exercício e um ritmo, devolve o descanso.

**Critérios de aceite:**
- [ ] `RestCalculator` é função pura, sem estado e sem dependência de plataforma.
- [ ] Implementa exatamente a tabela e os multiplicadores da regra 11.5, incluindo arredondamento para múltiplo de 5 e limites de 10 e 90 segundos.
- [ ] Teste que roda a função sobre os 226 exercícios reais nos três ritmos e verifica que **nenhum resultado sai de 10–90 segundos**.
- [ ] Teste dos casos da tabela de exemplos da regra 11.5, um a um.

### 8.3 Configuração de piscina e ritmo

**Objetivo:** o app sabe o tamanho da raia antes de gerar qualquer coisa.

**Fluxo (iPhone):** primeira abertura → tela de configuração de piscina, obrigatória → atalhos de 25 m e 50 m, mais "Outro" com stepper de **10 a 50** → confirma. `raia_confirmada` vira `true`.

**Critérios de aceite:**
- [ ] Com `raia_confirmada == false`, o botão Gerar está desabilitado e a tela de piscina é apresentada.
- [ ] Valor fora de 10–50 é rejeitado com mensagem.
- [ ] Piscinas de 12, 15, 16, 18 e 20 m são configuráveis e produzem treino válido (regra 11.3).
- [ ] Ajustes permite trocar depois; trocar **não** reescreve treino já salvo (7.4).
- [ ] Ritmo de descanso (curto/normal/longo) configurável nos Ajustes, com o efeito explicado em uma frase na própria tela.

### 8.4 Geração de treino no iPhone

**Objetivo:** o núcleo do produto.

**Fluxo:** Home → faixa de distância, equipamentos, interruptores de educativo e pernada → "Gerar" → treino na tela com as quatro seções, cada série mostrando repetições, distância, equipamento e **descanso**.

**Critérios de aceite:**
- [ ] O gerador é função pura, sem `MainActor`, testável sem UI.
- [ ] Só sorteia exercícios com `ativo == true`.
- [ ] **Adapta a distância de cada exercício à raia** (regra 11.3), e descarta do sorteio os que passariam de 25% de desvio.
- [ ] `distancia_m` gravado é a distância **real** (voltas × raia); `distancia_catalogo_m` guarda o original.
- [ ] A verificação da faixa (11.2) usa o total **adaptado**.
- [ ] Respeita os equipamentos selecionados; sem nenhum selecionado, usa só `equipamento_exigido == nenhum`.
- [ ] `educativo` e `pernada` só entram com o interruptor correspondente ligado.
- [ ] A distância total cai dentro da faixa pedida, com a tolerância da regra 11.2.
- [ ] Todo treino tem exatamente quatro seções, inclusive vazias.
- [ ] Toda série sai com `descanso_seg`, `descanso_pos_serie_seg` e `voltas_por_repeticao` preenchidos.
- [ ] Geração em ≤ 1 s.
- [ ] Teste de propriedade: 500 gerações com sementes variadas, nenhuma viola nenhum critério acima.

### 8.5 Persistência e favoritos

**Critérios de aceite:**
- [ ] Treino gerado é persistido com todas as seções e séries.
- [ ] Favoritar exige título de 1 a 60 caracteres, não só espaços.
- [ ] Lista de Favoritos ordena por `atualizado_em` decrescente.
- [ ] Apagar faz soft delete: some das listas, mas as sessões continuam no Histórico.
- [ ] Estado vazio explica o que fazer, não é lista vazia sem texto.
- [ ] **"Copiar como texto"** no Detalhe põe o treino na área de transferência no formato exato da seção 14, verificado caractere a caractere por teste.
- [ ] Copiar é um toque só: sem folha, sem tela intermediária. Háptico de sucesso e a confirmação 15.19.
- [ ] O texto copiado usa as distâncias **adaptadas à raia** e traz a linha da piscina (regras 14.2.2 e 14.2.6).
- [ ] Seção vazia não aparece no texto, cabeçalho incluído.

### 8.6 Sincronização iPhone → Watch

**Critérios de aceite:**
- [ ] `updateApplicationContext` carrega estado leve: piscina, ritmo, preferências, equipamentos, direito de compra. Limite de 262.144 bytes, folgadíssimo.
- [ ] Favoritos vão por `transferUserInfo`, respeitando 65.536 bytes por transferência; acima de 50.000 bytes serializados, divide em lotes (regra 11.12).
- [ ] Favoritar com o relógio fora de alcance e reaproximar entrega sem ação do usuário.
- [ ] Desfavoritar remove do relógio.
- [ ] **Nenhum dado trafega do relógio para o iPhone** (princípio 0.7).
- [ ] Com `WCSession` indisponível, o app do relógio funciona normalmente com o que tem em disco.

### 8.7 App do relógio: navegação, geração e pré-visualização

**Critérios de aceite:**
- [ ] Abre em ≤ 2 s em Series 7.
- [ ] Store SwiftData próprio, persistindo entre execuções.
- [ ] Tela Gerar: faixa de distância pela **coroa digital**, quatro toggles de equipamento.
- [ ] Gera com o iPhone desligado, identicamente.
- [ ] Pré-visualização mostra título, distância total e — **de forma destacada** — `Raia de {n} m`, tocável para trocar (mitigação do risco R1).
- [ ] Sem `raia_confirmada`, gerar leva à tela de piscina antes.
- [ ] Navegação inteiramente pela coroa, sem depender de toque preciso.

### 8.8 Execução guiada — o coração do produto

**Objetivo:** o treino roda na água sem nenhuma interação obrigatória.

**Fluxo:**
1. "Iniciar" → contagem regressiva de 3 s.
2. `HKWorkoutSession` inicia: `activityType = .swimming`, `swimmingLocationType = .pool`, `lapLength = tamanho_raia_m`. O Water Lock liga sozinho.
3. **Estado NADANDO:** tela mostra a repetição atual (`3 de 4`), a série (`4×100 crawl`) e a distância acumulada.
4. Ao completar `voltas_por_repeticao` voltas, entra em **DESCANSANDO**: contagem regressiva de `descanso_seg` em tipografia gigante, háptico ao começar e nos 3 segundos finais.
5. Zerou o descanso: háptico de saída, volta para NADANDO na repetição seguinte.
6. Última repetição da série: aplica `descanso_pos_serie_seg` e avança a série. Última série da seção: aplica `descanso_pos_secao_seg`.
7. Última série da última seção: háptico de conclusão e vai para o encerramento.

**Estados:** preparando, nadando, descansando, pausado, erro de autorização, erro de sessão.

**Critérios de aceite:**
- [ ] A sessão inicia com `lapLength` preenchido; sem ele, **não** inicia.
- [ ] Nenhuma ação obrigatória exige toque entre o início e o fim (princípio 0.1).
- [ ] A contagem regressiva de descanso é o elemento dominante da tela quando o estado é DESCANSANDO — é a informação que a persona da seção 2 mais precisa.
- [ ] Háptico ao entrar em descanso, nos 3 s finais, e ao sair.
- [ ] Legível a 40 cm com o braço em movimento; número principal ≥ 44 pt.
- [ ] Com Always-On e luminância reduzida, continua mostrando o estado e o número, sem animação.
- [ ] Segurar a coroa desbloqueia o Water Lock e revela Pausar, Pular série e Encerrar.
- [ ] Nadar mais que o planejado não gera erro: a sessão fica na última série contando a distância extra (regra 11.10).
- [ ] Descanso mais longo que o previsto não gera erro: o app espera a volta seguinte, sem avançar sozinho.
- [ ] Sem autorização do HealthKit, a tela explica em português e oferece abrir os Ajustes; a sessão não inicia.

### 8.9 Encerramento e gravação

**Critérios de aceite:**
- [ ] `HKWorkout` de natação gravado com distância real, duração e `lapLength` nos metadados.
- [ ] Aparece no app Saúde do iPhone sem nenhum código de sincronização adicional.
- [ ] Sessão com menos de 25 m é descartada sem gravar, com aviso (regra 11.11).
- [ ] Falha de gravação preserva a `sessao_natacao` com `motivo_encerramento = falhou` e avisa — nunca falha silenciosa.
- [ ] Resumo legível com a mão molhada, sem exigir toque preciso.

### 8.10 Histórico e volume no iPhone

**Critérios de aceite:**
- [ ] Sessões nadadas no relógio aparecem sem ação do usuário.
- [ ] Volume por semana, semana começando na segunda-feira, fuso do aparelho (regra 11.16).
- [ ] Treinos de natação gravados por **outros** apps aparecem também, identificados como origem externa — o HealthKit é do usuário, não do Vou Nadar.
- [ ] Sem autorização de leitura, a tela explica e oferece o caminho, sem quebrar.

### 8.11 Paywall

**Critérios de aceite:**
- [ ] StoreKit 2, produto não-consumível, R$ 49,90.
- [ ] As 3 primeiras execuções guiadas são livres; a 4ª leva ao paywall (assunção 24.5).
- [ ] Gerar treino é **sempre** livre, pago ou não.
- [ ] "Restaurar compra" existe no paywall e nos Ajustes.
- [ ] O relógio lê o direito por `Transaction.currentEntitlements`; falhando, vale o último estado recebido via `applicationContext`; **na dúvida, libera** (regra 11.17).
- [ ] Teste com o arquivo `.storekit` local cobrindo compra, restauração e falha.

### 8.12 Complication

**Critérios de aceite:**
- [ ] Famílias `accessoryCircular`, `accessoryCorner` e `accessoryRectangular`.
- [ ] Mostra o volume da semana; sem dado, ícone e um traço.
- [ ] Tocar abre o app na tela Início.
- [ ] Atualiza no máximo uma vez por hora.

---

## 9. Fluxos principais ponta a ponta

### 9.1 Primeira abertura

1. Abre o app no iPhone → tela de piscina, obrigatória.
2. Toca "25 m". `raia_confirmada = true`.
3. Home habilitada. Ajusta faixa (1.500–2.500), marca pull buoy.
4. "Gerar". Treino na tela, com descanso em cada série.
5. Favorita como "Terça leve".
6. O treino chega ao relógio sozinho.

### 9.2 Fluxo feliz — treino completo

1. Vestiário. Abre no relógio, escolhe "Terça leve".
2. Pré-visualização: `2.100 m · Raia de 25 m`. "Iniciar". Contagem de 3.
3. Water Lock liga. Entra na água.
4. Nada 100 m. Tela vira: `DESCANSO 0:30`, contando. Háptico.
5. Faltam 3 s: háptico. Zera: háptico de saída, tela mostra `2 de 4 · 4×100 crawl`.
6. Repete até acabar. Háptico de conclusão.
7. Sai, segura a coroa, encerra. Resumo. `HKWorkout` gravado.
8. Em casa, no iPhone: a sessão está no Histórico e no volume da semana.

### 9.3 Exceção — piscina de tamanho incomum

O nadador configura uma piscina de condomínio de 16 m. O gerador adapta cada exercício ao número de voltas mais próximo (regra 11.3): o `4×100` do catálogo vira `4×96 m` — seis voltas —, e é `4×96` que aparece na tela, no relógio e no total do treino. O desvio médio nessa piscina é de 3,4%.

Os blocos de 25 m saem do sorteio nessa piscina: 25 m em raia de 16 m daria 2 voltas, 32 m, um desvio de 28% que estoura a guarda. Restam 205 dos 226.

O caso mais afetado é a piscina de 50 m, onde os mesmos 21 blocos de 25 m e 2 de 75 m saem, restando 203. **12 dos 32 educativos são blocos de 25 m**, então numa piscina olímpica o repertório de técnica encolhe bastante. Ver a regra 11.19 e o risco R2.

### 9.4 Exceção — nadou menos ou mais que o planejado

Parou em 1.200 m de 2.100 m: resumo mostra `1.200 m de 2.100 m`, `motivo_encerramento = encerrado_antes`, e o `HKWorkout` grava **1.200 m**. Não há mensagem de falha — parar antes não é erro.

Nadou 2.400 m: a sessão fica na última série contando a distância extra e grava 2.400 m.

### 9.5 Exceção — relógio nunca pareado

Abre, gera, executa, encerra e grava normalmente. Favoritos aparece vazio com a copy 15.4. Nada quebra, nada pede o iPhone.

---

## 10. Inventário de telas

Sem perfis de acesso (seção 5). `P` = iPhone, `W` = Apple Watch.

| # | Tela | Mostra | Ações | Lê | Escreve |
|---|---|---|---|---|---|
| P1 | **Home** | Faixa de distância, equipamentos, dois interruptores, botão Gerar | Gerar | `preferencias`, `equipamento_selecionado`, catálogo | `preferencias`, `equipamento_selecionado` |
| P2 | **Detalhe do treino** | Numeral herói, quatro seções, cada série com repetições, distância, equipamento e descanso | Favoritar, Gerar outro, **Copiar como texto** | `treino` | `treino` |
| P3 | **Favoritos** | Lista: título, distância, vezes executado | Abrir, apagar | `treino` | `treino` |
| P4 | **Histórico** | Volume por semana e lista de sessões | — | HealthKit, `sessao_natacao` | — |
| P5 | **Ajustes** | Piscina, ritmo de descanso, restaurar compra, apagar dados | Editar | `preferencias` | `preferencias` |
| P6 | **Piscina** | Atalhos 25 m e 50 m, mais "Outro" (10–50) | Confirmar | `preferencias` | `preferencias` |
| P7 | **Paywall** | Proposta, preço, comprar, restaurar | Comprar, restaurar | StoreKit | — |
| W1 | **Início** | Volume da semana, dois botões | Gerar, Favoritos | `sessao_natacao`, HealthKit | — |
| W2 | **Gerar** | Faixa pela coroa + 4 toggles | Gerar | `preferencias` | `preferencias` |
| W3 | **Favoritos** | Título + distância | Selecionar | `treino` | — |
| W4 | **Pré-visualização** | Título, distância, séries, `Raia de {n} m` | Iniciar, Trocar piscina | `treino`, `preferencias` | `treino` |
| W5 | **Piscina** | Atalhos 25 m e 50 m, mais "Outro" (10–50, pela coroa) | Confirmar | `preferencias` | `preferencias` |
| W6 | **Contagem** | `3 · 2 · 1` em tela cheia | — | — | — |
| W7 | **Nadando** | `3 de 4`, série atual, acumulado | (nenhuma obrigatória) | `treino` | — |
| W8 | **Descansando** | Contagem regressiva gigante, próxima repetição | (nenhuma obrigatória) | `treino` | — |
| W9 | **Desbloqueada** | Igual a W7/W8 + botões | Pausar, Pular, Encerrar | idem | `sessao_natacao` |
| W10 | **Resumo** | Real vs planejado, tempo, séries | Concluir | `sessao_natacao` | `sessao_natacao`, HealthKit |
| W11 | **Erro de autorização** | Explicação + caminho | Abrir Ajustes | — | — |

---

## 11. Regras de negócio

| # | Regra | Onde |
|---|---|---|
| 11.1 | **Quatro seções sempre.** Todo treino tem `aquecimento`, `progressao`, `principal`, `soltura`, nessa ordem, inclusive quando alguma fica vazia em treino curto | Gerador |
| 11.2 | **Tolerância de distância.** A distância total do treino gerado fica dentro da faixa pedida. Se o sorteio não fechar dentro da faixa em até 50 tentativas, aceita o resultado mais próximo e registra em log — nunca falha para o usuário | Gerador |
| 11.3 | **Adaptação à raia.** A repetição só termina quando um número inteiro de voltas é completado. Em vez de exigir que a distância do catálogo seja múltiplo da piscina, o gerador **adapta** a distância ao número de voltas mais próximo. Detalhe em "11.3 detalhado" | Gerador |
| 11.4 | **Piscina obrigatória antes de gerar.** Com `raia_confirmada == false` nenhum treino é gerado, nos dois aparelhos. Não é só requisito da execução: a regra 11.3 muda as distâncias e o conteúdo do treino | Ambos |
| 11.5 | **Tabela de descanso.** `descanso_seg = base(distancia_m) × mult(intensidade) × mult(modo) × mult(ritmo)`, arredondado para o múltiplo de 5 mais próximo e limitado a 10–90 s. Detalhe abaixo | Gerador |
| 11.6 | **Descanso entre séries e entre seções.** `descanso_pos_serie_seg` = 30 s × mult(ritmo), zero na última série da seção. `descanso_pos_secao_seg` = 45 s × mult(ritmo), zero na última seção. Arredondados para múltiplo de 5 | Gerador |
| 11.7 | **Fim da repetição.** A repetição termina quando o relógio contabiliza `voltas_por_repeticao` voltas desde o início dela. `voltas_por_repeticao = distancia_m / tamanho_raia_m`, calculado na geração — nunca em tempo de execução, para o treino salvo não mudar de comportamento se a piscina mudar depois | App watchOS |
| 11.8 | **Início do descanso.** O descanso começa quando a repetição termina (11.7), não quando o nadador para. Se a detecção de volta atrasar, o descanso começa atrasado — é tolerável e está no risco R3 | App watchOS |
| 11.9 | **Háptico.** Entrada em descanso: `.notification`. Três segundos finais: `.directionUp`, um por segundo. Saída: `.start`. Conclusão do treino: `.success`. Sessão descartada: `.failure`. **Nenhum háptico em qualquer outro evento** — háptico demais vira ruído e o nadador para de prestar atenção | App watchOS |
| 11.10 | **Tolerância na execução.** Nadar menos encerra com `encerrado_antes`, sem mensagem de falha. Nadar mais mantém a sessão na última série contando a distância extra. Descansar mais que o previsto não avança nada — o app espera a volta seguinte. Em todos os casos o `HKWorkout` grava a distância **real** | App watchOS |
| 11.11 | **Distância mínima.** Sessão com `distancia_real_m < 25` é descartada: `descartado_curto`, nenhum `HKWorkout`, aviso na tela. Evita poluir o histórico de saúde com toque acidental | App watchOS |
| 11.12 | **Sincronização.** `updateApplicationContext` para estado leve (limite 262.144 bytes). `transferUserInfo` para favoritos (limite 65.536 bytes por transferência); acima de 50.000 bytes serializados, divide em lotes e o receptor **substitui** o conjunto ao receber o último lote — substituição é idempotente, merge exigiria resolução de conflito. Em conflito de `preferencias`, vence o `atualizado_em` mais recente | Ambos |
| 11.13 | **Contador denormalizado.** `treino.vezes_executado` e `ultima_execucao_em` são atualizados na **mesma transação** de toda inserção e remoção de `sessao_natacao`, sob pena de divergir | Ambos |
| 11.14 | **Título do favorito.** Obrigatório ao favoritar: 1 a 60 caracteres, não só espaços. Treino não favoritado exibe "Treino de {data curta}" | iPhone |
| 11.15 | **Soft delete do treino.** Apagar preenche `arquivado_em`. O treino some das listas, mas as sessões continuam no Histórico e no volume | Ambos |
| 11.16 | **Semana.** Começa na segunda-feira, no fuso do aparelho no momento da consulta. Sessão que atravessa a meia-noite conta na semana do `iniciada_em` | Ambos |
| 11.17 | **Direito de compra.** Verificado por `Transaction.currentEntitlements`. Falhando por indisponibilidade, vale o último estado recebido via `applicationContext`. **Na dúvida, libera** — negar acesso a quem pagou é pior que liberar a quem não pagou | Ambos |
| 11.18 | **Direção do dado.** O relógio nunca edita nem apaga treino com `origem == gerado_iphone`. Treino gerado no relógio existe só no relógio no v1 | Ambos |
| 11.19 | **Aviso de repertório curto.** Se a combinação de raia, equipamentos e interruptores deixar **menos de 30 candidatos**, o app gera assim mesmo mas avisa uma vez, com a copy 15.17, dizendo o que reduziria o problema (marcar mais equipamento, ou desligar um filtro). Nunca bloqueia a geração — treino repetitivo é melhor que treino nenhum | Ambos |

### 11.3 detalhado — adaptação da distância à raia

O relógio só sabe que a repetição acabou quando conta um número **inteiro** de voltas. Exigir que a distância do catálogo fosse múltiplo exato da piscina inviabilizaria o produto justamente nas piscinas mais comuns de condomínio e academia — em raia de 16 m sobrariam 14 exercícios dos 226, e em 18 m sobrariam 2.

Por isso o gerador adapta em vez de exigir:

```
voltas_por_repeticao  = max(1, arredonda(distancia_catalogo_m / tamanho_raia_m))
distancia_m           = voltas_por_repeticao × tamanho_raia_m
metros_totais         = repeticoes × distancia_m
```

**`distancia_m` é a distância real e é o que a interface exibe.** Um `4×100` do catálogo aparece como `4×96 m` numa piscina de 16 m, porque é isso que o nadador vai nadar. `distancia_catalogo_m` guarda o valor original só para rastreabilidade.

**Guarda de desvio.** Se `|distancia_m − distancia_catalogo_m| / distancia_catalogo_m > 0,25`, o exercício **sai do sorteio** naquela piscina. Isso protege o caso ruim — os blocos de 25 m em piscina de 16, 18 ou 50 m, onde a adaptação distorceria demais o exercício.

**Verificação de cobertura contra o catálogo real:**

| Raia | Utilizáveis | Desvio médio | Pior caso |
|---|---|---|---|
| 10 m | 226 | 1,6% | 25 m → 2 voltas = 20 m |
| 12 m | 226 | 1,5% | 25 m → 2 voltas = 24 m |
| 15 m | 226 | 2,6% | 25 m → 2 voltas = 30 m |
| 16 m | 205 | 3,4% | 21 blocos de 25 m saem pela guarda |
| 18 m | 205 | 3,6% | 21 blocos de 25 m saem pela guarda |
| 20 m | 226 | 3,4% | 25 m → 1 volta = 20 m |
| 25 m | 226 | 0% | adaptação nunca dispara |
| 50 m | 203 | — | 21 blocos de 25 m e 2 de 75 m saem |

**Consequência para a faixa de distância.** A verificação da regra 11.2 (total dentro da faixa pedida) é feita sobre a distância **adaptada**, nunca sobre a do catálogo. Em piscinas de tamanho incomum o total do treino desloca alguns por cento, e isso é esperado.

**Piscinas ruins para este catálogo.** Raia de 33 m derruba 93 dos 226 pela guarda de desvio, porque quase nenhuma distância do catálogo se aproxima de um múltiplo de 33. É raro o bastante para não tratar no v1, mas o app deve avisar quando a combinação de filtros deixar menos de 30 candidatos (regra 11.19).

---

### 11.5 detalhado — a tabela de descanso

**Base, por distância da repetição:**

| `distancia_m` | Base |
|---|---|
| 25 | 15 s |
| 50 | 20 s |
| 75 | 25 s |
| 100 | 30 s |
| 150 | 40 s |
| 200 | 45 s |
| 250 | 50 s |
| 300 ou mais | 60 s |

**Multiplicador por intensidade:** `aquecimento` 0,75× · `soltura` 0,75× · `moderado` 1,0× · `aerobico` 1,0× · `variavel` 1,0× · `resistencia` 1,25×

**Multiplicador por modo:** `nado` 1,0× · `bracada` 1,0× · `educativo` 0,75× · `pernada` 1,25×

**Multiplicador global (`preferencias.ritmo_descanso`):** `curto` 0,75× · `normal` 1,0× · `longo` 1,5×

**Arredondamento:** múltiplo de 5 mais próximo. **Limites:** mínimo 10 s, máximo 90 s.

**Exemplos verificados contra o catálogo real, no ritmo normal:**

| Exercício | Cálculo | Descanso |
|---|---|---|
| `CD_08x25` — 8×25 soltura/nado | 15 × 0,75 × 1,0 = 11,25 | **10 s** |
| `ED_04x25_CATCHUP` — 4×25 aquecimento/educativo | 15 × 0,75 × 0,75 = 8,4 | **10 s** (piso) |
| 4×50 aeróbico/nado | 20 × 1,0 × 1,0 = 20 | **20 s** |
| 6×50 aeróbico/pernada | 20 × 1,0 × 1,25 = 25 | **25 s** |
| 3×100 resistência/nado | 30 × 1,25 × 1,0 = 37,5 | **40 s** |
| 2×200 moderado/nado | 45 × 1,0 × 1,0 = 45 | **45 s** |
| `KI_01x300_PRANCHA` — 1×300 aeróbico/pernada | 60 × 1,0 × 1,25 = 75 | **75 s** |

**Amplitude verificada sobre os 226 exercícios:** 10 a 75 s no ritmo normal, 10 a 55 s no curto, 15 a 90 s no longo. Nenhum valor bate no teto de 90 fora do ritmo longo.

---

## 12. Máquinas de estado

### 12.1 `treino`

```
gerado ──favoritar──> favorito ──arquivar──> arquivado
   │                      │                      ▲
   └──────arquivar────────┴──────────────────────┘
```

Não há estado "editado": edição está fora do escopo (3.2). Arquivado é terminal.

### 12.2 `sessao_natacao`

```
ocioso ──iniciar──> preparando ──autorizado──> NADANDO ⇄ DESCANSANDO
                        │                          │  ▲        │
                        │ nega autorização         │  └────────┘
                        ▼                          │  (por repetição, regra 11.7)
                    erroAutorizacao                │
                                        pausar ⇄ pausado
                                                   │
                                                encerrar
                                                   │
              ┌────────────────────────────────────┼────────────────────┐
              ▼                    ▼               ▼                    ▼
      salva(concluido)   salva(encerrado_antes)  descartada    salva(falhou)
                                                (descartado_curto)
```

**Transições proibidas:** `pausado → salva` direto (passa por encerrar); `erroAutorizacao → NADANDO` sem nova autorização; qualquer saída de estado terminal.

**Falhas:**

| Falha | O que acontece |
|---|---|
| HealthKit nega autorização | `erroAutorizacao`, tela W11, nenhuma sessão criada |
| `HKWorkoutSession` falha ao iniciar | `erroAutorizacao` com copy 15.9, sessão descartada |
| App morto pelo sistema durante a sessão | Ao reabrir, recupera a `HKLiveWorkoutBuilder` ativa se houver; se não, encerra a sessão órfã com `falhou` |
| Gravação do `HKWorkout` falha | Sessão salva com `healthkit_workout_uuid = nil` e `motivo_encerramento = falhou`; usuário avisado |

---

## 13. Contratos dos módulos internos

Não há API HTTP. Três contratos importam.

### 13.1 Gerador

```
gerarTreino(faixaMin: Int,
            faixaMax: Int,
            equipamentos: [String],
            incluirEducativos: Bool,
            incluirPernada: Bool,
            tamanhoRaiaM: Int,
            ritmoDescanso: RitmoDescanso,
            catalogo: [ExercicioCatalogo],
            seed: UInt64?) -> Treino
```

Função pura, sem `MainActor`, sem acesso a disco. `seed` existe para os testes de propriedade; em produção é `nil`.

### 13.2 Calculadora de descanso

```
descansoSegundos(distanciaM: Int,
                 intensidade: Intensidade,
                 modo: ModoExercicio,
                 ritmo: RitmoDescanso) -> Int
```

Função pura, implementando a regra 11.5 literalmente.

### 13.3 WatchConnectivity — payloads

`updateApplicationContext` (iPhone → Watch):

| Chave | Tipo |
|---|---|
| `tamanho_raia_m` | `Int` |
| `raia_confirmada` | `Bool` |
| `ritmo_descanso` | `String` |
| `distancia_min_m` / `distancia_max_m` | `Int` |
| `incluir_educativos` / `incluir_pernada` | `Bool` |
| `equipamentos` | `[String]` |
| `prefs_atualizado_em` | `Double` (timestamp Unix) |
| `comprado` | `Bool` |

`transferUserInfo` (iPhone → Watch), favoritos:

| Chave | Tipo |
|---|---|
| `tipo` | `String`, sempre `"favoritos"` |
| `lote` / `total_lotes` | `Int` |
| `treinos` | `[[String: Any]]`, treino serializado com seções e séries |

### 13.4 HealthKit

| Uso | Tipo |
|---|---|
| Escrita | `HKWorkoutType`, `.distanceSwimming`, `.activeEnergyBurned` |
| Leitura | `.distanceSwimming`, `.heartRate`, `HKWorkoutType` |
| Configuração | `HKWorkoutConfiguration`: `activityType = .swimming`, `swimmingLocationType = .pool`, `lapLength = HKQuantity(unit: .meter(), doubleValue: tamanhoRaiaM)` |
| Metadados | `HKMetadataKeyLapLength`, `HKMetadataKeySwimmingLocationType`, e chave própria `com.dablab.vounadar.tituloTreino` |

`Info.plist`, em português: `NSHealthShareUsageDescription` e `NSHealthUpdateUsageDescription` (copy em 15.10).

---

## 14. Exportação: copiar o treino como texto

Única saída do app. Não há importação, e não há figura de compartilhamento — imagem é território do Swim Builder e fica fora daqui de propósito (3.2).

**O caso de uso:** o nadador quer mandar o treino para alguém no WhatsApp, colar numa nota, ou imprimir. Um botão "Copiar como texto" no Detalhe põe o treino na área de transferência em texto puro.

### 14.1 Formato exato

Texto puro, UTF-8, quebra de linha `\n`. **Sem emoji, sem markdown, sem URL** — o destino é uma caixa de mensagem, onde asterisco e cerquilha viram lixo visual ou formatação indesejada.

```
Vou Nadar — 2.100 m
Raia de 25 m · descanso normal

AQUECIMENTO
1×300 crawl leve
4×50 pernada — 20s

PROGRESSÃO
6×50 crawl progressivo — 25s

PARTE PRINCIPAL
4×100 crawl forte — 30s
4×75 crawl com pull buoy — 25s
8×25 tiro com nadadeiras — 20s

SOLTURA
1×200 nado livre solto
```

### 14.2 Regras de montagem

| # | Regra |
|---|---|
| 14.2.1 | **Primeira linha:** `Vou Nadar — {distancia_total_m} m`, com separador de milhar em ponto (padrão pt-BR). Quando o treino tem título, a linha vira `{titulo} — {distancia_total_m} m` |
| 14.2.2 | **Segunda linha:** `Raia de {n} m · descanso {curto\|normal\|longo}`. Ela existe porque o treino só faz sentido na piscina para a qual foi gerado (regra 11.3) — quem recebe precisa saber disso |
| 14.2.3 | **Cabeçalho de seção em caixa alta**, sem acentuação alterada: `AQUECIMENTO`, `PROGRESSÃO`, `PARTE PRINCIPAL`, `SOLTURA`. Aqui a caixa alta é correta — é texto puro sem tipografia, e é o único recurso de hierarquia disponível |
| 14.2.4 | **Seção vazia é omitida inteira**, cabeçalho incluído |
| 14.2.5 | **Linha de série:** `{repeticoes}×{distancia_m} {nome_snapshot}`, e quando `descanso_seg > 0`, ` — {descanso_seg}s` no fim. O `×` é o sinal de multiplicação U+00D7, não a letra x |
| 14.2.6 | A distância na linha é a **real, já adaptada à raia** (regra 11.3). Numa piscina de 16 m sai `4×96`, igual à tela |
| 14.2.7 | Uma linha em branco entre seções. **Nenhuma linha em branco no fim** — o WhatsApp preserva e fica feio |
| 14.2.8 | **Nunca aparece:** tempo, ritmo, pace, frequência cardíaca, calorias, data, hora, localização, nome de usuário, URL, QR code, nome de arquivo |
| 14.2.9 | Copiar dispara háptico de sucesso e a confirmação 15.19. Sem folha, sem tela intermediária: **um toque e acabou** |

### 14.3 Onde fica

Botão "Copiar como texto" no Detalhe do treino (P2), na barra de navegação junto com as outras ações secundárias — **não** como um terceiro botão grande empilhado. No relógio não existe: copiar para área de transferência não tem destino útil no pulso.

---

## 15. Copy e tom de voz

Texto final, não placeholder. Direto, sem exclamação, sem gerúndio de call-center. O nadador está com pressa e molhado.

| # | Onde | Texto |
|---|---|---|
| 15.1 | P1 — botão principal | `Gerar treino` |
| 15.2 | P1 — bloqueado sem piscina | `Configure o tamanho da piscina para gerar treinos.` |
| 15.3 | P6/W5 — título | `Tamanho da piscina` |
| 15.4 | W3 — favoritos vazio | `Nenhum treino salvo.\nFavorite um treino no iPhone e ele aparece aqui.` |
| 15.5 | P5 — explicação do ritmo | `Ajusta o descanso de todo o treino. Curto para quem já tem fôlego, longo para quem está voltando.` |
| 15.6 | W4 — linha da piscina | `Raia de {n} m` |
| 15.7 | W8 — rótulo do descanso | `DESCANSO` |
| 15.8 | W10 — encerrado antes | `{real} m de {planejado} m` |
| 15.9 | W11 — falha ao iniciar | `Não foi possível iniciar o treino. Tente de novo.` |
| 15.10 | Info.plist | Leitura: `O Vou Nadar usa a distância nadada para acompanhar o treino e contar o descanso.` Escrita: `O Vou Nadar salva seu treino de natação no app Saúde.` |
| 15.11 | W11 — sem autorização | `O Vou Nadar precisa do app Saúde para contar as voltas. Sem isso, o treino não avança sozinho.` |
| 15.12 | W10 — descartado por curto | `Treino muito curto. Nada foi salvo.` |
| 15.13 | W10 — falha ao salvar | `O treino não foi salvo no app Saúde. Os dados ficaram no relógio.` |
| 15.14 | P7 — paywall, título | `Continue nadando com o Vou Nadar` |
| 15.15 | P7 — paywall, corpo | `Compra única. Sem assinatura, sem mensalidade, sem anúncio. Vale para sempre, em todos os seus aparelhos.` |
| 15.16 | P3 — favoritos vazio | `Nenhum treino salvo ainda.\nGere um treino e toque em Favoritar.` |
| 15.17 | P1 — repertório curto (regra 11.19) | `Com essa piscina e esses filtros sobram poucos exercícios, então os treinos vão se repetir. Marcar mais equipamento ajuda.` |
| 15.18 | P2 — nota de adaptação, quando `distancia_m ≠ distancia_catalogo_m` em alguma série | `As distâncias foram ajustadas para fechar voltas inteiras na sua piscina de {n} m.` |
| 15.19 | P2 — confirmação de cópia | `Treino copiado.` |
| 15.20 | P2 — rótulo da ação | `Copiar como texto` |

---

## 16. Direção visual

App consumer nas duas telas — **não** se aplica padrão de menu lateral.

### 16.0 Paleta

O ícone do app ("A raia") definiu a marca. **Todos os contrastes abaixo foram calculados, não estimados.**

**Tema escuro — o padrão do app:**

| Token | Hex | Papel |
|---|---|---|
| `fundo` | `#061620` | Fundo da tela |
| `superficie_agrupada` | `#0C2531` | Fundo do `List` inset grouped |
| `superficie_elevada` | `#12313F` | Folhas, alertas |
| `destaque` | `#0E9BC4` | Tint do sistema. 5,69:1 sobre o fundo |
| `texto_primario` | `#EAF4F8` | 16,44:1 |
| `texto_secundario` | `#8FA9B6` | 7,45:1 sobre o fundo, 6,43:1 sobre a superfície |
| `hairline` | `#1C3A48` | Separador |

**Tema claro:**

| Token | Hex | Papel |
|---|---|---|
| `fundo` | `#F4F8FA` | |
| `superficie_agrupada` | `#FFFFFF` | |
| `superficie_elevada` | `#E9F1F5` | |
| `destaque` | `#0A7593` | **Tint diferente do escuro, de propósito.** 5,28:1 sobre branco. O `#0E9BC4` daria 3,23:1 e reprovaria o requisito 17.9 |
| `texto_primario` | `#0B1B23` | 17,57:1 |
| `texto_secundario` | `#5A7285` | 5,02:1 |
| `hairline` | `#DBE6EC` | |

**Semânticas, reservadas a significado — nunca decorativas:**

| Papel | Escuro | Claro |
|---|---|---|
| Sucesso | `#30D158` | `#1F8A55` |
| Alerta | `#FF9F0A` | `#9A6B10` |
| Erro / destrutivo | `#FF453A` | `#B3352C` |

**Cores das quatro seções do treino** — um ponto pequeno **ou** um traço fino de 3 pt junto ao cabeçalho da `Section`, ou nada. **Nunca fundo, nunca faixa de card:** Aquecimento `#5AA9E6` · Progressão `#0E9BC4` · Parte principal `#E8813C` · Soltura `#8FA9B6`.

**Apple Watch** — paleta própria, sem relação com o tema do iPhone: fundo `#000000`, NADANDO `#0E9BC4` (6,50:1), DESCANSANDO `#FF9F0A` (10,22:1), últimos 3 s `#30D158` (10,39:1), Encerrar `#FF453A` (6,16:1).

**Três restrições que saem desses números e não são negociáveis:**

1. **O azul de marca marca interação e estado, não preenche superfície.** Ele aparece no glyph da aba ativa, no marcador de seleção, no rótulo de um botão, no tint de um `Toggle` ligado, no traço do gráfico. **Não** aparece como fundo de card, fundo de pílula, faixa larga ou bloco de cor.
2. **`#0E9BC4` não serve de fundo para texto branco** — 3,23:1, abaixo do AA de 4,5:1. No tema claro, use `#0A7593` como tint; para um botão de fundo sólido, use `azul_profundo` `#06485C`, que dá 10,05:1 com branco.
3. **Âmbar e verde têm 1,02:1 de contraste entre si.** Para quem tem deuteranopia — o daltonismo mais comum — os dois estados do relógio ficam indistinguíveis, justamente na transição que avisa "prepara pra sair". A cor **não pode ser o único sinal**: ver o requisito 17.12.

### 16.1 iPhone — componentes nativos, não desenho próprio

**Este app tem que parecer construído com os componentes do iOS, porque vai ser.** Esta seção existe porque a primeira rodada de design produziu telas que pareciam app genérico — dashboard, não iOS.

**Teste de uma frase:** se a tela, em modo claro e sem a cor de marca, pudesse ser confundida com uma tela dos Ajustes do iOS, está certa. Se parece um dashboard, está errada.

**Estrutura — a parte que mais importa.** Componentes do sistema com os valores **padrão** deles. Não inventar contêiner, não especificar padding, não especificar raio de canto:

| Tela | Componente |
|---|---|
| Home, Favoritos, Ajustes, Piscina | `List` estilo inset grouped |
| Detalhe do treino | numeral herói + `List` com 4 `Section` |
| Histórico | números soltos + gráfico + `List` |
| Folhas | `sheet` com detents |
| Botão primário | barra inferior de área segura, estilo glass prominent |

Agrupamento vem da `Section` e do espaço em branco, **não de retângulos com fundo**. Separadores são os do `List`. Quem desenha fundo, canto e inset é o `List`.

Contêiner desenhado à mão é permitido em **exatamente dois lugares**: o bloco do numeral herói no Detalhe, e o gráfico de volume no Histórico. Em todo o resto, componente do sistema.

**Tipografia — regra dura.** Somente os onze estilos semânticos do iOS. **Nenhum tamanho fixo em pontos, em lugar nenhum:** `largeTitle · title · title2 · title3 · headline · subheadline · body · callout · footnote · caption · caption2`.

| Elemento | Estilo |
|---|---|
| Título de tela | `largeTitle` que **encolhe** para o título da barra ao rolar |
| Distância total (herói) | `largeTitle` em SF Pro Rounded Bold, dígitos monoespaçados |
| Cabeçalho de seção | o header padrão da `Section`, em **Title Case** |
| Nome do exercício | `body` |
| Metragem e descanso | `body` monoespaçado, cor secundária, à direita |
| Descrição do exercício | `footnote`, cor secundária |
| Selo de modo | `caption2`, cor secundária, com SF Symbol antes — **sem pílula colorida** |

SF Pro do sistema. SF Pro Rounded **apenas** no numeral herói.

**Navegação.** `TabView` nativa, três abas: Treino · Favoritos · Histórico. Glyph ativo no tint; a cápsula atrás dele é do **sistema** e não é redesenhada em cor de marca. Ajustes é uma engrenagem na barra de navegação da Home, não uma aba. Sem menu lateral, sem botão flutuante próprio.

**Ícones:** SF Symbols, sempre. Nenhum SVG desenhado à mão.

**Movimento:** ao gerar, o numeral da distância anima de 0 ao valor final em 0,4 s com easeOut. É o único momento de espetáculo do app. Com Reduce Motion, aparece direto.

**Onze reprovações automáticas:**

1. Tudo dentro de um card; card dentro de card.
2. Mais de onze tamanhos de fonte. Qualquer tamanho fixo em pontos.
3. Vários raios de canto diferentes.
4. A cor de marca preenchendo superfície (pílula sólida, botão sólido no meio do conteúdo, barra sólida).
5. "Chips" — não é idioma de iOS, é Material Design.
6. Cabeçalho de seção em **CAIXA ALTA com letter-spacing**.
7. Título grande estático, que não encolhe ao rolar.
8. Números dentro de caixas de largura fixa.
9. Paddings fora de qualquer grade.
10. Ícones desenhados à mão em vez de SF Symbols.
11. `Toggle`, slider e linha de lista redesenhados do zero.

### 16.2 Apple Watch

| Item | Definição |
|---|---|
| **Referência declarada** | O app Treino nativo da Apple. É o vocabulário visual que o nadador já lê com o braço molhado; imitar a hierarquia reduz o custo de aprendizado a zero |
| **Fundo** | Preto puro (`#000000`). OLED: pixel apagado não consome bateria e dá o contraste máximo. Nunca cinza escuro |
| **Tipografia** | SF Compact Rounded. **A contagem regressiva de descanso é o maior elemento do app** — 52 pt bold no mínimo. Nada abaixo de 15 pt |
| **Cor por estado** | NADANDO: `azul_marca` `#0E9BC4`. DESCANSANDO: `ambar_descanso` `#FF9F0A`. Últimos 3 s: `verde_saida` `#30D158`. Todos acima de 10:1 sobre preto — mas ver o requisito 17.12, porque âmbar e verde não se distinguem por cor sozinha |
| **Densidade** | Tela de execução: no máximo três elementos de texto |
| **Modo** | Escuro sempre — o relógio é escuro |
| **Always-On** | Luminância reduzida: estado e número, sem animação, sem cor saturada |
| **Área de toque** | Mínimo 44×44 pt, lembrando que na água nenhum botão é alcançável (0.1) |
| **Livre para o agente** | Ícone da complication, curva da transição entre estados, layout exato do resumo |

---

## 17. Requisitos não-funcionais

| # | Requisito | Alvo |
|---|---|---|
| 17.1 | Abertura do app watchOS até tela útil | ≤ 2 s em Series 7 |
| 17.2 | Geração de treino | ≤ 1 s nos dois aparelhos |
| 17.3 | Legibilidade da contagem de descanso | Legível a 40 cm com braço em movimento; ≥ 52 pt |
| 17.4 | Latência entre fim da repetição e início da contagem de descanso | ≤ 5 s (limitada pela amostragem do HealthKit — risco R3) |
| 17.5 | Bateria em sessão de 60 min | ≤ 15% em Series 7 com Always-On |
| 17.6 | Offline | 100% das funções sem rede e sem iPhone, exceto compra |
| 17.7 | Tamanho instalado | iOS ≤ 30 MB, watchOS ≤ 15 MB |
| 17.8 | Compatibilidade | iOS 18+, watchOS 11+, caixas de 40 a 49 mm |
| 17.9 | Acessibilidade | Dynamic Type fora da tela de execução; VoiceOver em todas as telas de iPhone e em W1–W5 e W10; contraste mínimo AA |
| 17.10 | Volume de dados | 500 treinos e 2.000 sessões sem degradação perceptível |
| 17.11 | Idioma | pt-BR apenas, zero string em `View` |
| 17.12 | **Nenhum estado é sinalizado só por cor** | A transição para os últimos 3 segundos do descanso — o aviso de "prepara pra sair" — precisa de pelo menos dois canais além da cor: o háptico da regra 11.9 e uma mudança visual não-cromática (o número cresce e pulsa uma vez por segundo). Âmbar `#FF9F0A` e verde `#30D158` têm 1,02:1 de contraste entre si; para um usuário com deuteranopia eles são a mesma cor. Vale para qualquer estado do app, não só esse |

---

## 18. Convenções de código, documentação e estrutura

- **Idioma.** Banco em **português**, `snake_case`, preservado por `@Attribute(originalName:)`; enums com `rawValue` em português. Código, variáveis, funções e nomes de arquivo em **inglês**. Interface e comentários em português.
- **Comentários obrigatórios.** Toda função, view, view model, repositório e rotina de sincronização leva cabeçalho em português dizendo o que faz, o que recebe, o que devolve e **qual regra deste spec implementa, com o número**. Exemplo: `// Encerra a repetição quando as voltas previstas são atingidas (regra 11.7)`. Comentário que repete a sintaxe é ruído; o que nomeia a regra é o que salva o projeto daqui a seis meses.
- **`CLAUDE.md` na raiz** — mapa dos três targets, a regra de que `Domain/` e `Data/Models/` não importam framework de plataforma, os comandos (`xcodegen generate`, build e teste dos dois targets), a advertência de que o `.xcodeproj` não é versionado nem editado à mão, e a obrigação de manter os docs em dia.
- **Documentação no mesmo commit.** `CLAUDE.md`, `DOCUMENTACAO-TECNICA.md` e `README` acompanham a mudança que os afeta.
- **Variáveis de ambiente:** nenhuma. O projeto não tem segredo, chave nem endpoint. Se aparecer uma, é sinal de que alguém está introduzindo backend contra o anti-escopo.

---

## 19. Documento de documentação técnica (entregável)

Ao fim da implementação, gerar `DOCUMENTACAO-TECNICA.md` na raiz, em português, descrevendo o sistema **como ficou**, não como foi planejado:

1. **Modelo de dados explicado** — cada entidade: para que serve, o que cada coluna significa em linguagem de negócio, quais valores cada enum aceita e o que cada valor quer dizer.
2. **Relacionamento entre as tabelas** — diagrama em texto e uma frase de cardinalidade por relação, no vocabulário do produto.
3. **Regras que vivem fora da tela** — como não há SQL, esta seção lista as **rotinas de domínio e sincronização**: gerador, calculadora de descanso, contagem de voltas, resolução de `atualizado_em`, verificação de compra, gravação no HealthKit. Nome exato do tipo e da função, quando roda, o que faz.
4. **Mapa tela → dados** — para cada tela de P1–P7 e W1–W11: o que lê, o que escreve, por qual rotina passa.
5. **Lógica por tela** — o que é validado, gravado e calculado em cada ação, onde, e o que o usuário vê em caso de erro.
6. **Divergências em relação a este spec** — o que ficou diferente e por quê. Sem esta seção o documento envelhece mentindo.

---

## 20. Privacidade, segurança e conformidade

Este app grava e lê **dado sensível de saúde**, o que o coloca sob o artigo 11 da LGPD.

| Aspecto | Definição |
|---|---|
| **Dados coletados** | Distância nadada, duração, frequência cardíaca durante a sessão, e a estrutura do treino executado |
| **Base legal** | Consentimento específico e destacado, dado na tela de autorização do HealthKit do próprio sistema. Não há outra coleta a consentir |
| **Onde ficam** | Exclusivamente no aparelho: SwiftData local e o banco do HealthKit, que é da Apple e do usuário — não do Vou Nadar |
| **Quem acessa** | Somente o usuário. Não há servidor, operador nem terceiro |
| **Retenção** | Indefinida, sob controle do usuário. Sessões saem pelos Ajustes; os `HKWorkout` saem pelo app Saúde, e o app **não** os apaga junto — dado de saúde do usuário não é do app |
| **Exportação** | Pelo app Saúde, que já oferece exportação completa. Não reimplementar |
| **Analytics** | **Nenhuma.** Sem SDK de terceiro, sem crash reporter de rede, sem identificador |
| **Ficha da App Store** | "Dados não coletados". Gravar no HealthKit do próprio usuário não é coleta pelo desenvolvedor — mas revise o questionário de privacidade antes de submeter |
| **Segredos** | Nenhum existe. Se aparecer um, é desvio de arquitetura |
| **Superfície de risco** | Não há rede. O vetor relevante é gravar dado de saúde **errado** por piscina mal configurada (risco R1), não vazamento |

Não há IA embarcada, portanto não há guardrail de modelo a definir.

---

## 21. Métricas de sucesso

Sem telemetria (seção 20), as métricas são observadas fora do produto. Restrição consciente: coletar comportamento contradiz a promessa de privacidade.

| Métrica | Alvo | Prazo | Fonte |
|---|---|---|---|
| Convesão para a compra entre quem executou 3 treinos | ≥ 15% | 90 dias | App Store Connect |
| Avaliação média | ≥ 4,0 | 120 dias | App Store Connect |
| Menção a "descanso" ou "relógio" nas avaliações | qualitativa, ler todas | contínuo | App Store Connect |

---

## 22. Estratégia de teste

| O que | Como |
|---|---|
| Integridade do catálogo | Teste que valida os 226 na carga: `metros_totais` correto, ids únicos, equipamento existente, enums válidos |
| Calculadora de descanso (11.5) | Teste dos 7 exemplos da tabela, um a um, mais varredura dos 226 nos três ritmos verificando o intervalo 10–90 s |
| Gerador (11.1 a 11.4) | Teste de propriedade: 500 gerações com sementes variadas, verificando quatro seções, faixa de distância sobre o total adaptado, filtro de equipamento, adaptação à raia, interruptores respeitados |
| Adaptação à raia (11.3) | Varredura dos 226 exercícios em raias de 10, 12, 15, 16, 18, 20, 25 e 50 m, verificando: `distancia_m` é sempre múltiplo exato da raia; `voltas_por_repeticao ≥ 1`; nenhum exercício sorteado passa de 25% de desvio; a contagem de utilizáveis bate com a tabela de 11.3 detalhado |
| Repertório curto (11.19) | Teste que monta a combinação mais restritiva (raia 50, sem equipamento, sem educativo, sem pernada) e verifica que o aviso dispara e a geração **não** é bloqueada |
| Máquina de estados (12.2) | Teste de transição, incluindo as proibidas |
| Contagem de voltas (11.7) | Teste com distâncias simuladas, sem HealthKit real |
| Sincronização (11.12) | Teste que serializa 500 favoritos e verifica que nenhum lote passa de 65.536 bytes |
| Compra (11.17) | Arquivo `.storekit` local: compra, restauração, falha de verificação |
| Texto copiado (seção 14) | Teste de igualdade **exata** contra uma string esperada, para um treino com seção vazia, um em piscina de tamanho incomum, e um com título. Verifica o `×` U+00D7, a ausência de linha em branco final e a ausência de markdown |
| **Execução em água** | **Teste manual obrigatório em piscina real antes de submeter.** Simulador não reproduz Water Lock, amostragem nem detecção de volta. Mínimo: uma sessão em 25 m, uma em 50 m, e uma encerrada antes do planejado |
| Sem iPhone | Teste manual com o iPhone desligado: gerar, executar, encerrar, gravar |
| Autorização negada | Teste manual recusando o HealthKit na primeira execução |

---

## 23. Riscos e mitigação

| # | Risco | Impacto | Probab. | Mitigação |
|---|---|---|---|---|
| R1 | **Piscina configurada errada.** Nada em 50 m com o app em 25 m: toda a distância sai errada, o descanso dispara na hora errada e o HealthKit recebe dado falso | Alto | Média | `Raia de {n} m` destacado na tela W4, tocável. Não há detecção automática possível |
| R2 | **Piscinas grandes empobrecem o repertório de técnica.** Em raia de 50 m saem 23 exercícios, e **12 dos 32 educativos são blocos de 25 m** — com o interruptor de educativos ligado numa piscina olímpica, os treinos ficam repetitivos. Em 16 e 18 m saem os mesmos 21 blocos de 25 m | Médio | Média | Verificado numericamente (11.3 detalhado). Mitigação de produto: aviso da regra 11.19. Mitigação de conteúdo: criar variantes de 50 m e de 100 m dos educativos numa release seguinte — hoje as distâncias dos educativos são só 25, 50 e 100 m |
| R2b | **A adaptação de distância confunde o usuário.** Ele pediu um treino e recebeu `4×96` em vez de `4×100`, e acha que o app errou | Baixo | Alta | Copy 15.18 explicando na tela do treino, e a distância real exibida em todo lugar — nunca mostrar a do catálogo e nadar outra |
| R3 | **Atraso na detecção de volta** faz o descanso começar tarde e o nadador sair errado | Alto | Alta | Alvo de 5 s no requisito 17.4. Aceitar o atraso como parte do produto (11.8) e nunca punir o nadador por ele (11.10). Saída manual sempre disponível desbloqueando a coroa |
| R4 | **Bateria** em sessão longa com Always-On em Series 6 | Médio | Média | Requisito 17.5 medido em Series 7; reduzir atualização de UI com `isLuminanceReduced`; medir em Series 6 antes de publicar |
| R5 | **Tabela de descanso mal calibrada** — o número parece certo no papel e é errado na água | Alto | Média | Teste manual em piscina é critério de DoD, não sugestão. A tabela é código, corrigível numa release, e o snapshot em `serie_treino` garante que treino salvo não muda sozinho |
| R6 | **App morto pelo sistema** no meio da sessão | Médio | Baixa | Recuperar a `HKLiveWorkoutBuilder` ativa ao reabrir (12.2) |
| R7 | **Review da Apple** questiona HealthKit | Médio | Baixa | Strings de uso em português explicando a finalidade real (15.10) |
| R8 | **Nome indisponível** na App Store | Baixo | Média | Reservar "Vou Nadar" no App Store Connect **antes** de escrever código (premissa P1) |
| R9 | **Canibalização do Swim Builder** — dois apps do mesmo autor disputando a mesma busca | Baixo | Média | Posicionamento distinto na ficha: o Swim Builder monta treino, o Vou Nadar executa treino no pulso. Reavaliar em 6 meses se vale descontinuar um |

---

## 24. Assunções declaradas

**Revise antes de gerar código.** Assunção não revisada vira verdade no minuto em que o agente começa a implementar.

| # | Assunção | Se discordar |
|---|---|---|
| 24.1 | Nome do app: **Vou Nadar**. Bundle `com.dablab.vounadar` | Diga outro nome antes do início — ele entra em bundle ID, `project.yml` e design |
| 24.2 | O `WorkoutGenerator` é **copiado e adaptado** do Swim Builder, não reescrito. Ganha os parâmetros de raia e de descanso | Se preferir reescrever do zero, o épico 8.4 cresce bastante |
| 24.3 | Faixa de raia aceita: **10 a 50 m**, com atalhos de 25 e 50. Cobre piscina de condomínio (12, 15, 16, 18, 20 m) e olímpica | Diga outros limites |
| 24.3b | Guarda de desvio da adaptação: **25%**. Acima disso o exercício sai do sorteio (11.3) | Um limite maior mantém mais exercícios e distorce mais; um menor faz o contrário |
| 24.4 | Distância mínima para gravar sessão: **25 m** | Diga outro número |
| 24.5 | Paywall: gerar é sempre livre; as **3 primeiras execuções guiadas** são livres, a 4ª leva ao paywall. O valor do produto está em executar, não em gerar — o paywall fica onde o valor está | Se preferir espelhar o Swim Builder (5 gerações grátis), muda o épico 8.11 |
| 24.6 | Descanso entre séries **30 s** e entre seções **45 s**, ambos ajustados pelo ritmo global (11.6) | Diga outros valores |
| 24.7 | Frequência cardíaca é coletada (vem de graça com a sessão) mas **não é exibida** no v1 | Exibir é uma linha na tela W7 |
| 24.8 | O catálogo é copiado na `versao_catalogo` 1, com os 226 exercícios, sem alteração | Se quiser podar exercícios que não fazem sentido com descanso fixo, é decisão de conteúdo antes do 8.1 |
| 24.9 | Treinos gerados no relógio ficam só no relógio no v1 (11.18) | Subir para o iPhone exige sync Watch→iPhone, que é v2 |
| 24.10 | Não há tela de edição de treino em nenhum aparelho | Se quiser editar, o princípio 0.2 precisa ser revisto primeiro |

---

## 25. Perguntas abertas

O agente de código **pergunta em vez de assumir** ao cruzar com qualquer item.

| # | Pergunta | Quem decide |
|---|---|---|
| Q1 | Copiar o `WorkoutGenerator` do Swim Builder ou reescrever? A 24.2 assume copiar, mas o algoritmo de lá não conhece raia nem descanso | Alexandre |
| Q2 | O nome "Vou Nadar" está disponível no App Store Connect? | Alexandre, antes do 8.1 |
| ~~Q3~~ | ~~Qual o azul de marca (hex) e o ícone do app?~~ **RESOLVIDA em 06/09/2026:** ícone "A raia", `azul_marca` `#0E9BC4` e `azul_profundo` `#06485C`. Ver 16.0 | — |
| Q4 | Piscina de 50 m e o repertório de técnica: aceitar os 12 educativos a menos no v1, ou criar variantes de 50 m e 100 m dos educativos antes de publicar? (risco R2) | Alexandre |
| Q5 | Quando a faixa de distância não fecha nem repetindo exercício, o que vence: treino menor que o pedido, ou exercício repetido dentro do mesmo treino? | Alexandre |
| Q6 | A guarda de desvio de 25% (24.3b) está calibrada? Ela é o que decide se um bloco de 25 m entra numa piscina de 16 m como 32 m | Alexandre, idealmente depois de nadar uma vez |

---

## 26. Definition of Done

- [ ] Todos os critérios de aceite dos épicos 8.1 a 8.12 verificados um a um
- [ ] Banco em português conforme 7.0, sem entidade ou propriedade fora do padrão
- [ ] Todas as rotinas comentadas em português com o número da regra que implementam
- [ ] Testes de propriedade do gerador passando (500 gerações)
- [ ] Varredura da tabela de descanso sobre os 226 nos três ritmos, sem valor fora de 10–90 s
- [ ] Varredura da adaptação à raia nas oito piscinas da tabela de 11.3 detalhado, com as contagens batendo
- [ ] **Teste manual em piscina real**, com pelo menos três sessões (25 m, uma piscina de tamanho incomum, e uma encerrada antes do planejado)
- [ ] Teste manual com o iPhone desligado: gerar → executar → gravar
- [ ] `DOCUMENTACAO-TECNICA.md` gerado com os seis itens da seção 19, conferido contra o implementado
- [ ] `CLAUDE.md` e `README` criados e em dia
- [ ] Strings de uso do HealthKit em português no `Info.plist`
- [ ] Questionário de privacidade da App Store revisado (seção 20)
- [ ] Requisitos 17.1, 17.2 e 17.5 medidos em aparelho real, não no simulador
- [ ] Requisito 17.12 verificado: a tela de execução foi conferida em simulação de daltonismo (Xcode → Environment Overrides → Color Blindness), e a transição para os últimos 3 segundos continua legível sem cor
- [ ] Ícone entregue nas três variantes do iOS 18 (clara, escura, tingida) mais a circular do watchOS, sem alfa e sem cantos arredondados desenhados
- [ ] Build sem warning nos dois targets
- [ ] Screenshots de iPhone e de Apple Watch na ficha da loja

---

## 27. Próximos passos operacionais

1. **Reservar "Vou Nadar" no App Store Connect** e confirmar o bundle ID. É a única coisa que precisa acontecer antes de tudo.
2. Revisar a seção 24 e responder o que der da seção 25.
3. Criar o repositório `vou-nadar` vazio, com este spec, o `.dbml` e o prompt de design dentro.
4. Copiar `catalogo_exercicios.json` e `tipos_equipamento.json` do Swim Builder para `VouNadar/Resources/`.
5. Abrir o Claude Code na raiz e colar o prompt de implementação.
6. Gerar as telas no Claude Design a partir do `prompt-design-vou-nadar.md`, e salvar o material exportado no repositório como referência de UI.
7. Implementar 8.1 e 8.2 e validar os testes **antes** de seguir.
8. Testar em piscina antes de qualquer submissão.

---

## 28. Roadmap: próximas releases

### 28.1 (v2) Intervalo de saída — *sai a cada X*
Alternativa ao descanso fixo: `4×100 saindo a cada 2:00`. O relógio conta do início de cada repetição, não do fim. Depende de 28.2 para o usuário saber escolher um intervalo que faça sentido. Adiciona um campo `tipo_tempo` em `serie_treino` e uma escolha nos Ajustes.

### 28.2 (v2) Pace base e tempo estimado
Campo de pace em `preferencias` (segundos por 100 m). Habilita: tempo estimado do treino antes de gerar, tempo-alvo por série, e o intervalo de saída do 28.1. Exige tabela de multiplicadores por intensidade, modo e equipamento, a calibrar com dados reais.

### 28.3 (v2) Editar o descanso bloco a bloco
Override de `descanso_seg` por série na tela P2. Só entra se a tabela da 11.5 se mostrar errada na prática — e nesse caso, corrigir a tabela pode ser a resposta melhor.

### 28.4 (v2) Outros nados e medley
O enum `nado` já tem os cinco valores, então não há migração. Falta conteúdo: exercícios de costas, peito, borboleta e medley, mais um seletor de foco na Home.

### 28.5 (sem release) Águas abertas
`swimmingLocationType = .openWater`, sem `lapLength`, distância por GPS. Sem volta contada, o modelo inteiro de repetição e descanso deixa de funcionar — os blocos teriam que virar por tempo. É praticamente outro produto.

### 28.6 (sem release) Sincronização por iCloud
SwiftData + CloudKit privado. Custo zero. O trabalho: todo atributo opcional ou com default, relações opcionais com inverse, política de conflito, e migração do que já está em disco. Destrava o 28.7.

### 28.7 (sem release) Treino gerado no relógio subindo para o iPhone
Bloqueado pela regra 11.18 e pelo princípio 0.7 no v1. Depende do 28.6 ou de um canal Watch→iPhone com resolução de conflito.

### 28.8 (sem release) Widget de Smart Stack
Cartão que aparece por contexto — perto do horário habitual, ou ao chegar na academia — sugerindo o treino do dia.

---

## 29. Protocolo de mudanças incrementais

Depois do v1 pronto, para um ajuste não virar reescrita:

1. **Commit de checkpoint** antes de qualquer mudança, para ter um `git diff` confiável.
2. **Não colar este spec inteiro de novo.** Colar só o trecho novo ou alterado.
3. Escrever a instrução **como diff**, deixando explícito que o projeto existe e funciona.
4. **Delimitar nominalmente o que não deve mudar.**
5. Pedir a **lista de arquivos** que serão criados/alterados antes do código, e aprovar.
6. Revisar o `git diff` contra o plano aprovado; reverter arquivo que passou do escopo.
7. Exigir a atualização do `DOCUMENTACAO-TECNICA.md` no mesmo commit.

**Modelo de prompt para colar:**

```
O projeto Vou Nadar já existe e funciona. NÃO reescreva nada que não seja
pedido aqui.

Mudança pedida:
[descreva só o que muda]

Não pode mudar: o gerador, a calculadora de descanso, o modelo de dados, e
nenhum arquivo que não esteja na lista que você vai me mostrar.

Antes de escrever código: me mostre a lista de arquivos que você vai criar ou
alterar, e o que muda em cada um. Espere minha aprovação.

Ao final: atualize o DOCUMENTACAO-TECNICA.md no mesmo commit.
```

---

## Anexo — Fontes

Consultadas em 06/09/2026.

- [Water Lock no Apple Watch — Apple Support](https://support.apple.com/en-us/108352) — o Water Lock liga automaticamente em treino aquático e a tela não responde a toque enquanto está ligado. Origem do princípio 0.1.
- [Size limits for WatchConnectivity data transfers](https://blog.martinp7r.com/posts/size-limits-for-watchconnectivity-data-transfers/) — 65.536 bytes para `sendMessage` e `transferUserInfo`, 262.144 bytes para `updateApplicationContext`. Origem da regra 11.12.
- [watchOS 26 — aparelhos compatíveis (iClarified)](https://www.iclarified.com/97689/watchos-26-supported-devices-the-full-list-of-compatible-apple-watches) — watchOS 26 não cortou modelo nenhum: Series 6 e SE 2ª geração em diante, os mesmos do watchOS 11.
- [watchOS 27 — AppleInsider](https://appleinsider.com/inside/watchos-27) — o watchOS 27 corta Series 8 e anteriores. Base da decisão de mínimo em 4.3.
- [Delay on lap events from HKLiveWorkoutBuilder — Apple Developer Forums](https://developer.apple.com/forums/thread/128307) — origem do risco R3.
- [What's new in HealthKit — WWDC22](https://developer.apple.com/videos/play/wwdc2022/10005/)
- **Catálogo real do Swim Builder** (`catalogo_exercicios.json`, `versao_catalogo` 1, 226 exercícios), lido no repositório do Alexandre em 06/09/2026 — fonte de toda a estatística das seções 7.2, 9.3, 11.3 e 11.5.
