# Documentação Técnica — Vou Nadar

Entregável da seção 19 do `spec-vou-nadar.md`. Descreve o sistema **como ficou**,
não como foi planejado. Onde o implementado difere do spec, isso está na
**seção 6 — Divergências**, e não escondido no meio do texto.

Escrito contra o código em 06/09/2026: 67 arquivos de código-fonte, 206 testes em
20 suítes, iOS e watchOS compilando em Release sem nenhum warning.

**Sumário**

1. [Modelo de dados explicado](#1-modelo-de-dados-explicado)
2. [Relacionamento entre as tabelas](#2-relacionamento-entre-as-tabelas)
3. [Regras que vivem fora da tela](#3-regras-que-vivem-fora-da-tela)
4. [Mapa tela → dados](#4-mapa-tela--dados)
5. [Lógica por tela](#5-lógica-por-tela)
6. [Divergências em relação ao spec](#6-divergências-em-relação-ao-spec)

---

## 1. Modelo de dados explicado

Seis entidades persistidas em SwiftData, declaradas em
`VouNadar/Data/Schema/VouNadarSchema.swift` (`VouNadarSchemaV1`). O catálogo
**não** é uma delas: `catalogo_exercicios.json` e `tipos_equipamento.json` vivem
no bundle assinado, são somente-leitura e nunca entram no banco.

Cada aparelho tem o seu store. Não há CloudKit, não há servidor.

### 1.1 `Treino` — um treino gerado

O produto inteiro gira em torno desta linha. Um treino é um **programa**: ele já
nasce com todo o descanso decidido, e nada nele é recalculado depois.

| Propriedade | O que significa no negócio |
|---|---|
| `id` | Identidade do treino. Única, e é ela que viaja para o relógio |
| `titulo` | Nome dado pelo nadador ao favoritar ("Terça leve"). Nulo enquanto não é favorito |
| `origem` | Onde foi gerado: `gerado_iphone` ou `gerado_watch` |
| `distanciaTotalM` | Quantos metros o treino soma, **já adaptados à raia** |
| `distanciaMinSolicitadaM` / `distanciaMaxSolicitadaM` | A faixa que o nadador pediu. Guardada para explicar por que o total ficou onde ficou |
| `tamanhoRaiaM` | A piscina para a qual este treino foi gerado. **Congelada** |
| `ritmoDescansoUsado` | O multiplicador de descanso vigente na geração. **Congelado** |
| `comEducativos` / `comPernada` | Os dois interruptores como estavam na geração |
| `favorito` | Se está salvo na lista de Favoritos |
| `vezesExecutado` | Quantas sessões já foram gravadas para este treino |
| `ultimaExecucaoEm` | Quando foi a última. Nulo se nunca executado |
| `criadoEm` / `atualizadoEm` | Carimbos. `atualizadoEm` é o que decide conflito de sincronização |
| `arquivadoEm` | Data do descarte. **Não-nulo = sumiu das listas, mas o histórico continua íntegro** |

Um treino não-favorito e não-executado é lixo temporário: gerar outro
simplesmente o substitui.

**`origem_treino`** — `gerado_iphone` (padrão) e `gerado_watch`. Existe para a
regra 11.18: o relógio nunca edita nem apaga treino que veio do iPhone.

**`ritmo_descanso`** — `curto` (0,75× da tabela, para quem tem fôlego), `normal`
(1,0×, o padrão) e `longo` (1,5×, para quem está voltando).

### 1.2 `SecaoTreino` — uma das quatro partes

Todo treino tem as **quatro** seções, sempre nessa ordem, mesmo quando alguma
fica vazia num treino curto.

| Propriedade | O que significa |
|---|---|
| `tipoSecao` | Qual das quatro partes |
| `ordem` | 1 a 4. É a ordem de execução, e ela é a autoridade — não a ordem em que o SwiftData devolve a relação |
| `distanciaAlvoM` | Quantos metros o gerador tentou colocar aqui |
| `descansoPosSecaoSeg` | Pausa **depois** desta seção. Zero na última |

**`tipo_secao`** — `aquecimento` (soltar), `progressao` (subir o ritmo),
`principal` (o miolo do treino) e `soltura` (descer).

### 1.3 `SerieTreino` — um bloco a nadar

A unidade que o nadador de fato executa: `4×100 crawl · 30 s`.

| Propriedade | O que significa |
|---|---|
| `exercicioId` | Referência **lógica** ao catálogo. Sem chave estrangeira, porque o catálogo não está no banco |
| `repeticoes` | Quantas vezes repetir |
| `distanciaM` | Metros de cada repetição, **já adaptados à raia** |
| `distanciaCatalogoM` | Os metros originais do catálogo. Guardados para mostrar "ajustado à sua piscina" |
| `metrosTotais` | `repeticoes × distanciaM` |
| `descansoSeg` | Pausa **entre repetições**. Zero quando `repeticoes == 1` — não existe intervalo dentro de uma repetição só |
| `descansoPosSerieSeg` | Pausa **depois** da série. Zero na última série da seção, onde quem manda é o descanso de seção |
| `voltasPorRepeticao` | Quantas idas-e-vindas cada repetição tem, nesta piscina. É o que o relógio conta debaixo d'água |
| `nomeSnapshot` / `descricaoSnapshot` | Cópia do texto do catálogo no momento da geração. Atualizar o app não muda treino salvo |
| `equipamentoExigido` | `nenhum`, `pullbuoy`, `palmar`, `prancha`, `nadadeira` ou `snorkel` |
| `modo` | `nado`, `pernada` ou `educativo` |
| `intensidade` | `leve`, `aerobico`, `forte` ou `sprint` |
| `ordem` | Posição dentro da seção |

Os campos com "snapshot" no nome, mais `distanciaM`, `descansoSeg` e
`voltasPorRepeticao`, são o princípio 0.6 escrito no schema: o treino salvo é
**imutável**.

### 1.4 `Preferencias` — a configuração, uma linha só

Nasce na primeira abertura e nunca é apagada, exceto por "Apagar todos os dados".

| Propriedade | O que significa | Padrão |
|---|---|---|
| `distanciaMinM` / `distanciaMaxM` | A faixa pedida na geração | 1.500 / 2.500 |
| `incluirEducativos` | Deixar entrar exercícios de técnica | falso |
| `incluirPernada` | Deixar entrar blocos de perna | falso |
| `tamanhoRaiaM` | A piscina de sempre, de 10 a 50 m | 25 |
| `raiaConfirmada` | Se o nadador **já disse** qual é a piscina. Falso bloqueia a geração | falso |
| `ritmoDescanso` | Multiplicador global do descanso | `normal` |
| `versaoCatalogoVisto` | Última versão de catálogo que o app viu | 0 |
| `atualizadoEm` / `criadoEm` | Carimbos. `atualizadoEm` resolve conflito entre aparelhos | — |

`raiaConfirmada` separado de `tamanhoRaiaM` é deliberado: 25 é um padrão
plausível, mas gerar um treino inteiro para a piscina errada é pior que perguntar.

### 1.5 `EquipamentoSelecionado` — o que está na mochila

Uma linha por equipamento marcado, com `equipamentoId` único. **Zero linhas é
estado normal**: 168 dos 226 exercícios não exigem equipamento nenhum.

Desmarcar apaga a linha de verdade — isto é configuração, não histórico.

### 1.6 `SessaoNatacao` — uma execução

| Propriedade | O que significa |
|---|---|
| `treino` | Qual treino foi executado. Fica nulo se o treino for apagado — a sessão sobrevive |
| `tituloSnapshot` | O nome do treino no dia. É o que o Histórico mostra quando o treino não existe mais |
| `iniciadaEm` / `encerradaEm` | Início e fim. `encerradaEm` nulo = sessão em andamento |
| `distanciaPlanejadaM` | O que o treino previa |
| `distanciaRealM` | O que o HealthKit mediu. Pode ser menor **ou maior** |
| `seriesConcluidas` / `repeticoesConcluidas` | Até onde foi |
| `healthkitWorkoutUuid` | O `HKWorkout` correspondente. Nulo quando a gravação falhou |
| `tamanhoRaiaM` | A piscina daquele dia |
| `motivoEncerramento` | Por que terminou. Nulo enquanto em andamento |

**`motivo_encerramento`** — `concluido` (nadou até o fim), `encerrado_antes`
(parou antes; **não é erro**, e o `HKWorkout` grava a distância real),
`descartado_curto` (menos de 25 m: nada vai para o app Saúde, para um toque
acidental não virar registro de saúde) e `falhou` (a gravação do `HKWorkout` não
deu certo; a sessão fica no relógio e o nadador é avisado).

---

## 2. Relacionamento entre as tabelas

```
                     ┌─────────────────────┐
                     │     Preferencias    │   uma linha, sem relação
                     └─────────────────────┘

                     ┌──────────────────────────┐
                     │  EquipamentoSelecionado  │   n linhas, sem relação
                     └──────────────────────────┘

  ┌──────────┐  1   n  ┌──────────────┐  1   n  ┌──────────────┐
  │  Treino  ├─────────┤  SecaoTreino ├─────────┤  SerieTreino │
  └────┬─────┘ cascata └──────────────┘ cascata └──────────────┘
       │ 1
       │
       │ n           ┌────────────────┐
       └─────────────┤ SessaoNatacao  │   cascata
                     └────────────────┘

  ExercicioCatalogo / TipoEquipamento  ← JSON no bundle, referência lógica
       ▲                                  por `serie_treino.exercicio_id`
       └── sem FK: o catálogo não está no banco
```

Uma frase por relação, no vocabulário do produto:

- **Um treino tem exatamente quatro seções**, e cada seção pertence a um treino
  só. Apagar o treino apaga as seções.
- **Uma seção tem de zero a várias séries**, e cada série pertence a uma seção
  só. Seção vazia é estado válido em treino curto. Apagar a seção apaga as séries.
- **Um treino pode ter várias sessões** — favorito repetido toda terça —, e cada
  sessão aponta para no máximo um treino. Apagar o treino apaga as sessões dele
  do banco local; o `HKWorkout` no app Saúde **permanece**, porque é dado de
  saúde do usuário e não nosso.
- **Uma série aponta para um exercício do catálogo** por `exercicio_id`, sem
  chave estrangeira. Se um exercício sumir de uma versão futura do catálogo, a
  série continua legível pelos snapshots de nome e descrição.
- **`Preferencias` e `EquipamentoSelecionado` não se relacionam com nada.** São
  estado de configuração, lidos na geração e descartados depois.

**Ordem é por coluna, nunca pela relação.** `Treino.secoesOrdenadas` e
`SecaoTreino.seriesOrdenadas` ordenam por `ordem` explicitamente, porque o
SwiftData não garante a ordem de uma relação — e ler fora de ordem faria o
nadador executar o treino trocado.

---

## 3. Regras que vivem fora da tela

Não há SQL. As regras de negócio são **funções puras** em `VouNadar/Domain/`,
compiladas nos dois apps e testadas sem simulador, sem piscina e sem HealthKit.

### 3.1 Adaptação à raia — `LaneAdapter` (regra 11.3)

`VouNadar/Domain/Generation/LaneAdapter.swift`

Roda **na geração**, uma vez por exercício candidato, antes de qualquer sorteio.

- `voltasPorRepeticao(distanciaCatalogoM:tamanhoRaiaM:)` — o número inteiro de
  voltas mais próximo, no mínimo 1.
- `distanciaAdaptadaM(distanciaCatalogoM:tamanhoRaiaM:)` — voltas × tamanho da
  raia. É essa distância que aparece na tela, no relógio e no total.
- `desvio(...)` e `desvioAceitavel(...)` — o quanto a adaptação afastou do
  catálogo. O teto é `desvioMaximo = 0.25`.
- `podeSerSorteado(_:tamanhoRaiaM:)` — a guarda: exercício que estouraria 25%
  **sai do sorteio** nessa piscina.

Numa raia de 16 m o `4×100` vira `4×96` (seis voltas). Numa de 50 m os 21 blocos
de 25 m saem, restando 203 dos 226. As oito piscinas da tabela do spec são
varridas em `LaneAdapterTests`, e as contagens batem.

### 3.2 Descanso — `RestCalculator` (regras 11.5 e 11.6)

`VouNadar/Domain/Rest/RestCalculator.swift`

Roda **na geração**, uma vez por série, e o resultado é gravado. Nunca é
recalculado na leitura.

- `descansoSegundos(...)` — base por distância × multiplicador de intensidade ×
  multiplicador de modo × ritmo, arredondado ao múltiplo de 5 e limitado a
  **10–90 s**.
- `base(distanciaM:)` — a tabela de 8 linhas, escolhendo a **linha mais próxima**,
  empate para a maior.
- `multiplicador(intensidade:)` e `multiplicador(modo:)`.
- `arredondarParaMultiploDeCinco(_:)` — arredondamento **meio-para-longe-do-zero**,
  não bancário. O exemplo `37,5 → 40` do spec é o que fixa isso.
- `descansoEntreSeries(ritmo:)` (base 30 s) e `descansoEntreSecoes(ritmo:)`
  (base 45 s).

Varrido sobre os 226 exercícios × 8 piscinas × 3 ritmos: nenhum valor fora de
10–90 s.

### 3.3 Catálogo adaptado — `AdaptedCatalog`

`VouNadar/Domain/Generation/AdaptedCatalog.swift`

Roda **uma vez por geração**, antes do gerador. Aplica a regra 11.3 a todo o
catálogo, descarta o que estoura a guarda e monta os sete conjuntos de candidatos
(aquecimento, educativos, soltura, progressão, principal, pernada, complemento).

É a peça que permitiu reaproveitar o gerador do Swim Builder quase intacto: ele
passou a sortear sobre distâncias **já adaptadas**, sem saber que a adaptação
existe.

### 3.4 Geração — `WorkoutGenerator` (épico 8.5, regras 11.1, 11.2, 11.4, 11.19)

`VouNadar/Domain/Generation/WorkoutGenerator.swift`

Roda quando o nadador toca **Gerar**, no iPhone (P1) ou no relógio (W2).

`gerar(...)` sorteia o alvo dentro da faixa, divide entre as quatro seções,
preenche cada uma com candidatos e **nunca lança**: até `maxTentativas = 50`
rascunhos, guardando o melhor, com `maxRejeicoesPorIdentidade = 3` para não
repetir o treino anterior. Um treino aquém do pedido é entregue com aviso; nunca
uma tela de erro na frente de quem só quer nadar.

O descanso é carimbado num **passo final** em `resultado(de:pedido:)`, com três
decisões derivadas: série de uma repetição não tem descanso interno; última série
da seção não tem descanso pós-série; última seção não tem descanso pós-seção.

`RepertoireGuard` avisa quando a combinação de filtros deixa menos de 30
candidatos — piscina incomum com equipamento nenhum, por exemplo.

`SeededRandomNumberGenerator` existe para o teste de propriedade poder repetir
uma geração exata.

### 3.5 Execução — `ExecutionEngine` e `LapCounter` (épico 8.8, regras 11.7 a 11.9)

`VouNadar/Domain/Execution/`

Rodam **durante o treino**, no relógio, com a tela travada pelo Water Lock.

`ExecutionEngine` é uma máquina de estados pura — `preparando`, `nadando`,
`descansando`, `pausado`, `concluido` — que recebe eventos (`voltaCompletada`,
`segundo`, `pausar`, `retomar`, `pularSerie`) e devolve o próximo estado mais os
hápticos (entrada em descanso, contagem final, saída do descanso, conclusão).
**Nenhuma ação obrigatória depende de toque** — princípio 0.1.

`LapCounter` conta voltas a partir da **distância acumulada** que o HealthKit
reporta, e não de eventos de virada, e nunca decrementa quando a leitura regride.

### 3.6 Volume semanal — `Semana` e `VolumeSemanal` (regra 11.16)

`VouNadar/Domain/Semana.swift`, `VouNadar/Domain/History/VolumeSemanal.swift`

Rodam ao abrir o Histórico (P4), a tela inicial do relógio (W1) e a complication.

A semana começa na **segunda-feira**, no fuso do aparelho.
`VolumeSemanal.porSemana(...)` agrupa as sessões nas últimas 6 semanas e
`mediaSemanal(...)` divide **incluindo as semanas vazias** — semana sem nadar é
informação, não ausência de dado.

### 3.7 Compra — `PurchaseGate` e `PurchaseService` (regra 11.17)

`VouNadar/Domain/Purchase/PurchaseGate.swift`,
`VouNadar/Data/Purchase/PurchaseService.swift`

`PurchaseGate.podeExecutar(comprado:execucoesFeitas:)` roda antes de cada
execução guiada. **Gerar é sempre livre**; a compra destrava a execução, a partir
da quarta (`execucoesLivres = 3`).

`OrigemDoDireito` é onde mora o "na dúvida, libera": `.verificado` quando o
StoreKit respondeu, `.ultimoEstadoConhecido` quando só o iPhone informou, e
`.indeterminado` — que **libera**. Negar a quem pagou, molhado na borda da
piscina, é pior que liberar a quem não pagou.

`PurchaseService` é a única coisa no app que fala com a rede, e apenas com a App
Store: `Product.products(for:)`, `Transaction.currentEntitlements`,
`Transaction.updates` e `AppStore.sync()` para restaurar.

### 3.8 Sincronização iPhone → relógio (contrato 13.3)

`VouNadar/Domain/Sync/`, `VouNadar/Connectivity/PhoneSyncService.swift`,
`VouNadarWatch/Connectivity/WatchSyncService.swift`

O fluxo é de mão única. O relógio nunca escreve no iPhone — há um teste,
`WatchNeverSendsTests`, que garante isso.

- `SyncPayload` codifica o **estado leve** (piscina, ritmo, faixa, interruptores,
  equipamentos, carimbo, compra) nas 10 chaves do contrato, e mede o tamanho
  contra o limite de 262.144 bytes do `updateApplicationContext`.
- `WorkoutTransfer` codifica um favorito inteiro. A descrição de cada exercício é
  **deliberadamente omitida** — ela é o campo mais pesado e o relógio não a mostra.
- `FavoritesSync.lotes(de:)` divide os favoritos em lotes por tamanho **medido**,
  com limiar de 50.000 e teto de 65.536 bytes (`transferUserInfo`).
- `FavoritesBatchAssembler` remonta os lotes no relógio, tolerando chegada fora
  de ordem e transferências entrelaçadas.
- `SyncCoordinator` observa `ModelContext.didSave` e dispara a sincronização
  quando algo relevante muda.
- `PhoneSyncService` só envia com as **três** condições satisfeitas: sessão
  ativada, `isPaired` e `isWatchAppInstalled`.

**Resolução de conflito (regra 11.12):** `WatchStore.aplicar(_:)` compara o
`atualizado_em` que chegou com o local e só sobrescreve se o de fora for mais
recente.

### 3.9 Gravação no HealthKit — `WorkoutSessionController` (épico 8.9, regras 11.10 e 11.11)

`VouNadarWatch/Health/WorkoutSessionController.swift`

Roda no relógio, do início ao fim da sessão. `iniciar()` monta a
`HKWorkoutConfiguration` como natação em piscina com o `lapLength` correto, abre
`HKWorkoutSession` e `HKLiveWorkoutBuilder`, e alimenta o `ExecutionEngine` com a
distância que chega ao vivo.

`encerrar()` decide o motivo por `MotivoEncerramento.decidir(...)` e só grava o
`HKWorkout` quando `deveGravarNoHealthKit` — abaixo de 25 m nada vai para o app
Saúde. Falha na gravação vira `motivoEncerramento = .falhou` com aviso na tela;
**nunca falha silenciosa**.

### 3.10 Leitura do histórico — `HealthHistoryReader` e `WeeklyVolumeReader`

`VouNadar/Data/Health/HealthHistoryReader.swift` (iPhone, só lê),
`VouNadarWatch/Health/WeeklyVolumeReader.swift` (relógio e complication).

O iPhone monta o Histórico com **todas** as sessões de natação do app Saúde,
marcando as que não vieram do Vou Nadar como "fora do app", e conta as execuções
do app para o portão da compra. `WeeklyVolumeReader` devolve **um número** e
distingue `nil` ("não sei") de `0` ("respondeu, e você não nadou") — é o que
permite a complication mostrar um traço em vez de mentir.

### 3.11 Repositórios

`PreferencesRepository` e `WorkoutRepository` são compartilhados pelos dois apps.
O ponto mais delicado é `registrarSessao(_:)`: ele grava a sessão e atualiza
`vezesExecutado` e `ultimaExecucaoEm` **na mesma transação** (regra 11.13), para
o contador nunca divergir do histórico. `removerSessao(_:)` desfaz nos mesmos
termos.

---

## 4. Mapa tela → dados

### iPhone

| Tela | Lê | Escreve | Rotinas que atravessa |
|---|---|---|---|
| **P1 Home** (`HomeView`) | `Preferencias`, `EquipamentoSelecionado`, catálogo | `Preferencias`, `EquipamentoSelecionado`, `Treino` (+ seções e séries) | `PreferencesRepository`, `AdaptedCatalog`, `RepertoireGuard`, `WorkoutGenerator`, `LaneAdapter`, `RestCalculator`, `WorkoutRepository.salvar` |
| **P2 Detalhe** (`WorkoutDetailView`) | `Treino` | `Treino` (favorito, título) | `WorkoutPresentation`, `ExerciseName`, `WorkoutTextExporter`, `WorkoutRepository.favoritar` |
| **P3 Favoritos** (`FavoritesView`) | `Treino` (favoritos) | `Treino` (renomear, arquivar) | `WorkoutRepository.favoritos` / `.renomear` / `.arquivar` |
| **P4 Histórico** (`HistoryView`) | HealthKit, `SessaoNatacao` | — | `HealthHistoryReader.sessoes`, `Semana`, `VolumeSemanal` |
| **P5 Ajustes** (`SettingsView`) | `Preferencias`, StoreKit, catálogo | `Preferencias`, e o store inteiro em "Apagar todos os dados" | `PreferencesRepository`, `PurchaseService.restaurar` |
| **P6 Piscina** (`PoolSizeView`) | `Preferencias` | `Preferencias` (`tamanhoRaiaM`, `raiaConfirmada`) | `PreferencesRepository.confirmarPiscina` |
| **P7 Paywall** (`PaywallView`) | StoreKit | — (o direito vem do StoreKit) | `PurchaseService.carregar` / `.comprar` / `.restaurar`, `PurchaseGate` |

`RootView` monta as três abas e é quem impõe a piscina obrigatória na primeira
abertura. `SyncCoordinator` roda por trás de P1, P3, P5 e P6: qualquer gravação
relevante dispara o envio ao relógio.

### Apple Watch

| Tela | Lê | Escreve | Rotinas que atravessa |
|---|---|---|---|
| **W1 Início** (`WatchHomeView`) | HealthKit | — | `WeeklyVolumeReader.metrosDaSemana`, `Semana` |
| **W2 Gerar** (`WatchGenerateView`) | `Preferencias` (sincronizadas) | `Preferencias`, `Treino` | `WorkoutGenerator`, `AdaptedCatalog`, `RestCalculator`, `WorkoutRepository.salvar` |
| **W3 Favoritos** (`WatchFavoritesView`) | `Treino` (recebidos do iPhone) | — | `WatchStore.treinosExecutaveis` |
| **W4 Pré-visualização** (`WatchPreviewView`) | `Treino`, `Preferencias` | — | `ExecutionPlan`, `PurchaseGate`, `WatchStore.apurarDireito` |
| **W5 Piscina** (`WatchPoolSizeView`) | `Preferencias` | `Preferencias` | `PreferencesRepository.confirmarPiscina` |
| **W6 Contagem** | — | — | `WorkoutSessionController.iniciar` |
| **W7 Nadando** | `Treino` (via plano) | — | `ExecutionEngine`, `LapCounter`, `HKLiveWorkoutBuilder` |
| **W8 Descansando** | idem | — | `ExecutionEngine` (contagem regressiva e hápticos) |
| **W9 Desbloqueada** | idem | `SessaoNatacao` | `ExecutionEngine` (pausar, pular), `WorkoutSessionController.encerrar` |
| **W10 Resumo** | `SessaoNatacao` | `SessaoNatacao`, HealthKit | `MotivoEncerramento.decidir`, `WorkoutRepository.registrarSessao` |
| **W11 Erro de autorização** | — | — | — |

W6 a W11 vivem todas em `WatchSessionView`, porque são fases de uma mesma sessão:
separá-las em telas navegáveis criaria pontos onde a navegação pode se perder com
a tela travada e o pulso na água.

---

## 5. Lógica por tela

### P1 — Home

**Valida** que a piscina foi confirmada: sem `raiaConfirmada`, o botão Gerar fica
desabilitado com a explicação em rodapé, e não uma tela de erro depois do toque.

**Grava** a faixa (mínimo e máximo), os dois interruptores e os equipamentos —
cada um imediatamente, sem botão Salvar. Faixa invertida é impossível pelo
controle; se chegar assim de outro caminho, o repositório recusa com
`erroFaixaInvertida`.

**Calcula** na hora do Gerar: `AdaptedCatalog` sobre a raia atual,
`RepertoireGuard` para saber se avisa, `WorkoutGenerator.gerar(...)` e
`WorkoutRepository.salvar(...)`, e navega para P2.

**Erro:** repertório curto vira aviso não-bloqueante ("Sua combinação de filtros
deixou poucos exercícios…"), não um impedimento. Falha de gravação mostra a
mensagem do repositório.

### P2 — Detalhe do treino

**Mostra** o numeral herói com o total, as quatro seções na ordem e cada série
como `4×100 Crawl Ritmo Constante · 30 s`, com selo de modo e de equipamento.
Série ajustada à raia é marcada.

**Valida** o título ao favoritar: de 1 a 60 caracteres, com a contagem visível.
Fora disso o botão Salvar fica desabilitado.

**Grava** `favorito = true` e o título. **Copiar como texto** monta o treino em
texto plano por `WorkoutTextExporter` (formato da seção 14) e confirma com
"Treino copiado."

**Nada é recalculado aqui.** Descanso, distância e voltas vêm gravados.

### P3 — Favoritos

**Mostra** título, distância e vezes executado. Vazio traz a copy 15.4, que
explica como salvar o primeiro.

**Grava** renomeação (mesma validação de 1 a 60) e arquivamento. **Apagar é
arquivar**: `arquivadoEm` recebe a data, o treino some da lista, e as sessões
continuam no Histórico com o título preservado.

### P4 — Histórico

**Lê** do HealthKit, não do banco: é lá que está a verdade sobre o que foi
nadado, inclusive o que foi nadado sem o app.

**Mostra** o volume das últimas 6 semanas, "Esta semana", a média semanal e a
lista de sessões. Sessão que não veio do Vou Nadar é marcada "fora do app".

**Erro:** sem autorização do HealthKit, a tela explica o que falta e oferece
"Abrir Ajustes" — não uma lista vazia sem explicação.

### P5 — Ajustes

**Mostra e grava** piscina (leva a P6), ritmo de descanso com a explicação do que
cada opção faz, equipamentos, restaurar compra, versão do app e do catálogo,
privacidade e suporte.

**"Apagar todos os dados"** pede confirmação **duas vezes**, com textos
diferentes, e diz explicitamente que o app Saúde não é afetado — os `HKWorkout`
são dado de saúde do usuário e permanecem.

### P6 — Piscina

**Valida** o valor entre 10 e 50 m; fora disso, `erroRaiaForaDaFaixa`.

**Grava** `tamanhoRaiaM` e `raiaConfirmada = true` numa transação, e dispara a
sincronização com o relógio.

**Não regenera nada.** Treinos já salvos continuam com a raia deles — é o
princípio 0.6, e é o que impede um favorito de mudar sozinho.

### P7 — Paywall

**Mostra** a proposta, o preço vindo do StoreKit (nunca escrito no código),
Comprar e Restaurar compra.

**Cancelar não é erro** e não gera mensagem. Restauração sem compra encontrada
avisa; com compra encontrada confirma e fecha.

### W1 — Início

Mostra o volume da semana e dois botões, Gerar e Favoritos. Sem autorização do
HealthKit, mostra o pedido; sem dado, um traço.

### W2 — Gerar

Faixa pela coroa digital e os interruptores. Gera **no próprio relógio**, com o
catálogo embarcado — com o iPhone desligado, na mochila do vestiário.

### W3 — Favoritos

Lista o que chegou do iPhone. Vazio traz a copy 15.4. O relógio **nunca apaga nem
edita** treino com `origem = gerado_iphone`.

### W4 — Pré-visualização

Mostra título, distância e `Raia de {n} m`. É aqui que o portão da compra é
consultado, **antes** de o nadador entrar na água: `WatchStore.apurarDireito()`
tenta o StoreKit, cai para o último estado vindo do iPhone e, em último caso,
libera. "Trocar piscina" leva a W5.

### W5 — Piscina

Atalhos de 25 e 50 m, mais "Outro" pela coroa, de 10 a 50. Grava e volta.

### W6 — Contagem

`3 · 2 · 1` em tela cheia enquanto a sessão do HealthKit sobe e o Water Lock
liga. Nenhum toque é necessário daqui em diante.

### W7 — Nadando

`3 de 4`, a série atual e o acumulado, em números grandes o suficiente para
serem lidos de relance com água no visor. A tela **muda sozinha** quando as
voltas previstas são atingidas.

### W8 — Descansando

Contagem regressiva gigante e a próxima repetição já anunciada. Háptico ao entrar,
nos últimos 3 segundos e ao sair. A transição dos 3 segundos finais continua
legível **sem depender de cor**.

### W9 — Desbloqueada

Igual a W7/W8 mais os botões Pausar, Pular e Encerrar. Existe para quando o
nadador **escolhe** interagir — nunca porque o treino exige.

### W10 — Resumo

Real contra planejado, tempo e séries. É aqui que `SessaoNatacao` é gravada e o
`HKWorkout` é fechado. `1.200 m de 2.100 m` é apresentado como fato, **sem
linguagem de falha**.

**Erro:** se o `HKWorkout` não gravar, o motivo vira `falhou`, a sessão fica
salva no relógio sem `healthkitWorkoutUuid` e o nadador é avisado na tela.

### W11 — Erro de autorização

Explica o que falta e como conceder. É a única tela do relógio cuja copy não vem
da seção 15 do spec — ver a divergência 6.5.

---

## 6. Divergências em relação ao spec

Sem esta seção o documento envelhece mentindo. Cada item diz o que ficou
diferente, por quê, e onde está no código.

### 6.1 O banco está em português, mas não em `snake_case`

**Spec 7.0:** o banco fica em português `snake_case`, "preservado por
`@Attribute(originalName:)`".

**O que acontece:** `originalName` declara o nome **anterior** de uma propriedade,
para o SwiftData mapear numa migração. Num store novo ele não define o nome
persistido. Verificado no banco gravado: as colunas saem `ZDISTANCIATOTALM`,
`ZDESCANSOPOSSERIESEG`, `ZVOLTASPORREPETICAO`.

**O que continua valendo:** o banco **está** em português, porque as propriedades
foram nomeadas em português. O que não se sustenta é o `snake_case`.

**Decisão (06/09/2026, do Alexandre): aceitar.** As anotações ficam onde estão —
documentam a intenção e passam a ter efeito real na primeira renomeação de
propriedade, que é exatamente para o que servem.

Documentada no código em `Data/Schema/VouNadarSchema.swift`.

### 6.2 O prefixo `NxM` é removido do nome do exercício

**Spec 14.2.5:** montar a linha como `{repeticoes}×{distancia_m} {nome_snapshot}`,
com o exemplo mostrando nomes como `crawl leve`.

**O conflito:** **os 226 nomes do catálogo copiado do Swim Builder começam com
`NxM`** — `1x300 Aquecimento Leve`. Ao pé da letra, a regra produziria
`1×300 1x300 Aquecimento Leve`. Numa piscina de 16 m produziria
`1×304 1x300 Aquecimento Leve`, onde o segundo número **contradiz** o primeiro.

**O que foi feito:** `ExerciseName.semPrefixoDeSerie(_:)` remove o prefixo,
restaurando exatamente a forma do exemplo do spec. É o **único** lugar onde isso
acontece, e serve tanto à tela P2 quanto ao texto copiado.

### 6.3 A tabela de descanso usa a linha mais próxima

**Spec 11.5:** dá a tabela de base por distância sem dizer o que fazer com uma
distância que não bate com nenhuma linha — situação que a adaptação à raia
(regra 11.3) cria o tempo todo.

**O que foi feito:** **linha mais próxima, empate para a maior.** Não foi escolha
de gosto: varrendo os 226 exercícios × 8 piscinas × 3 ritmos, esse critério
produz **exatamente o mesmo descanso** que a distância do catálogo produziria —
zero divergências. O critério alternativo ("última linha ≤ distância") divergiria
em até 106 dos 205 exercícios numa das piscinas.

### 6.4 O botão primário usa `.glass`, não `.glassProminent`

**DESIGN-SYSTEM:** botão primário em `.glassProminent` com a cor de marca.

**O problema medido:** `.glassProminent` renderiza rótulo branco sobre
`#0E9BC4`, dando **3,27:1** — abaixo do mínimo de acessibilidade, e a tela de
execução é lida com água no visor.

**Decisão do Alexandre:** trocar por `.glass` (com fallback `.bordered` abaixo do
iOS 26) e rótulo tingido com a cor de marca. Medido: **5,12:1** no escuro,
**5,14:1** no claro.

Em `DesignSystem/PrimaryButtonBar.swift`.

### 6.5 A copy da W11 não vem da seção 15

A seção 15 não traz texto para a tela de erro de autorização do HealthKit no
relógio. O texto foi escrito seguindo o tom das demais (direto, sem culpar o
usuário, com o caminho concreto para resolver) e está isolado em
`WatchCopy`, para revisão futura num lugar só.

### 6.6 `Data/Schema/` e `Data/Repositories/` também são fontes compartilhadas

**Spec 4.2** lista `Domain/`, `Data/Catalog/`, `Data/Enums/` e `Data/Models/`
como as pastas compiladas nos dois targets.

**O que foi feito:** `Data/Schema/` e `Data/Repositories/` entraram na lista.
Sem elas, o relógio teria o modelo mas não o `ModelContainer` nem o acesso — e
teria de reimplementar `salvar`, `registrarSessao` e a regra 11.13, que é
exatamente a duplicação que a regra de fontes compartilhadas existe para evitar.

Ambas importam apenas `SwiftData`. A regra de pureza continua valendo e é
verificada por `SharedSourcePurityTests`.

### 6.7 `HealthHistoryReader` saiu de `Data/Repositories/`

Consequência direta de 6.6: ele importa HealthKit, e o teste de pureza o rejeitou
— corretamente. Foi movido para `VouNadar/Data/Health/`, fora das fontes
compartilhadas. O relógio tem o seu próprio leitor, `WeeklyVolumeReader`.

### 6.8 Sessão descartada por ser curta não é persistida

**Regra 11.11** diz que abaixo de 25 m nada é gravado no HealthKit. O enum
`MotivoEncerramento` tem o caso `descartado_curto`, o que sugeriria uma linha de
`sessao_natacao` com esse motivo.

**O que foi feito:** a sessão descartada **não vai para o banco** também. Um
toque acidental de 10 metros não pode aparecer no Histórico nem consumir uma das
três execuções livres. O caso do enum permanece porque é ele que carrega a
decisão de `MotivoEncerramento.decidir(...)` e de `deveGravarNoHealthKit`.

### 6.9 `treino.origem` tem valor padrão

O SwiftData exige valor padrão em propriedade de enum para migração leve.
`origem` nasce `gerado_iphone` e é sobrescrito explicitamente pelo gerador do
relógio. Mesma coisa em `tipoSecao`, `ritmoDescansoUsado`, `modo` e
`intensidade` — os padrões são exigência do framework, não semântica de produto.

### 6.10 A descrição do exercício não viaja para o relógio

`WorkoutTransfer` omite `descricaoSnapshot` de propósito: é o campo mais pesado
do payload e o relógio não o exibe em nenhuma das onze telas. A omissão é o que
mantém os lotes dentro dos 65.536 bytes do `transferUserInfo` sem cortar
favoritos.

### 6.11 Exceção de warning no target de testes

**Critério 8.1.4** exige build sem nenhum warning. Ela vale integralmente para os
três targets de app.

Em `VouNadarTests`, `GCC_TREAT_WARNINGS_AS_ERRORS` está desligado, porque o
header do `StoreKitTest` **da Apple** usa `SKPaymentTransactionState`, deprecado
no iOS 18. A exceção é estreita, está declarada no `project.yml` e não tolera
nenhum warning nosso.

### 6.13 O iPhone declara string de escrita no HealthKit sem nunca escrever

**Spec 4.1:** o iPhone **só lê** do HealthKit; quem escreve é o relógio. Isso
continua verdade no código.

**O que o validador da App Store exige:** as **duas** strings de propósito —
`NSHealthShareUsageDescription` e `NSHealthUpdateUsageDescription` — em todo
bundle que carregue o entitlement `com.apple.developer.healthkit`,
independentemente do que o código faz. O upload da 1.0.0 foi recusado com
*"Missing purpose string in Info.plist"* apontando para `VouNadar.app`.

**O que foi feito:** as duas strings entraram no `Info.plist` do iPhone e no da
complication, com a copy 15.10 literal. Comentário ao lado de cada uma explica
por que estão ali.

**Por que isso não mente para o usuário:** a folha de autorização do sistema só
mostra a string do que é efetivamente pedido. O iPhone chama
`requestAuthorization(toShare: [], read: ...)` e a complication não pede nada —
então o texto de escrita nunca aparece em nenhuma das duas telas.

### 6.14 A descrição do exercício cita a metragem do catálogo, e não é ajustada

**O que acontece:** `descricaoSnapshot` vem do catálogo e cita a distância
original. Em raia fora do padrão ela contradiz o número ao lado — a série sai
como `3×144 m` e a descrição diz *"Três repetições de 150m de braçada com pull
buoy"*. **192 das 226 descrições citam metragem** (84%), então numa piscina de
18 m isso acontece o tempo todo.

É a mesma classe do conflito que a divergência 6.2 resolveu para os **nomes**.
Lá foi corrigido porque a contradição ficava dentro da **mesma linha**
(`1×304 1x300 Aquecimento Leve`, dois números discordando lado a lado). Aqui ela
está entre a linha e o texto de apoio, que é mais tolerável.

**Decisão do Alexandre em 06/09/2026, testando numa piscina real de 18 m:
aceitar, sem mexer.** Quem nada em piscina fora do padrão entende bem. A
descrição explica a **intenção** do exercício, não a prescrição; o cabeçalho da
tela já diz que as distâncias foram ajustadas para fechar voltas inteiras; e o
número que vale é o da direita.

### 6.15 Não existe "marcar como executado" no iPhone

**O que acontece:** só o `WorkoutSessionController`, que é do relógio, cria
`SessaoNatacao`. O iPhone lê o Histórico e nunca escreve sessão. Nenhuma tela de
P1 a P7 tem a ação, e o spec não a prevê.

**Consequência, deliberada:** sem relógio, `vezes_executado` fica em zero, o
Histórico e o volume da semana ficam vazios, e **o paywall nunca aparece** — a
contagem de execuções sai do HealthKit, e sem relógio não há execução para
contar. O iPhone sozinho gera, copia como texto e favorita; o resto é folheto.

**Decisão do Alexandre em 06/09/2026: manter assim.** Executar só pelo relógio é
o que garante **acurácia no app Saúde** — distância e duração vêm de medição, não
de alguém digitando o que acha que nadou. Um botão "marquei como feito" no
iPhone poria dado estimado no mesmo lugar onde hoje só entra dado medido, e é
esse lugar que alimenta o Histórico, o volume da semana e a complication.

Também é coerente com a compra: o que se vende é a execução guiada.

### 6.12 O que não foi implementado, por decisão

Do anti-escopo e do roadmap (spec 28), nada foi implementado — nem "só a
estrutura", nem campo "para depois": intervalo de saída, pace base, edição de
descanso bloco a bloco, edição de treino, outros nados, águas abertas, CloudKit,
sincronização Watch→iPhone, widget de Smart Stack, compartilhamento em imagem,
tela de conta ou login, gráfico de pace, jardas, iPad e inglês.
