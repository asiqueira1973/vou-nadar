# Vou Nadar — roteiro das imagens da App Store

Documento de preparação da ficha da loja. Não é documentação técnica: o
`DOCUMENTACAO-TECNICA.md` descreve o sistema, este descreve o **material de
submissão**.

Fecha o último item do Definition of Done (seção 26 do spec): *"Screenshots de
iPhone e de Apple Watch na ficha da loja"*.

---

## 1. O formato: imagem composta, não print solto

As imagens da galeria são **desenhadas**, não capturadas. Cada uma tem três
camadas:

```
┌─────────────────────────────┐
│  foto de piscina (fundo)    │  ← fotos de pessoas/
│                             │
│  TEXTO DE MARKETING         │  ← frase curta, alto contraste
│                             │
│     ┌───────────────┐       │
│     │ print do app  │       │  ← captura real da tela
│     │               │       │
│     └───────────────┘       │
└─────────────────────────────┘
```

**Tamanho de composição: 1242 × 2688 px (6,5"), retrato** — o mesmo que o Swim
Builder entregou em `app-store/appstore-entrega/iphone-1242x2688/`.

> **Conferir no App Store Connect antes de subir.** A Apple passou a pedir o
> conjunto de **6,9" (1290 × 2796)** para submissões novas, e o 6,5" virou
> herança. Como estas imagens são **desenhadas**, e não capturas cruas, elas
> podem ser renderizadas nos dois tamanhos a partir do mesmo layout — o que muda
> é o canvas, não o conteúdo. Não descubra isso no dia da submissão.

As fotos são **1536 × 2752**, um pouco mais estreitas que 1242 × 2688 na
proporção (0,558 contra 0,462): sobra altura e falta largura. Cortar pelo centro
perde as laterais; o corte tem que ser decidido foto a foto, olhando onde está o
nadador.

---

## 2. Posicionamento — o que os textos precisam dizer

Cinco diferenciais, na ordem de força. Valem para a **descrição da ficha** e para
os **textos das imagens**, e é por isso que vêm antes da tabela de imagens: o
texto decide qual tela vale a pena mostrar, não o contrário.

| # | Diferencial | Por que pega |
|---|---|---|
| 1 | **Piscina de tamanho de condomínio** | Nenhum concorrente serve raia de 12, 15, 16, 18 ou 20 m. O app adapta a distância a voltas inteiras (regra 11.3) e o `4×100` vira `4×96` — quem nada em prédio nunca teve isso |
| 2 | **Treino no relógio, para quem tem** | Contagem de voltas e de metros automática, descanso com intervalo automático. O treino sai do armário e vai para o pulso |
| 3 | **Em português** | Não é tradução: a copy inteira é escrita em português, para nadador brasileiro |
| 4 | **Customização do treino** | Equipamento na mochila, educativos e pernada — o treino se ajusta ao que a pessoa tem e quer |
| 5 | **Gerado de experiência real de atleta amador, não por IA** | O catálogo é conteúdo humano, e o motor é algoritmo determinístico. Não há modelo de linguagem em lugar nenhum do app (spec 20: *"Não há IA embarcada"*) |

**Cuidado ao escrever o diferencial 5.** A afirmação é verdadeira sobre o
**treino** — catálogo humano, gerador determinístico, zero IA embarcada. Mas as
**fotos de apoio da galeria são geradas por IA**. As duas coisas não se
contradizem, e a ficha não deve deixar que sejam lidas juntas: fale "treinos
criados a partir da experiência de atletas amadores, não gerados por IA", que é
específico e verificável, em vez de "sem IA", que soa como afirmação sobre o
material inteiro.

---

## 3. As sete imagens da galeria

Todos os prints do app no **tema escuro**, que é o padrão declarado (seção 16.0
do spec) e o que combina com as fotos.

| # | Foto de fundo | Print do app | Texto de marketing |
|---|---|---|---|
| 1 | `g1aouh…` — nadador em silhueta, visto de baixo d'água | P2 Detalhe, com os descansos visíveis | **O treino sai com o descanso definido.** |
| 2 | *(sem foto)* | P6 Piscina, com "Outro" aberto em 16 m | **Funciona na piscina de 16 m do seu prédio.** |
| 3 | `4sfq8s…` — homem na borda, respirando forte | W8 Descansando, contagem em âmbar | **Na borda, o pulso conta o descanso.** |
| 4 | *(sem foto)* | W7 Nadando, `3 de 4` | **Voltas e metros contados sozinhos.** |
| 5 | `tjuyk0…` — vista aérea, nadador numa raia | P1 Home, pull buoy e nadadeiras marcados | **Você escolhe o que levou na mochila.** |
| 6 | `2lc2ka…` — mulher na borda, espaço vazio à esquerda | P4 Histórico, 5 semanas de volume | **O que você nadou vai para o app Saúde.** |
| 7 | *(sem foto)* | P3 Favoritos, com "Feito N vezes" | **Favorite no iPhone. Aparece no relógio.** |

São **sete**, não seis: o diferencial mais forte — piscina de condomínio — merece
imagem própria, e a App Store aceita até dez.

**Por que a 2, a 4 e a 7 não levam foto:** seis imagens seguidas com foto de fundo
viram um catálogo de banco de imagens, e a tela do app some. Alternar dá ritmo e
deixa as telas respirarem. Se você quiser foto nas seis, a reserva é a
`2lc2ka…`, que tem espaço morto suficiente para o print sentar em cima.

**Por que a `2lc2ka…` foi para o Histórico:** é a única com uma área grande e lisa à
esquerda. O gráfico do Histórico é largo e precisa desse espaço; nas outras
fotos ele cairia em cima do corpo do nadador.

**Notas de composição:**
- O texto de marketing é **frase curta em uma ou duas linhas**, no tom da seção
  15 do spec: direto, sem exclamação, sem gerúndio de call-center.
- A cor do texto sobre foto é branco puro. Sobre a `2lc2ka…`, que é clara, use o
  `azul_profundo` `#06485C` — branco ali não passa no contraste.
- Nada de moldura de iPhone desenhada à mão em volta do print, e nada de seta ou
  balão apontando para elemento de interface.

---

## 4. Capturando os prints que entram nas composições

### iPhone

O simulador de desenvolvimento (**iPhone 17 Pro**, 1206 × 2622) serve, porque o
print vai ser **redimensionado dentro da composição** de qualquer jeito. Se
quiser a captura no tamanho nativo do 6,9", crie o Pro Max:

```bash
xcrun simctl create "iPhone 17 Pro Max" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max com.apple.CoreSimulator.SimRuntime.iOS-26-1
```

Fixe a barra de status antes de capturar — hora quebrada e bateria pela metade
denunciam captura de desenvolvimento:

```bash
xcrun simctl status_bar "iPhone 17 Pro" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3
```

### Apple Watch

Medido no simulador: o **Apple Watch Series 11 (46 mm)** produz **416 × 496 px**
nativos. É pouco para uma composição de 1242 px de largura — o print do relógio
tem que entrar **pequeno e centralizado**, nunca ampliado a ponto de pixelar.

```bash
xcrun simctl io "Apple Watch Series 11 (46mm)" screenshot w8-descansando.png
```

### O que nunca pode aparecer

Hora falsa ou quebrada, bateria pela metade, nome de usuário, treino com
distância absurda, e — o mais fácil de deixar passar — **qualquer tela mostrando
R$ 29,90** (ver seção 6).

---

## 5. Galeria do Apple Watch

Além das composições de iPhone, a ficha tem uma galeria **própria** para o app do
relógio. Ali as imagens são **capturas diretas**, sem foto de fundo e sem texto
de marketing: o formato é pequeno demais para comportar composição.

| # | Tela | Estado a preparar |
|---|---|---|
| W-1 | W8 Descansando | Contagem em âmbar, número grande, próxima repetição embaixo |
| W-2 | W8 últimos 3 s | Verde, número maior (90 pt) — o estado que o requisito 17.12 protege |
| W-3 | W7 Nadando | `3 de 4`, série, acumulado |
| W-4 | W4 Pré-visualização | Título, distância total e `Raia de 25 m` destacado |
| W-5 | W10 Resumo | Real vs planejado, tempo, séries |

---

## 6. Print da compra dentro do app

**Item separado e obrigatório**, e o mais esquecido: o App Store Connect pede uma
*Review Screenshot* para **cada** compra dentro do app. Sem ela o produto fica em
"Missing Metadata" e a versão não sai da fila, mesmo com tudo o mais pronto.

| Item | Valor |
|---|---|
| Produto | `com.dablab.vounadar.completo` |
| Tipo | Não-consumível |
| Preço | **R$ 49,90** (spec 8.11, confirmado pelo Alexandre em 06/09/2026) |
| Imagem | A tela **P7 Paywall**, com título, corpo, botão de compra mostrando o preço, e "Restaurar compra" |

**É captura crua, não composição.** Este print vai no formulário do produto, na
seção "Review Information" — ele existe para o revisor conferir que a tela de
compra é a que o app mostra, então foto de fundo e texto de marketing atrapalham.

### O arquivo já está gerado

`app-store/in-app/review-screenshot-com.dablab.vounadar.completo.png` —
**1206 × 2622 px**, bem acima do mínimo de 640 × 920 que a App Store exige.
Mostra a tela P7 completa: título, corpo, botão de compra com o preço e
"Restaurar compra", com a barra de status em 9:41.

### ⚠️ Ele precisa ser REGERADO antes de submeter

O preço no print atual sai em **dólar** (`$49.90`), não em real. O motivo:

- o arquivo `.storekit` local é ferramenta de **teste**, e o preço que ele
  mostra depende da vitrine do simulador, que é a americana;
- forçar `"_storefront": "BRA"` no arquivo **quebra**: o produto some, porque a
  configuração local não tem faixa de preço para aquela vitrine, e a tela fica
  sem botão de compra — pior que o dólar.

O valor **49,90 está certo** e vem do arquivo; o que está errado é só o símbolo
da moeda. O print definitivo tem que sair de um build com o **produto real do
App Store Connect**, onde o preço vem da loja e aparece como `R$ 49,90`.

Como regerar, depois de o produto existir no App Store Connect:

```bash
xcrun simctl status_bar "iPhone 17 Pro" override --time "9:41" \
  --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl launch "iPhone 17 Pro" com.dablab.vounadar
# Ajustes › Comprar o Vou Nadar completo
xcrun simctl io "iPhone 17 Pro" screenshot --type=png \
  app-store/in-app/review-screenshot-com.dablab.vounadar.completo.png
```

Conferir antes de subir: o botão diz **`Comprar por R$ 49,90`**, e não `$49.90`
nem `R$ 29,90`.

**Divergência registrada:** as telas exportadas do Claude Design mostram
`Comprar por R$ 29,90`. O valor correto é **R$ 49,90** — preço é regra de negócio
e o spec vence. A tela precisa mostrar 49,90 antes de o print ser tirado.

---

## 7. Textos e links fixos da ficha

Recuperados do código publicado do Swim Builder, onde já estão em produção:

| Campo | Valor |
|---|---|
| Support URL | `https://suportedablab.carrd.co/` |
| Privacy Policy URL | `https://dablab.notion.site/politica-de-privacidade` |

Os dois são também as duas linhas da seção "Sobre" da tela P5 (Ajustes), no
épico 8.11.

**Privacidade da ficha:** "Dados não coletados". Gravar no HealthKit do próprio
usuário não é coleta pelo desenvolvedor — mas o questionário tem que ser revisado
à mão antes de submeter (seção 20 do spec).

**Sobre as fotos:** as quatro são geradas por IA. Use como imagem de apoio e
evite legenda que as apresente como cliente real ou resultado real de usuário.

---

## 8. Ordem de execução

1. Terminar os épicos 8.5 a 8.12 — sem Histórico e sem Favoritos preenchidos não
   há o que capturar para as imagens 5 e 6.
2. Popular o app com dados plausíveis: 4 favoritos com títulos de verdade e 5
   semanas de volume.
3. Fixar a barra de status em 9:41 e capturar os prints de iPhone e de relógio.
4. Compor as sete imagens de 1242 × 2688 com foto, texto e print.
5. Montar a galeria do relógio com as cinco capturas diretas.
6. Capturar o print da compra, cru, com R$ 49,90 na tela.
7. Conferir imagem por imagem que nenhuma mostra R$ 29,90.
8. Confirmar no App Store Connect se ele quer 6,5", 6,9" ou os dois, e
   renderizar as composições no tamanho pedido.
