# Vou Nadar — Design System

Documento de implementação. Alvo: SwiftUI, iOS 18+ e watchOS 11+.
Só português do Brasil, só retrato no iPhone, 100% offline, sem conta.

Quem lê este documento não vê as telas. Todo valor aqui é literal e deve ser
usado como está.

---

## 1. Tokens de cor

### iPhone — Color Sets no asset catalog (dois temas cada)

| Token | Color Set | Claro | Escuro |
|---|---|---|---|
| fundo | `BackgroundPrimary` | `#F4F8FA` | `#061620` |
| superfície agrupada | `SurfaceGrouped` | `#FFFFFF` | `#0C2531` |
| superfície elevada | `SurfaceElevated` | `#E9F1F5` | `#12313F` |
| destaque | `AccentTint` | `#0A7593` | `#0E9BC4` |
| texto primário | `TextPrimary` | `#0B1B23` | `#EAF4F8` |
| texto secundário | `TextSecondary` | `#5A7285` | `#8FA9B6` |
| hairline | `Hairline` | `#DBE6EC` | `#1C3A48` |
| sucesso | `StatusSuccess` | `#1F8A55` | `#30D158` |
| alerta | `StatusWarning` | `#9A6B10` | `#FF9F0A` |
| erro | `StatusError` | `#B3352C` | `#FF453A` |
| seção aquecimento | `SectionWarmup` | `#5AA9E6` | `#5AA9E6` |
| seção progressão | `SectionProgression` | `#0E9BC4` | `#0E9BC4` |
| seção parte principal | `SectionMain` | `#E8813C` | `#E8813C` |
| seção soltura | `SectionCooldown` | `#8FA9B6` | `#8FA9B6` |

`AccentTint` é `#0A7593` no tema claro e **não** `#0E9BC4`: o azul de marca
sobre branco dá 3,23:1 e reprova o critério de acessibilidade do app. Não troque.

Onde cada token pode e não pode ser usado:

- **BackgroundPrimary** — fundo de tela. Nunca em linha de lista nem em texto.
- **SurfaceGrouped** — fundo das linhas do `List`. Quem pinta é o `List`; não
  aplique manualmente, exceto no contêiner do gráfico.
- **SurfaceElevated** — fundo do controle embutido do `Stepper` e da faixa de
  confirmação "Treino copiado.". Nunca como fundo de tela nem de linha comum.
- **AccentTint** — `.tint` do app: glyph da aba ativa, marcador de seleção,
  rótulo de botão, `Toggle` ligado, traço do gráfico, trilha preenchida do
  slider. **Nunca** como fundo de pílula, de card, de faixa larga ou de bloco.
- **TextPrimary** — todo texto de conteúdo. Nunca sobre `AccentTint`.
- **TextSecondary** — metragem, descanso, descrição, rótulo de número, selo de
  modo, footer de Section, texto de estado vazio. Nunca em título de tela.
- **Hairline** — separador do `List`, borda do botão da barra inferior, barra
  vazia do gráfico. Nunca em texto.
- **StatusSuccess** — apenas o símbolo de confirmação de cópia.
- **StatusWarning** — apenas o símbolo e a moldura do aviso de repertório curto.
- **StatusError** — apenas "Apagar todos os dados", a ação de swipe Apagar e o
  alerta de confirmação. Nunca decorativo.
- **Section\*** — apenas um traço de 14 × 3 pt junto ao header da Section, ou
  nada. Nunca fundo, nunca faixa larga, nunca cor de texto.

### Apple Watch — sem tema, valores fixos

| Token | Constante | Hex |
|---|---|---|
| fundo | `watchBackground` | `#000000` |
| estado nadando | `watchSwimming` | `#0E9BC4` |
| estado descansando | `watchResting` | `#FF9F0A` |
| últimos 3 segundos | `watchFinalCountdown` | `#30D158` |
| encerrar | `watchDestructive` | `#FF453A` |
| texto primário | `watchTextPrimary` | `#FFFFFF` |
| texto secundário | `watchTextSecondary` | `#98989F` |
| superfície de botão | `watchButtonFill` | `#1C1C1E` |
| Always-On nadando | `watchDimSwimming` | `#7C8894` |
| Always-On descansando | `watchDimResting` | `#A8925F` |

`#000000` é obrigatório em todas as telas do relógio: é OLED, pixel apagado não
gasta bateria. Nunca cinza escuro.

---

## 2. Tipografia

Nenhum tamanho fixo em pontos é permitido no iPhone. Só os onze estilos
semânticos, sempre via `Font.TextStyle`, sempre sujeitos a Dynamic Type.
SF Pro do sistema; SF Pro Rounded só no numeral herói.

| Elemento | Estilo | Peso | Design | Dígitos mono |
|---|---|---|---|---|
| Título de tela (grande e recolhido) | `.largeTitle` → `.headline` na barra | `.bold` / `.semibold` | `.default` | não |
| Distância total (herói) | `.largeTitle` | `.bold` | `.rounded` | **sim** |
| Unidade "m" do herói | `.title3` | `.bold` | `.rounded` | não |
| Rótulo "Total" | `.caption` | `.regular` | `.default` | não |
| "Feito 3 vezes" / nota de ajuste | `.footnote` | `.regular` | `.default` | não |
| Header de Section | `.footnote` | `.regular` | `.default` | não |
| Footer de Section | `.footnote` | `.regular` | `.default` | não |
| Nome do exercício | `.body` | `.regular` | `.default` | não |
| Descrição do exercício | `.footnote` | `.regular` | `.default` | não |
| Metragem da série | `.body` | `.regular` | `.default` | **sim** |
| Descanso da série | `.footnote` | `.regular` | `.default` | **sim** |
| Selo de modo | `.caption2` | `.regular` | `.default` | não |
| Rótulo de linha de lista | `.body` | `.regular` | `.default` | não |
| Valor à direita da linha | `.body` | `.regular` | `.default` | **sim** |
| Nota do Toggle | `.footnote` | `.regular` | `.default` | não |
| Número da semana (Histórico) | `.title2` | `.semibold` | `.default` | **sim** |
| Rótulo do número | `.caption` | `.regular` | `.default` | não |
| Eixo do gráfico | `.caption2` | `.regular` | `.default` | não |
| Rótulo de aba | fornecido pela `TabView` | — | — | não |
| Rótulo do botão primário | `.body` | `.semibold` | `.default` | não |
| Título do estado vazio | `.title3` | `.semibold` | `.default` | não |
| Corpo do estado vazio | `.body` | `.regular` | `.default` | não |
| Título do paywall | `.largeTitle` | `.bold` | `.default` | não |
| Corpo do paywall | `.body` | `.regular` | `.default` | não |

Header de Section sempre em **Title Case**: "Distância", "Equipamento na
mochila", "Parte principal". Nunca caixa alta, nunca `letter-spacing`.

Dígitos monoespaçados: `.monospacedDigit()`.

### Apple Watch

SF Compact Rounded, `.rounded`. Aqui tamanho explícito é permitido porque a
tela é fixa e a hierarquia é a do app Treino nativo.

| Elemento | Tamanho mínimo | Peso |
|---|---|---|
| Contagem de descanso (âmbar) | 76 pt | `.bold` |
| Contagem de descanso (últimos 3 s) | 90 pt | `.bold` |
| Repetição atual ("3 de 4") | 56 pt | `.bold` |
| Algarismo da contagem inicial | 130 pt | `.bold` |
| Distância do resumo | 40 pt | `.bold` |
| Série e rótulos | 15 pt | `.semibold` |

Nada abaixo de 15 pt no relógio. No Ultra 49 mm, some 12 a 30 % em cada valor.

---

## 3. Componentes

| Elemento | Componente SwiftUI |
|---|---|
| Navegação raiz | `TabView` com três `Tab`: Treino, Favoritos, Histórico |
| Pilha de cada aba | `NavigationStack` |
| Título de tela | `.navigationTitle` + `.navigationBarTitleDisplayMode(.large)` |
| Ajustes | `.toolbar { ToolbarItem(placement: .topBarTrailing) }` na Home |
| Home, Favoritos, Ajustes, Piscina | `List` com `.listStyle(.insetGrouped)` |
| Agrupamento | `Section { } header: { } footer: { }` |
| Separador | padrão do `List`; nunca `Divider()` manual |
| Faixa de distância | `Section` com uma linha de valor + slider de intervalo com dois `gesture`-driven thumbs sobre `Canvas`; a linha de valor é `LabeledContent` |
| Equipamento (multi-seleção) | linhas com `Button` + `Image(systemName: "checkmark")` visível quando marcado, `.foregroundStyle(.tint)` |
| Educativos / Pernada | `Toggle` padrão, com `.font(.footnote)` na descrição dentro de um `VStack` |
| Botão primário | `.safeAreaInset(edge: .bottom)` com `Button` em `.buttonStyle(.glassProminent)` e `.controlSize(.large)` |
| Botão primário desabilitado | mesmo botão com `.disabled(true)`; texto de motivo acima, `.footnote`, `TextSecondary` |
| Aviso de repertório curto | primeira linha do `List`, `Label` com `exclamationmark.triangle.fill` em `StatusWarning` |
| Numeral herói (Detalhe) | **contêiner desenhado à mão**: `VStack(alignment: .leading, spacing: 2)` fora do `List`, padding horizontal 20, padding inferior 10, sem fundo e sem borda |
| Seções do treino | `List` com quatro `Section`; header é `HStack` com `RoundedRectangle` de **14 × 3 pt**, `cornerRadius` 2, na cor da seção |
| Linha de série | `HStack` com `VStack` à esquerda (selo, nome, descrição) e `VStack(alignment: .trailing)` à direita (metragem, descanso) |
| Seção sem série | uma linha comum com texto em `TextSecondary`. Nunca esconder a Section |
| Favoritar / Comprar | botão da barra inferior, `.glassProminent` |
| Gerar outro / Copiar como texto | `.toolbar` com `ToolbarItem(placement: .topBarTrailing)`; "Copiar como texto" em `Menu` |
| Confirmação "Treino copiado." | `.safeAreaInset` acima do botão, fundo `SurfaceElevated`, `cornerRadius` 12, símbolo em `StatusSuccess` |
| Swipe em Favoritos e Histórico | `.swipeActions` com Renomear e Apagar (`role: .destructive`) |
| Gráfico de volume | **contêiner desenhado à mão**: `HStack(spacing: 6)` de altura **112 pt**, barras com `RoundedRectangle(cornerRadius: 2)`, largura por `frame(maxWidth: .infinity)`, sem moldura e sem fundo; semana sem treino é barra de **6 %** da altura com `stroke` de `Hairline` |
| Números do Histórico | `HStack(spacing: 26)` de `VStack`s, sem caixa, `.lineLimit(1)` + `.minimumScaleFactor(0.7)` |
| Selo "fora do app" | `Label` com `arrow.up.forward`, `.caption2`, `TextSecondary` |
| Descanso (Ajustes) | três linhas com marcador de seleção, `Section` com footer explicativo |
| Piscina 25 m / 50 m | duas linhas de seleção no mesmo `Section` |
| Piscina "Outro" | `Stepper(value: $metros, in: 10...50)` |
| Paywall | `.sheet` com `.presentationDetents([.large])`; "Restaurar compra" como `Button(role: nil)` em `.buttonStyle(.plain)` abaixo do botão de compra |
| Alerta de apagar dados | `.alert` em duas etapas, ação `.destructive` |
| Estados vazios | `ContentUnavailableView` |
| Relógio — listas | `List` padrão do watchOS |
| Relógio — execução | `VStack` sobre `Color.black.ignoresSafeArea()` |
| Relógio — coroa | `.digitalCrownRotation` |
| Relógio — escape | `.handGestureShortcut` não se aplica; a tela W9 é alcançada pela coroa segurada, com três `Button` empilhados |

Contêiner desenhado à mão existe em **exatamente dois lugares**: o numeral herói
do Detalhe e o gráfico do Histórico. Em todo o resto, componente do sistema.

---

## 4. SF Symbols

Nomes exatos. Nenhum ícone desenhado à mão, nenhum SVG.

| Símbolo | Onde |
|---|---|
| `figure.pool.swim` | aba Treino |
| `star` / `star.fill` | aba Favoritos; ação Favoritar |
| `chart.bar` | aba Histórico |
| `gearshape` | Ajustes, na barra da Home |
| `checkmark` | marcador de seleção em equipamento, descanso e piscina |
| `chevron.right` | linha de navegação (o `List` desenha sozinho no `NavigationLink`) |
| `chevron.left` | botão voltar (o sistema desenha) |
| `exclamationmark.triangle.fill` | aviso de repertório curto |
| `checkmark.circle.fill` | confirmação "Treino copiado." |
| `doc.on.doc` | Copiar como texto |
| `ellipsis.circle` | menu Gerar outro |
| `arrow.up.forward` | selo "fora do app" |
| `trash` | swipe Apagar |
| `pencil` | swipe Renomear |
| `xmark` | fechar o paywall |
| `figure.pool.swim` | estado vazio do Histórico, em `ContentUnavailableView` |
| `hand.raised.slash` | tela de erro de autorização no relógio |
| `minus` / `plus` | o `Stepper` desenha sozinho; não substitua |

---

## 5. Espaçamento e layout

Padrão do sistema em tudo: padding do `List`, inset das linhas, espaçamento
entre Sections, área segura. Não declare padding em linha de lista.

Exceções, com valor:

| Onde | Valor |
|---|---|
| Padding horizontal do numeral herói | 20 pt |
| Padding inferior do numeral herói | 10 pt |
| Espaçamento interno do herói | 2 pt (6 pt quando há nota de ajuste) |
| Traço de cor da Section | 14 × 3 pt, `cornerRadius` 2, `spacing` 7 até o texto |
| Altura do gráfico | 112 pt |
| Espaçamento entre barras | 6 pt |
| `cornerRadius` das barras | 2 pt |
| Espaçamento entre os números da semana | 26 pt |
| Padding vertical da barra inferior | 10 pt topo, 12 pt base |

Um único raio de canto em contêiner desenhado à mão: **12 pt**. O botão da barra
inferior é cápsula (`Capsule()`). Nenhum outro raio.

---

## 6. Estados por tela

**P1 Home** — normal · bloqueada (piscina não confirmada: botão `.disabled`,
texto "Configure o tamanho da piscina para gerar treinos." acima) · aviso de
repertório curto (linha de alerta no topo, botão continua ativo) · faixa fechada
(os dois puxadores no mesmo ponto, valor "2.000 m") · Reduce Transparency
(material da barra e do botão trocados por `SurfaceElevated` opaco).

**P2 Detalhe** — normal · piscina de tamanho incomum (séries em "4×96", nota em
`.footnote` sob o herói) · rolado (título grande recolhido para `.headline` na
barra) · seção sem série · confirmação "Treino copiado.".

**P3 Favoritos** — normal · vazio ("Nenhum treino salvo ainda" / "Gere um treino
e toque em Favoritar.", sem botão) · linha em swipe.

**P4 Histórico** — normal · vazio (`ContentUnavailableView` com
`figure.pool.swim`, "Nenhum treino registrado" / "Gere um treino, nade com o
relógio, e o volume aparece aqui.") · semana sem treino (barra vazia, nunca
buraco no eixo) · sessão de origem externa (selo "fora do app").

**P5 Ajustes** — normal · confirmação de apagar dados em duas etapas ·
"Restaurar compra" em processamento (`ProgressView` na linha).

**P6 Piscina** — normal · primeira abertura (obrigatória, sem botão voltar,
nenhuma opção pré-selecionada, botão "Continuar" na barra inferior).

**P7 Paywall** — normal · compra em processamento · compra restaurada.

**Relógio** — W1 início · W2 gerar · W3 favoritos e vazio · W4
pré-visualização · W5 piscina · W6 contagem · W7 nadando e Always-On · W8
descansando, últimos 3 s e Always-On · W9 desbloqueada · W10 resumo em quatro
variantes (concluído, encerrado antes, muito curto, falha ao salvar) · W11 erro
de autorização.

---

## 7. Paleta e regras do Apple Watch

O relógio não segue o design system do iPhone.

1. Fundo `#000000` puro em toda tela. Nunca cinza escuro, nunca material.
2. Cor por estado: nadando `#0E9BC4`, descansando `#FF9F0A`, últimos 3 segundos
   `#30D158`, encerrar `#FF453A`.
3. Uma informação em destaque por tela, nunca duas. No máximo três elementos de
   texto na tela de execução.
4. A contagem de descanso é o maior elemento de todo o app: **mínimo 52 pt**, na
   prática 76 pt em 41 mm e 94 pt em 49 mm.
5. Nenhuma ação obrigatória depende do toque. O Water Lock está ligado durante o
   treino; a tela ignora o dedo. Avanço de série vem da contagem de voltas.
6. **Nenhum estado é sinalizado só por cor.** Âmbar e verde têm contraste de
   1,02:1 entre si: quem tem daltonismo vê a mesma cor. A passagem para os
   últimos 3 segundos muda a cor **e** aumenta o número de 76 pt para 90 pt (em
   49 mm, de 94 pt para 110 pt) **e** pulsa uma vez por segundo.
7. Always-On: luminância reduzida, `watchDimSwimming` / `watchDimResting`, sem
   animação, apenas repetição e distância.

---

## 8. Movimento

Uma única animação no app inteiro: ao gerar um treino, o numeral da distância
conta de 0 até o valor final.

```swift
.animation(.easeOut(duration: 0.4), value: distancia)
```

Duração 0,4 s, curva `easeOut`. Com `accessibilityReduceMotion` ligado, o valor
final aparece direto, sem contagem.

Fora disso, só as transições padrão de `NavigationStack`, `TabView` e `.sheet`.
A pulsação da contagem final no relógio (item 6 acima) é sinal de
acessibilidade, não decoração, e permanece com Reduce Motion ligado.

---

## 9. Acessibilidade

- Contraste mínimo **4,5:1** para texto normal e **3:1** para texto grande, nos
  dois temas. É por isso que `AccentTint` claro é `#0A7593`.
- Nenhum texto branco sobre `#0E9BC4`: dá 3,23:1.
- Área de toque mínima **44 × 44 pt**.
- Dynamic Type até **AX5** sem truncar. Nas listas o texto quebra em várias
  linhas: `.lineLimit(nil)` e `.fixedSize(horizontal: false, vertical: true)`.
  A única exceção são os números do Histórico, que usam `.lineLimit(1)` +
  `.minimumScaleFactor(0.7)` para caber "96.800 m".
- Cor nunca é a única portadora de informação: seleção tem `checkmark`, aviso tem
  `exclamationmark.triangle.fill`, origem externa tem texto "fora do app", e o
  estado final do descanso muda de tamanho além de mudar de cor.
- Reduce Transparency: substituir o material da barra inferior e da `TabView` por
  `SurfaceElevated` opaco.
- `accessibilityLabel` em todo botão só com símbolo (Ajustes, fechar, copiar).

---

## 10. Guardrails de implementação

Onze regras. Cada uma reprova o build por conta própria.

1. **Não aninhe contêiner.** Nada de `.background()` com `RoundedRectangle` em
   linha de lista, nem `GroupBox` dentro de `Section`. Quem desenha fundo, canto
   e inset é o `List`.
2. **Nenhum `Font.system(size:)`.** Só `Font.TextStyle`. No iPhone, todo tamanho
   fixo em pontos é bug. Máximo de onze estilos no app inteiro.
3. **Um raio de canto:** 12 pt em contêiner desenhado à mão, `Capsule()` no botão
   da barra inferior. Nenhum outro valor de `cornerRadius`.
4. **`AccentTint` não preenche superfície.** Não use como `.background` de
   pílula, card, faixa ou bloco. Só em glyph, marcador, rótulo, `.tint` e traço
   do gráfico.
5. **Sem "chips".** Multi-seleção é linha de `List` com `checkmark`, não cápsula
   colorida em `HStack` rolável.
6. **Header de Section em Title Case.** Nunca `.textCase(.uppercase)`, nunca
   `.tracking()`. Se precisar, `.textCase(nil)` para desligar o padrão.
7. **Título grande recolhe ao rolar.** `.navigationBarTitleDisplayMode(.large)`
   com `NavigationStack`. Nunca um `Text` grande fixo no topo do `ScrollView`.
8. **Nenhum número em caixa de largura fixa.** Alinhamento vem de
   `.monospacedDigit()` e `VStack(alignment: .trailing)`, não de `.frame(width:)`.
9. **Não declare padding em linha de lista.** As exceções com valor estão na
   seção 5 e são só duas: numeral herói e gráfico.
10. **Só SF Symbols.** Nenhum `Path`, `Shape` ou asset vetorial para ícone. As
    únicas formas desenhadas são as barras do gráfico e o traço de cor da Section.
11. **Não reconstrua controle do sistema.** `Toggle`, `Stepper`, `List` row e
    swipe actions são os nativos, com `.tint` do app. A única exceção é o slider
    de intervalo de dois puxadores, que o SwiftUI não fornece.

Teste final de uma frase: se a tela, em modo claro e sem a cor de marca, pudesse
ser confundida com uma tela dos Ajustes do iOS, está certa. Se parece um
dashboard, está errada.
