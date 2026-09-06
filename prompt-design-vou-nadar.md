# Prompt de design — Vou Nadar — rodada 2 (atualizar o projeto existente)

> Gerado a partir do `spec-vou-nadar.md` v1.1, seções 8, 9, 10, 14, 15 e 16.
> **Este prompt é para rodar NO MESMO projeto do Claude Design**, não num novo. Ele preserva o ícone e as telas do Apple Watch aprovados na rodada 1, substitui as telas de iPhone, e no fim produz o documento de design system para o Claude Code.
> Cole o bloco abaixo inteiro.

---

```
Este é um trabalho de ATUALIZAÇÃO deste projeto, não um projeto novo. Leia as
três instruções antes de qualquer coisa.

============================================================================
INSTRUÇÃO 1 — O QUE PRESERVAR, SEM TOCAR
============================================================================
Duas coisas já foram aprovadas e NÃO devem ser regeradas, redesenhadas nem
"melhoradas":

a) O ÍCONE DO APP — a direção "A raia": duas divisórias de raia vistas de cima,
   boias alternadas formando o corredor, nas quatro versões (clara #0E9BC4,
   escura #06485C, tingida em escala de cinza, e a prévia circular do relógio).
   Mantenha exatamente como está. As outras direções de ícone que foram
   exploradas podem ser removidas do canvas.

b) AS 11 TELAS DO APPLE WATCH — W1 a W11, em 41 mm e 49 mm, com as variantes
   Always-On e a dos últimos 3 segundos. Mantenha o conceito, o layout e as
   cores. Se precisar mexer, mexa só no que a Instrução 3 pedir explicitamente.

============================================================================
INSTRUÇÃO 2 — O QUE SUBSTITUIR
============================================================================
TODAS as telas de iPhone da rodada anterior devem ser DESCARTADAS e refeitas do
zero segundo o briefing abaixo. Elas foram reprovadas: pareciam app genérico.

O problema é identificável, não é impressão. As telas antigas tinham cabeçalho
de seção em CAIXA ALTA com letter-spacing, todo bloco de conteúdo dentro de um
retângulo com borda e canto arredondado, botão primário como retângulo sólido
no meio do conteúdo, e tab bar desenhada à mão com ícones próprios.

O alvo é o oposto. Este app tem que parecer construído com os componentes do
iOS, porque vai ser.

ONZE REPROVAÇÕES AUTOMÁTICAS PARA AS TELAS DE IPHONE:
 1. Tudo dentro de um card; card dentro de card.
 2. Mais de onze tamanhos de fonte. Qualquer tamanho fixo em pontos.
 3. Vários raios de canto diferentes.
 4. A cor de marca preenchendo superfície — pílula sólida, botão sólido no meio
    do conteúdo, barra sólida, faixa larga.
 5. "Chips". Não é idioma de iOS, é Material Design.
 6. Cabeçalho de seção em CAIXA ALTA com letter-spacing.
 7. Título grande estático, que não encolhe ao rolar.
 8. Números dentro de caixas de largura fixa.
 9. Paddings fora de qualquer grade.
10. Ícones desenhados à mão em vez de SF Symbols.
11. Toggle, slider e linha de lista redesenhados do zero.

TESTE DE UMA FRASE: se a tela, em modo claro e sem a cor de marca, pudesse ser
confundida com uma tela dos Ajustes do iOS, está certa. Se parece um dashboard,
está errada.

Isto vale só para o IPHONE. O relógio tem regras próprias e já está aprovado.

============================================================================
INSTRUÇÃO 3 — O QUE ACRESCENTAR NO FIM
============================================================================
Depois das telas, produza um DOCUMENTO DE DESIGN SYSTEM em português, descrito
no fim deste prompt. Ele vai ser lido por um agente de código (Claude Code) que
vai implementar o app em SwiftUI, então precisa de valores exatos e nomes
exatos, não de descrição visual.

============================================================================
O APP
============================================================================
Vou Nadar: app de natação para iPhone e Apple Watch. O iPhone monta o treino, o
Apple Watch guia o nadador dentro da água contando as voltas e mostrando quanto
falta de descanso na borda.

100% offline, sem conta, sem login. Só iPhone (retrato) e Apple Watch. Só
português do Brasil. Um único perfil — o dono do aparelho.

CONTEXTO DE USO: seis da manhã, vestiário de clube ou academia. A pessoa está
com pressa, ou já molhada, sem óculos de leitura, o celular numa sacola. Texto
grande, contraste alto, área de toque generosa.

============================================================================
ESTRUTURA DO IPHONE — a parte mais importante
============================================================================
Use componentes nativos do iOS com os valores PADRÃO deles. Não invente
contêiner, não especifique padding, não especifique raio de canto.

  Home, Favoritos, Ajustes, Piscina  →  List com estilo inset grouped
  Detalhe do treino                  →  numeral herói + List com 4 Section
  Histórico                          →  números soltos + gráfico + List
  Paywall                            →  sheet
  Botão primário                     →  barra inferior de área segura, estilo
                                        glass prominent

Agrupamento vem do Section e do espaço em branco, NÃO de retângulos com fundo.
Separadores são os do List. Quem desenha fundo, canto e inset é o List.

Contêiner desenhado à mão é permitido em EXATAMENTE dois lugares: o bloco do
numeral herói no Detalhe, e o gráfico de volume no Histórico. Em todo o resto,
componente do sistema.

============================================================================
TIPOGRAFIA — regra dura no iPhone
============================================================================
SOMENTE os onze estilos semânticos do iOS. NENHUM tamanho fixo em pontos:
  largeTitle · title · title2 · title3 · headline · subheadline · body ·
  callout · footnote · caption · caption2

  Título de tela .............. largeTitle, que ENCOLHE para o título da barra
                                ao rolar. Desenhe os dois estados.
  Distância total (herói) ..... largeTitle em SF Pro Rounded Bold, dígitos
                                monoespaçados
  Cabeçalho de seção .......... o header padrão do Section, em Title Case
  Nome do exercício ........... body
  Metragem e descanso ......... body monoespaçado, cor secundária, à direita
  Descrição do exercício ...... footnote, cor secundária
  Selo de modo ................ caption2, cor secundária, com SF Symbol antes.
                                SEM pílula colorida.

SF Pro do sistema. SF Pro Rounded APENAS no numeral herói.

============================================================================
COR — tokens fechados, não proponha outros
============================================================================
Vieram do ícone e os contrastes já foram calculados.

TEMA ESCURO (padrão):        TEMA CLARO:
  fundo               #061620    #F4F8FA
  superfície agrupada #0C2531    #FFFFFF
  superfície elevada  #12313F    #E9F1F5
  destaque (tint)     #0E9BC4    #0A7593
  texto primário      #EAF4F8    #0B1B23
  texto secundário    #8FA9B6    #5A7285
  hairline            #1C3A48    #DBE6EC

O tint do tema claro é #0A7593 e NÃO #0E9BC4, porque o azul de marca sobre
branco dá só 3,23:1 e reprova o critério de acessibilidade. Não troque.

Semânticas, reservadas a significado (escuro / claro):
  sucesso #30D158 / #1F8A55   alerta #FF9F0A / #9A6B10
  erro    #FF453A / #B3352C

REGRA CRÍTICA DO AZUL: ele marca INTERAÇÃO E ESTADO, não preenche superfície.
Aparece no glyph da aba ativa, no marcador de seleção, no rótulo de um botão,
no tint de um Toggle ligado, no traço do gráfico. NÃO aparece como fundo de
pílula, fundo de card, faixa larga ou bloco de cor.

Cores das quatro seções do treino — um ponto pequeno OU um traço fino de 3 pt
junto ao cabeçalho da Section, ou nada. Nunca fundo, nunca faixa:
  Aquecimento #5AA9E6 · Progressão #0E9BC4 · Parte principal #E8813C ·
  Soltura #8FA9B6

Ícones: SF Symbols, sempre. Nenhum SVG desenhado à mão.

TEMAS: escuro (padrão) e claro. Desenhe no escuro primeiro.

MOVIMENTO: ao gerar, o numeral da distância anima de 0 ao valor final em 0,4 s
com easeOut. É o único momento de espetáculo do app. Com Reduce Motion, direto.

NAVEGAÇÃO: TabView nativa. Três abas: Treino · Favoritos · Histórico. Glyph
ativo no tint; a cápsula atrás dele é do SISTEMA e não deve ser redesenhada em
cor de marca. Ajustes é uma engrenagem na barra de navegação da Home, não uma
aba. Sem menu lateral. Sem botão flutuante próprio.

============================================================================
AS 7 TELAS DE IPHONE
============================================================================

--- P1 HOME (aba "Treino") ---
List inset grouped, título grande "Vou Nadar", engrenagem de Ajustes na barra.
  Section "Distância": uma linha com rótulo à esquerda e "1.500 – 2.500 m" à
    direita; abaixo, na mesma Section, um slider de intervalo com dois
    puxadores. A faixa PODE ser fechada — arrastar um puxador até o outro é
    permitido e mostra "2.000 m". Desenhe também esse estado.
  Section "Equipamento na mochila": QUATRO LINHAS com marcador de seleção —
    Pull buoy, Palmares, Nadadeiras, Prancha. Multi-seleção, zero ou mais.
    NÃO use chips. Marcador no tint, texto na cor primária.
  Section sem título com dois Toggle:
    "Incluir educativos" / footnote "Um bloco de técnica no aquecimento"
    "Incluir pernada"    / footnote "Um bloco de perna na parte principal"
    Desenhe os dois estados de cada.
  Botão "Gerar treino" na barra inferior de área segura, estilo glass
    prominent. NÃO um retângulo sólido no meio do conteúdo.

Três variantes:
  a) normal
  b) bloqueada, piscina não confirmada: botão desabilitado e, acima dele,
     "Configure o tamanho da piscina para gerar treinos."
  c) aviso de repertório curto: linha de aviso no topo da lista, SF Symbol de
     alerta na cor de alerta, texto "Com essa piscina e esses filtros sobram
     poucos exercícios, então os treinos vão se repetir. Marcar mais
     equipamento ajuda." É AVISO, não bloqueio — Gerar continua ativo.

--- P2 DETALHE DO TREINO ---
Numeral herói no topo, FORA da lista: "2.100" em largeTitle rounded bold, "m"
menor ao lado, "Total" em caption abaixo. Quando já executado, "Feito 3 vezes"
em footnote.
Abaixo, List com QUATRO Section, headers em Title Case: Aquecimento,
Progressão, Parte principal, Soltura. Cada série é uma linha comum:
  selo de modo (quando houver) + nome em body + descrição em footnote embaixo;
  à direita, metragem em body monoespaçado e descanso em footnote secundário —
  por exemplo "4×100" à esquerda, "30s" à direita.
Seção sem série: uma linha em texto secundário dizendo que não há séries. Não
some, não vira card vazio.
Ações: "Favoritar" como botão primário na barra inferior; "Gerar outro" e
"Copiar como texto" na barra de navegação ou numa linha secundária — NÃO três
botões grandes empilhados.

Três variantes:
  a) piscina de 25 m, números redondos
  b) piscina de tamanho incomum: as séries mostram "4×96" em vez de "4×100", e
     logo abaixo do numeral herói, em footnote secundário: "As distâncias foram
     ajustadas para fechar voltas inteiras na sua piscina de 16 m."
  c) rolagem longa, com o título grande já encolhido na barra
Mais a confirmação "Treino copiado." depois de tocar em Copiar como texto.

--- P3 FAVORITOS (aba) ---
List puro. Cada linha: título em body, "2.100 m · nadado 7 vezes" em footnote
secundário. Swipe actions nativas: Renomear, Apagar (destrutivo).
Vazio: "Nenhum treino salvo ainda" + "Gere um treino e toque em Favoritar."
Sem botão — a frase explica o caminho.

--- P4 HISTÓRICO (aba) ---
Título grande "Histórico".
Os números da semana SOLTOS, sem caixa: valor em title2 monoespaçado, rótulo em
caption abaixo. Precisa caber "96.800 m" sem quebrar linha — use
minimumScaleFactor, não caixa de largura fixa.
Gráfico de volume das últimas 12 semanas logo abaixo, SEM moldura. Barras finas
no tint, semana sem treino como barra vazia — nunca buraco no eixo.
Depois, List de sessões: data e distância em body, duração em footnote. Sessões
vindas de outros apps de natação levam um selo caption2 secundário "fora do
app". Swipe para Apagar.
Vazio: SF Symbol grande em cor secundária + "Nenhum treino registrado" + "Gere
um treino, nade com o relógio, e o volume aparece aqui."

--- P5 AJUSTES ---
List inset grouped:
  Section "Piscina": linha de navegação com chevron mostrando "25 m" à direita
  Section "Descanso": três opções com marcador de seleção — Curto, Normal,
    Longo — e footer da Section: "Ajusta o descanso de todo o treino. Curto
    para quem já tem fôlego, longo para quem está voltando."
  Section "Equipamento": as mesmas quatro linhas com marcador de seleção
  Section "Sobre": versão do app, versão do catálogo, Política de Privacidade,
    Suporte
  Section: "Restaurar compra"
  Section: "Apagar todos os dados" — linha destrutiva na cor de erro,
    confirmação em duas etapas

--- P6 PISCINA ---
List inset grouped, título "Tamanho da piscina".
  Section com duas linhas de seleção: "25 m" e "50 m"
  Section "Outro": uma linha com Stepper nativo, de 10 a 50 metros
  Footer: "Piscina de condomínio e academia costuma ter 12, 15, 16, 18 ou 20
    metros."
Desenhe também o estado de primeira abertura, em que a tela é obrigatória e não
tem botão de voltar.

--- P7 PAYWALL ---
Sheet. Título "Continue nadando com o Vou Nadar". Corpo: "Compra única. Sem
assinatura, sem mensalidade, sem anúncio. Vale para sempre, em todos os seus
aparelhos." Botão de compra na barra inferior, "Restaurar compra" como linha de
texto discreta abaixo.

============================================================================
COPY — usar LITERALMENTE, é texto final
============================================================================
Abas: Treino · Favoritos · Histórico
Home: "Distância" · "Equipamento na mochila" · "Incluir educativos" / "Um bloco
      de técnica no aquecimento" · "Incluir pernada" / "Um bloco de perna na
      parte principal" · "Gerar treino" ·
      "Configure o tamanho da piscina para gerar treinos." ·
      "Com essa piscina e esses filtros sobram poucos exercícios, então os
      treinos vão se repetir. Marcar mais equipamento ajuda."
Seções do treino, em Title Case (NUNCA caixa alta na interface):
      "Aquecimento" · "Progressão" · "Parte principal" · "Soltura"
Selos de modo: "braçada" · "pernada" · "técnica"
Detalhe: "Total" · "Favoritar" · "Gerar outro" · "Copiar como texto" ·
      "Treino copiado." · "As distâncias foram ajustadas para fechar voltas
      inteiras na sua piscina de 16 m."
Piscina: "Tamanho da piscina" · "Piscina de condomínio e academia costuma ter
      12, 15, 16, 18 ou 20 metros."
Ajustes: "Ajusta o descanso de todo o treino. Curto para quem já tem fôlego,
      longo para quem está voltando." · "Restaurar compra" · "Apagar todos os
      dados"
Paywall: "Continue nadando com o Vou Nadar" · "Compra única. Sem assinatura,
      sem mensalidade, sem anúncio. Vale para sempre, em todos os seus
      aparelhos."
Vazios: "Nenhum treino salvo ainda" / "Gere um treino e toque em Favoritar."
      "Nenhum treino registrado" / "Gere um treino, nade com o relógio, e o
      volume aparece aqui."

Nomes reais de exercício, para dimensionar as linhas:
  "4x100 Crawl Progressivo" — 400 m
  "1x200 Braçada Alternando 25 Forte / 25 Leve" — 200 m (selo "braçada")
  "4x50 Pernada com Prancha" — 200 m (selo "pernada")
  "4x50 Pegada Dupla" — 200 m (selo "técnica")
  "1x1000 Pirâmide 50-100-150-200-200-150-100-50" — 1.000 m
O nome mais longo tem 45 caracteres e a linha tem que comportar isso, com selo
e ícone, sem truncar.

============================================================================
ACESSIBILIDADE — requisito
============================================================================
- Dynamic Type até AX5 sem truncar. Nas listas o texto quebra em várias linhas.
  Entregue Home e Detalhe também em AX5.
- Contraste mínimo 4,5:1 (texto normal) e 3:1 (texto grande), nos dois temas.
- Área de toque de 44 × 44 pt.
- Cor NUNCA é a única portadora de informação.
- Entregue uma variante da Home com Reduce Transparency.

============================================================================
ENTREGÁVEL 1 — AS TELAS
============================================================================
As 7 telas de iPhone em tema escuro (padrão) e claro; as três variantes da
Home; as três variantes do Detalhe; Home e Detalhe também em AX5; Home em
Reduce Transparency; Detalhe com o título grande encolhido ao rolar; os estados
vazios de Favoritos e Histórico; a confirmação "Treino copiado."

O ícone e as 11 telas do Apple Watch permanecem como estão (Instrução 1).

============================================================================
ENTREGÁVEL 2 — O DOCUMENTO DE DESIGN SYSTEM
============================================================================
Produza, ao fim, um documento chamado DESIGN-SYSTEM.md, em PORTUGUÊS, que vai
ser lido por um agente de código que implementa o app em SwiftUI. Ele não vai
ver as telas: só este documento. Então ele precisa de VALORES E NOMES EXATOS,
não de descrição visual. Nada de "azul suave", "espaçamento generoso",
"tipografia elegante".

Estrutura obrigatória, nesta ordem:

1. TOKENS DE COR
   Tabela com quatro colunas: nome do token, nome do Color Set a criar no
   asset catalog, hex no tema claro, hex no tema escuro. Uma linha por token,
   incluindo os semânticos e as quatro cores de seção. Depois, uma tabela
   separada só com os tokens do Apple Watch, que não têm tema.
   Inclua também, em uma frase por token, ONDE ele pode e ONDE ele não pode
   ser usado.

2. TIPOGRAFIA
   Tabela: elemento da interface → estilo semântico do iOS (o nome exato da
   API, ex.: .largeTitle) → peso → design (.default ou .rounded) → dígitos
   monoespaçados sim/não. Uma linha por elemento que aparece nas telas.
   Declare explicitamente que nenhum tamanho fixo em pontos é permitido.

3. COMPONENTES
   Tabela: elemento da interface → componente SwiftUI exato, com o modificador
   de estilo quando houver. Por exemplo "lista de ajustes → List com
   .listStyle(.insetGrouped)". Cubra toda tela que você desenhou. Onde usei
   contêiner desenhado à mão (numeral herói, gráfico), diga isso
   explicitamente e dê as medidas dele — são as duas únicas exceções.

4. SF SYMBOLS
   Lista com o NOME EXATO de cada símbolo usado, e em que contexto. Sem isso o
   agente de código inventa nome de símbolo e o app quebra em silêncio.

5. ESPAÇAMENTO E LAYOUT
   Declare que se usa o padrão do sistema em tudo, e liste as ÚNICAS exceções
   com valor numérico. Não invente uma escala de espaçamento.

6. ESTADOS
   Para cada tela, quais estados existem (normal, vazio, carregando, erro,
   bloqueado, desabilitado) e o que muda visualmente em cada um.

7. PALETA E REGRAS DO APPLE WATCH
   Seção separada, porque o relógio não segue o design system do iPhone: fundo
   preto puro, cor por estado, o tamanho mínimo da contagem de descanso, e a
   regra de que nenhum estado é sinalizado só por cor.

8. MOVIMENTO
   A única animação do app, com duração e curva, e o comportamento com Reduce
   Motion ligado.

9. ACESSIBILIDADE
   As regras que o código precisa respeitar, com números: contraste mínimo,
   área de toque, Dynamic Type até AX5, e a regra de redundância de sinal.

10. GUARDRAILS DE IMPLEMENTAÇÃO
    As onze reprovações automáticas, reescritas como regras para quem
    implementa, não para quem desenha. É a seção que impede o código de
    reintroduzir o problema que o design acabou de resolver.

Entregue o DESIGN-SYSTEM.md como texto que eu possa copiar para um arquivo.
```

---

## Notas para o Alexandre (não colar no Claude Design)

- Rode isto **no projeto que já existe**. As instruções 1 e 2 no topo é que fazem o ícone e o relógio sobreviverem.
- Ainda assim, **exporte o ícone antes** — os quatro PNG de 1024×1024 (clara, escura, tingida, e a mesma arte para o target watchOS). Instrução no prompt é intenção, backup é garantia.
- O `DESIGN-SYSTEM.md` é o que fecha a lacuna entre o design e o Claude Code. Sem ele, o agente lê o spec, não vê as telas, e reinventa a interface — que é como se volta ao visual de app genérico pelo outro caminho.
- Se as seções 10, 14, 15 ou 16 do spec mudarem, este arquivo é regerado junto.
