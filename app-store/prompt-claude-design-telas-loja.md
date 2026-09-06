# Prompt para o Claude Design — imagens da App Store do Vou Nadar

**Como usar:** abra o Claude Design, anexe **as quatro fotos** de
`fotos de pessoas/` e **as sete capturas** do app, e cole o bloco de prompt
abaixo. Cada peça combina uma captura com — em quatro casos — uma foto de fundo.

---

## O erro que este documento existe para não repetir

As peças saíram em **6,9" (1290 × 2796)**. O padrão da casa é **6,5"
(1242 × 2688)**, o mesmo que o Bilhete e o Swim Builder entregaram, e é a partir
dele que a App Store deriva os tamanhos menores.

Por isso o tamanho aparece **três vezes** no prompt abaixo — no topo, em cada
peça e na entrega. Modelo de imagem tende a arredondar dimensão para o que ele
já viu; repetir é o que segura.

**Se as peças de 6,9" já estiverem prontas, não precisa regerar.** A proporção é
a mesma (19,5:9), então converter é redimensionar e aparar 4 px:

```bash
for f in *.png; do sips --resampleWidth 1242 "$f" --out "$f" >/dev/null && sips -c 2688 1242 "$f" >/dev/null; done
```

Confira depois — o passo que ninguém faz e que é o motivo desta seção existir:

```bash
for f in *.png; do echo -n "$f: "; sips -g pixelWidth -g pixelHeight "$f" | awk -F': ' '/pixel/{printf "%s ", $2}'; echo; done
```

---

## O prompt

```
Preciso das sete imagens de divulgação da App Store para um app iOS chamado
Vou Nadar. Vou anexar capturas de tela reais do app e quatro fotos de piscina;
use cada uma dentro de uma peça, conforme a lista.

FORMATO — obrigatório, é o que a App Store exige:
- Cada peça tem EXATAMENTE 1242 × 2688 pixels, retrato, PNG. Não é 1290 × 2796,
  não é 1284 × 2778, não é "proporção equivalente": é 1242 × 2688 exatos.
- A captura do app aparece dentro de uma moldura de iPhone (bordas arredondadas,
  sem mãos, sem sombra exagerada, sem perspectiva 3D).
- O aparelho ocupa a metade de baixo da peça e pode sangrar no rodapé.
- Reserve o terço superior para o texto: um título curto e uma linha de apoio
  menor. Nada de texto sobre a tela do aparelho.
- Nada de ícone flutuante, seta desenhada, balão, emoji ou "confira!".

AS FOTOS DE FUNDO:
Quatro peças levam foto de piscina atrás; três têm fundo liso. Isso é
deliberado — sete imagens seguidas com foto viram catálogo de banco de imagens e
a tela do app some. Alternar dá ritmo.
As fotos são 1536 × 2752, mais estreitas que a peça na proporção: sobra altura e
falta largura. Não corte pelo centro por padrão — decida o corte olhando onde
está o nadador, e nunca corte a cabeça nem a mão dele.

PALETA — a mesma do app, para a ficha parecer o produto. Todas as capturas são
do tema escuro, que é o padrão do app:
- Fundo das peças sem foto: #061620
- Superfície: #0C2531
- Texto do título: #EAF4F8
- Texto de apoio: #8FA9B6
- Cor de acento, com parcimônia: #0E9BC4
- Sobre foto escura, o texto é branco puro. Sobre a foto clara (a da mulher na
  borda), o texto é #06485C — branco ali não passa no contraste.
- Sem roxo, sem laranja de gradiente, sem arco-íris. O laranja #E8813C existe no
  app, mas só como cor da seção principal do treino: não use como cor de peça.

TIPOGRAFIA: uma família sem serifa, SF Pro ou equivalente. Título em semibold,
apoio em regular. Sem fonte decorativa, sem manuscrita, sem itálico.

O QUE O APP É — para o texto ficar fiel:
O Vou Nadar monta um treino de piscina e o executa no Apple Watch. A pessoa diz
quanto quer nadar, que equipamento levou na mochila e qual é o tamanho da
piscina; o app devolve o treino completo com o descanso de cada bloco já
definido. No relógio, o treino roda sozinho: conta as voltas pela distância
medida e avisa por vibração quando entra e quando sai do descanso — a pessoa não
toca em nada com a mão molhada.

O tom é de treinador anotando a série num quadro na parede. Frase curta, direta,
sem entusiasmo forçado e sem gamificação. Nunca "Mandou bem!", nunca "Transforme
seus treinos!", nunca ponto de exclamação. Fale do problema que a pessoa tem às
6h da manhã, não das funcionalidades do software.

REGRA DE ESCRITA — quem lê ainda não instalou o app:
Nenhum título pode depender do vocabulário interno do produto. "Soltura",
"progressão", "ritmo de descanso" e "educativo" são nomes de dentro do app.
Podem aparecer na tela capturada, que é real, mas o texto do topo fala de o que
acontece com a pessoa, não de como o app chama as coisas.

AS SETE PEÇAS, nesta ordem, com o texto exato:

1. Foto `Gemini_Generated_Image_g1aouhg1aouhg1ao.jpeg` (nadador em silhueta,
   visto de baixo d'água) + captura da tela de detalhe do treino
   Título: "O treino sai com o descanso definido"
   Apoio: "Cada bloco já vem com quantos segundos parar. Você não decide isso na
   borda."

2. Sem foto, fundo #061620 + captura da tela de tamanho da piscina, com "Outro"
   aberto em 16 m
   Título: "Funciona na piscina de 16 m do seu prédio"
   Apoio: "O treino se adapta a voltas inteiras. De 10 a 50 metros."

3. Foto `Gemini_Generated_Image_4sfq8s4sfq8s4sfq.jpeg` (homem na borda,
   respirando forte) + captura do Apple Watch na tela de descanso
   Título: "Na borda, o pulso conta o descanso"
   Apoio: "Vibra quando começa, vibra quando faltam três segundos, vibra quando
   é hora de sair."

4. Sem foto, fundo #061620 + captura do Apple Watch nadando, mostrando "3 de 4"
   Título: "Voltas e metros contados sozinhos"
   Apoio: "Você nada. O relógio sabe onde você está no treino."

5. Foto `Gemini_Generated_Image_tjuyk0tjuyk0tjuy.jpeg` (vista aérea, nadador
   numa raia) + captura da tela inicial, com equipamentos marcados
   Título: "Você escolhe o que levou na mochila"
   Apoio: "Pull buoy, palmar, prancha, nadadeira, snorkel. O treino usa só o que
   você tem."

6. Foto `Gemini_Generated_Image_2lc2ka2lc2ka2lc2.jpeg` (mulher na borda, com
   espaço vazio à esquerda) + captura do histórico, com o gráfico de semanas.
   Esta é a foto clara: título e apoio em #06485C, e o gráfico entra sobre a
   área lisa da esquerda.
   Título: "O que você nadou vai para o app Saúde"
   Apoio: "A sessão fica registrada como treino de natação, com distância e
   tempo."

7. Sem foto, fundo #061620 + captura dos favoritos, com "Feito N vezes" visível
   Título: "Favorite no iPhone. Aparece no relógio."
   Apoio: "E o relógio ainda gera treino novo com o iPhone desligado no
   armário."

REGRAS DE HONESTIDADE — não invente recurso:
- O app é só de NADO LIVRE em piscina. Não escreva nada sobre costas, peito,
  borboleta, medley ou águas abertas: não existem nesta versão.
- Não escreva nada sobre pace, tempo por 100 m, velocidade, intervalo de saída
  nem previsão de tempo. O app não calcula nada disso.
- Não escreva nada sobre nuvem, conta, login, sincronização entre aparelhos além
  do envio direto iPhone → Apple Watch, nem sobre compartilhar treino como
  imagem. Nada disso existe.
- Não escreva "sem IA" como afirmação sobre o material inteiro — as próprias
  fotos destas peças são geradas por IA. Se quiser usar o argumento, ele é
  específico: "treinos criados a partir da experiência de atletas amadores, não
  gerados por IA", e fala do catálogo, não das imagens.
- Não invente número de usuários, avaliação, prêmio nem "usado por milhares".
- Não escreva "grátis" sem qualificar: gerar treino é grátis e ilimitado; as três
  primeiras execuções guiadas no relógio também; depois é uma compra única.
- Nenhuma peça pode mostrar preço. Se alguma captura tiver valor na tela, ele
  precisa ser R$ 49,90 — nunca R$ 29,90, que é preço de outro app.

ENTREGA:
Sete peças, uma por captura, todas em EXATAMENTE 1242 × 2688 pixels, com o mesmo
tratamento visual entre si — mesma moldura, mesma altura de aparelho, mesma
posição de título — para a fileira na App Store parecer uma sequência, e não sete
imagens soltas. Diga no fim, peça por peça, a dimensão em pixels de cada arquivo
gerado.
```

---

## As capturas que entram nas peças

Todas no **tema escuro**, com dados plausíveis. Print vazio não vende, e treino
com distância absurda a App Store recusa.

| Peça | Tela | Estado a preparar |
|---|---|---|
| 1 | P2 Detalhe do treino | Um treino de ~2.100 m, com os descansos visíveis em várias séries |
| 2 | P6 Tamanho da piscina | "Outro" aberto, valor em 16 m |
| 3 | W8 Descansando | Contagem em âmbar, número grande, próxima repetição embaixo |
| 4 | W7 Nadando | `3 de 4`, série atual e acumulado |
| 5 | P1 Home | Faixa em 1.500–2.500, pull buoy e nadadeira marcados |
| 6 | P4 Histórico | Cinco ou seis semanas de volume, com barras de alturas diferentes |
| 7 | P3 Favoritos | Três ou quatro favoritos nomeados, com "Feito N vezes" |

### Como capturar

Fixe a barra de status antes — hora quebrada e bateria pela metade denunciam
captura de desenvolvimento:

```bash
xcrun simctl status_bar "iPhone 17 Pro" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
```

Relógio (o simulador do Series 11 de 46 mm produz 416 × 496 px nativos — o print
entra **pequeno e centralizado** na composição, nunca ampliado a ponto de
pixelar):

```bash
xcrun simctl io "Apple Watch Series 11 (46mm)" screenshot w8-descansando.png
```

### O que nunca pode aparecer

Hora falsa ou inconsistente entre as peças, bateria pela metade, nome de usuário,
treino com distância absurda, e — o mais fácil de deixar passar — qualquer tela
mostrando **R$ 29,90**.

---

## Depois de gerar

1. Confira que **cada arquivo** tem exatamente 1242 × 2688 px, com o comando do
   topo deste documento. Não confie no que o modelo disser que gerou.
2. Confira que todo número visível saiu de um treino de verdade — a App Store
   recusa print que mostre funcionalidade que o app não tem.
3. Confira que as sete peças parecem uma sequência: mesma moldura, mesma altura
   de aparelho, mesma posição de título.
4. A galeria do **Apple Watch** é separada e não passa por aqui: são as cinco
   capturas diretas da seção 5 do [`ROTEIRO-PRINTS.md`](ROTEIRO-PRINTS.md), sem
   foto de fundo e sem texto.
