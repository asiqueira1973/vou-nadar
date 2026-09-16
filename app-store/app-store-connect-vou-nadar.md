# App Store Connect — Vou Nadar

Pacote pronto para colar. Gerado a partir do `spec-vou-nadar.md` e do código como
ele ficou. Todos os campos de texto foram medidos com o script de limites — o
resultado está no fim do documento.

As imagens da galeria são assunto do [`ROTEIRO-PRINTS.md`](ROTEIRO-PRINTS.md).
Aqui é tudo o que é texto e formulário.

**Identificadores reais deste app** (conferidos no `VouNadar.xcconfig`, no
`project.yml` e nos entitlements, não presumidos):

| | |
|---|---|
| Bundle ID do app | `com.dablab.vounadar` |
| Bundle ID do app do Apple Watch | `com.dablab.vounadar.watchkitapp` |
| Bundle ID da complication | `com.dablab.vounadar.watchkitapp.widgets` |
| Produto de compra no app | `com.dablab.vounadar.completo` |
| Team ID | `XGZW6Y6K25` |
| Versão / build | 1.1.0 (2) |
| Deployment target | iOS 18.0 (iPhone apenas, retrato) · watchOS 11.0 |

> **Cuidado com o `.completo`:** ele é o **identificador do produto de compra**,
> não um Bundle ID. Quem registra `com.dablab.vounadar.completo` como App ID no
> portal perde o identificador e depois não consegue usá-lo na compra. Os App IDs
> são os três de cima.

> **Um registro só na loja.** O app do Apple Watch e a complication vão
> **embarcados** no app do iPhone. Você cria **um** app no App Store Connect, na
> plataforma iOS. Não existe registro separado para watchOS.

---

## 0. developer.apple.com — o que conferir antes

Como a assinatura é automática e o app já roda no aparelho, o Xcode **já criou**
quase tudo. Aqui você confere, não cria.

**Certificates, Identifiers & Profiles → Identifiers → App IDs**

1. `com.dablab.vounadar` deve existir, do tipo App (explícito).
   Capability marcada: **HealthKit**. Só ela.
2. `com.dablab.vounadar.watchkitapp` deve existir, também com **HealthKit**.
3. `com.dablab.vounadar.watchkitapp.widgets` deve existir, também com
   **HealthKit** — a complication lê o volume da semana direto do HealthKit,
   porque é outro processo e não compartilha o banco do app.

Os três precisam de HealthKit. É o erro de assinatura mais provável aqui: ligar
só no app do iPhone e o build do relógio falhar sem dizer o motivo com clareza.

**O que NÃO precisa ser ligado** (marcar por precaução custa caro depois, porque
cada capability extra vira um entitlement que a App Review pode questionar):

- **App Groups** — não existem. O relógio tem o próprio banco, e a complication
  lê do HealthKit justamente para não precisar de App Group.
- **Push Notifications** — o app não manda notificação nenhuma. O que avisa
  debaixo d'água é háptico, não notificação.
- **iCloud / CloudKit** — está no roadmap (spec 28), fora do v1.
- **Sign in with Apple, Associated Domains, SiriKit** — nada disso existe.
- **Background Modes** — o `workout-processing` do relógio é declarado no
  `Info.plist` e vem coberto pelo HealthKit; não há capability separada a ligar.
- **In-App Purchase** não aparece como capability: já vem habilitada em todo
  App ID.

**Membership**

4. Confirme que o Apple Developer Program está ativo e sem contrato pendente.
   Contrato vencido bloqueia o envio do build sem explicar direito.

---

## 0.1 App Store Connect → Business — faça isso primeiro

**Este é o item de maior prazo do roteiro inteiro e o único que não depende de
você.** Sem o contrato de apps pagos ativo, o produto de compra não pode ser
enviado para revisão, e você só descobre isso no fim.

Em **Business** (ou Agreements, Tax and Banking):

1. Aceite o **Paid Applications Agreement**.
2. Preencha as informações **fiscais** (Brasil e Estados Unidos — o formulário
   americano é obrigatório mesmo vendendo só no Brasil).
3. Cadastre a conta **bancária** que recebe.

Se você já publicou o Bilhete ou o Swim Builder por esta mesma conta, isso já
está ativo e você pode seguir direto. Se não, comece por aqui e faça o resto
enquanto processa.

---

## 1. App Information

| Campo | Valor |
|---|---|
| **Nome** | `Vou Nadar` |
| **Subtítulo** | `Treino de piscina no seu pulso` |
| **Idioma principal** | Português (Brasil) |
| **Bundle ID** | `com.dablab.vounadar` |
| **SKU** | `vounadar-ios-001` |
| **Categoria primária** | Health & Fitness |
| **Categoria secundária** | Sports |
| **Copyright** | `© 2026 Alexandre Siqueira` |
| **User Access** | Full Access |

**Sobre o nome:** "Vou Nadar" é expressão comum e pode estar tomada na App Store
brasileira. O nome é reservado no momento em que você cria o registro — então
**faça isso cedo**, antes de investir em qualquer outra coisa. Se estiver
indisponível, a alternativa que preserva a busca é `Vou Nadar: Treino de Piscina`
(28 caracteres), mantendo `Vou Nadar` no começo e o mesmo subtítulo.

**Sobre o subtítulo:** usa os 30 caracteres inteiros e carrega "treino" e
"piscina", que o nome não tem. Os dois campos somados são o que a busca da Apple
indexa com mais peso.

---

## 2. Version Information (versão 1.1.0)

### Texto promocional (159/170)

Único campo que pode ser trocado **sem enviar build novo**.

```
Nada em piscina de 16 m do prédio? O treino se adapta a voltas inteiras. E no Apple Watch ele roda sozinho: conta as voltas e avisa a hora de sair do descanso.
```

### Descrição (2.403/4.000)

```
O Vou Nadar monta o seu treino de piscina e o executa no seu pulso.

Você diz quanto quer nadar, o que levou na mochila e qual é o tamanho da piscina. O app devolve um treino completo — aquecimento, progressão, parte principal e soltura — com o descanso de cada bloco já definido. Sem planilha, sem calcular nada na borda.

FUNCIONA NA PISCINA DO SEU PRÉDIO

Piscina de 12, 15, 16, 18 ou 20 metros não é problema: é caso previsto. O app adapta cada exercício ao número de voltas inteiras mais próximo, e o 4×100 do catálogo vira 4×96 na sua raia de 16 m. É esse número que aparece na tela, no relógio e no total do treino. De 10 a 50 metros.

O TREINO NO PULSO, PARA QUEM TEM APPLE WATCH

Toque em Iniciar e guarde o iPhone. O relógio conta as voltas e os metros pela distância medida, avisa por vibração quando o descanso começa, avisa de novo quando faltam três segundos, e mostra a próxima série sozinho. Você não precisa tocar em nada com a mão molhada — e não precisa mesmo: o treino inteiro roda sem toque.

No fim, a sessão vai para o app Saúde como um treino de natação, com distância, duração e tempo.

EM PORTUGUÊS, DE VERDADE

Não é tradução. Cada tela, cada aviso e cada nome de exercício foi escrito em português, para quem nada no Brasil.

DO SEU JEITO

Marque o que você tem na mochila — pull buoy, palmar, prancha, nadadeira, snorkel — e o treino só usa o que você tem. Ligue educativos se quiser técnica, ligue pernada se quiser perna. Escolha se o descanso é curto, normal ou longo.

TREINOS DE GENTE QUE NADA

O catálogo tem 226 exercícios montados a partir da experiência de atletas amadores, não gerados por inteligência artificial. O que o app faz é combiná-los respeitando a estrutura de um treino de verdade.

FAVORITE E ESQUEÇA

Gostou de um treino? Dê um nome e ele fica salvo. Favorito salvo no iPhone aparece no relógio sozinho, e o relógio ainda gera treino novo com o iPhone desligado no armário do vestiário.

SEM CONTA, SEM SERVIDOR

Não tem login, não tem cadastro, não tem anúncio e não tem rastreamento. Seus treinos ficam no seu aparelho e suas sessões, no app Saúde — que é seu.

COMPRA ÚNICA

Gerar treino é sempre livre. As três primeiras execuções guiadas no relógio também. Depois disso, uma compra única destrava o app para sempre. Sem assinatura.

Requer iPhone com iOS 18 ou mais recente. O treino guiado precisa de Apple Watch com watchOS 11 ou mais recente.
```

### Keywords (99/100 bytes)

```
natacao,piscina,raia,crawl,bracada,pernada,educativo,masters,volume,metros,descanso,serie,swim,agua
```

Sem acento **de propósito**: o campo é limitado em **bytes**, e cada letra
acentuada custa dois. A busca da Apple normaliza acentuação, então "natacao"
também casa com quem digita "natação". Nenhuma palavra do Nome ou do Subtítulo
aparece aqui — "nadar", "treino" e "pulso" já contam para a indexação e
repeti-las desperdiçaria bytes.

### Novidades desta versão

```
Agora, em piscina menor que 25 metros, cada série mostra quantas travessias tem a repetição.

Numa raia de 18 m, um 4×54 aparece como "3 piscinas" e um 2×252 como "7 chegadas". Chegada é ida e volta; quando as travessias não fecham em pares, a conta sai em piscinas.

É o número que ninguém quer calcular de cabeça na borda.
```

Em raia de 25 ou 50 m a linha não aparece, e por isso a primeira frase diz o
limite: sem ela, quem nada em piscina padrão procura um recurso que não existe
para ele e abre chamado no suporte.

### Capturas de tela

**iPhone 6,5" (1242 × 2688)** — as sete peças montadas conforme o
[`ROTEIRO-PRINTS.md`](ROTEIRO-PRINTS.md), seção 3. A App Store deriva os tamanhos
menores a partir dessas, como no Bilhete e no Swim Builder.

**Apple Watch** — as cinco capturas diretas da seção 5 do roteiro. O slot é
separado no App Store Connect e só aparece porque o app embarca um app de
watchOS. Vale preencher: é o diferencial nº 2 do produto, e quem procura app de
natação com relógio olha essa galeria.

---

## 3. App Privacy

**Resposta: "Data Not Collected" — nenhum dado é coletado.**

Isto não é simplificação. O app não tem servidor, não tem conta, não faz nenhuma
chamada de rede própria e não embute nenhum SDK de terceiro — os únicos
frameworks importados são da Apple (SwiftUI, SwiftData, HealthKit, WatchConnectivity,
StoreKit, WidgetKit). A seção 20 do spec é explícita.

No questionário, responda **"No"** para a primeira pergunta ("Do you or your
third-party partners collect data from this app?") e o formulário encerra.

**O detalhe que gera dúvida neste app, e a resposta:** o Vou Nadar grava dado de
saúde — distância, duração, frequência cardíaca. Mas ele grava **no HealthKit do
próprio usuário**, que é da Apple e do usuário, não seu. O dado nunca passa por
você, não existe cópia em servidor nenhum, e você não tem como acessá-lo. Isso
**não é coleta pelo desenvolvedor**, e a resposta continua sendo "Data Not
Collected". A Apple é explícita sobre isso na própria documentação do formulário.

A compra passa pelo StoreKit, mas quem coleta esse dado é a Apple na relação dela
com o usuário — também não muda a resposta.

**[conferir]** Revise o questionário à mão antes de submeter, como manda a
seção 20 do spec e o Definition of Done.

---

## 4. URLs obrigatórias

| Campo | Valor |
|---|---|
| **Support URL** | `https://suportedablab.carrd.co/` |
| **Marketing URL** | deixar vazio |
| **Privacy Policy URL** | o documento Notion "Política de Privacidade — Aplicativos da Dab Lab" |

Os dois links já estão dentro do app, na seção "Sobre" dos Ajustes (tela P5) — o
link que a Apple vê e o que o usuário toca são o mesmo. A política de privacidade
é **obrigatória** para qualquer app que use HealthKit, e a Apple abre os dois na
revisão.

### Seção nova a acrescentar no documento de privacidade

O texto padrão da Dab Lab fala de Firebase, Crashlytics, Analytics e permissões
de câmera e galeria. **Nada disso existe no Vou Nadar**, e deixar o texto
genérico valendo criaria contradição direta com o "Data Not Collected" da seção
anterior. Acrescente esta seção, na mesma numeração do documento:

> ## Vou Nadar
>
> **1. Coleta de Dados**
> O Vou Nadar não coleta nenhum dado. Não há cadastro, login, conta nem
> identificador de usuário de qualquer tipo. O aplicativo não utiliza Firebase,
> Google Analytics, Crashlytics ou qualquer ferramenta de análise ou de registro
> de falhas de terceiros. Não existe servidor: o aplicativo não faz nenhuma
> chamada de rede própria.
>
> **2. Dados de saúde**
> O aplicativo lê e grava dados no app Saúde do seu iPhone e do seu Apple Watch,
> mediante autorização que você concede na tela do próprio sistema e pode revogar
> quando quiser. São eles: distância nadada, duração da sessão e frequência
> cardíaca durante o treino. O aplicativo do Apple Watch grava a sua sessão de
> natação como um treino no app Saúde; o aplicativo do iPhone apenas lê, para
> montar a tela de Histórico.
>
> Esses dados ficam no banco do app Saúde, que é da Apple e seu. Eles **não são
> enviados para lugar nenhum**, não são compartilhados, não são usados para
> publicidade e a Dab Lab não tem acesso a eles — não porque prometemos não
> olhar, mas porque não existe cópia em lugar nenhum para ser olhada.
>
> **3. Armazenamento e Segurança**
> Os treinos que você gera e favorita ficam armazenados **apenas no aparelho**,
> em uma área privada do aplicativo protegida pelo sistema operacional. Não
> existe cópia em nuvem e não há sincronização com outros aparelhos além do envio
> direto do iPhone para o seu Apple Watch, que acontece localmente, entre os dois
> aparelhos, sem passar por nenhum servidor.
>
> Ao desinstalar o aplicativo, os treinos são apagados junto. As sessões
> registradas no app Saúde **permanecem**: são dado de saúde seu, não do
> aplicativo, e cabe a você apagá-las pelo app Saúde se quiser.
>
> **4. Compartilhamento com Terceiros**
> Nenhum dado é compartilhado com terceiros, porque nenhum dado sai do aparelho.
> A única transação com um serviço externo é a compra opcional do Vou Nadar
> completo, processada inteiramente pela Apple através da App Store — a Dab Lab
> não recebe nem armazena dados de pagamento.
>
> **Permissões solicitadas**
> O Vou Nadar pede autorização para acessar o app **Saúde**, pelo motivo descrito
> no item 2. O aplicativo **não** utiliza câmera, galeria de fotos, microfone,
> localização, contatos, calendário, Bluetooth nem notificações.
>
> **5. Contato**
> alexandre@dablab.com.br

---

## 5. Pricing and Availability

| Campo | Valor |
|---|---|
| **Preço do app** | Grátis (Tier 0) |
| **Disponibilidade** | All Countries or Regions |

### Compra no app

| Campo | Valor |
|---|---|
| **Tipo** | Non-Consumable |
| **Product ID** | `com.dablab.vounadar.completo` |
| **Reference Name** | `Vou Nadar completo` |
| **Preço** | R$ 49,90 |
| **Family Sharing** | desligado |

**Display Name (pt-BR):** `Vou Nadar completo`
**Descrição (pt-BR):**
```
Treino guiado sem limite no Apple Watch.
```

O campo de descrição da compra é curto — **45 caracteres** — e é exibido na
própria App Store, na lista de compras do app. Não cabe argumento de venda; o
argumento fica no paywall, que é texto do app. **[conferir]** o limite ao colar:
se o App Store Connect aceitar mais, a versão longa é *"Treino guiado no Apple
Watch sem limite de execuções. Compra única, sem assinatura."*

O Product ID está escrito em `PurchaseGate.identificadorDoProduto` e no
`VouNadar.storekit`, e há um teste que reprova o build se os três divergirem.
**Não mude o ID aqui sem mudar lá.**

**Screenshot de revisão:** a tela P7 (paywall), em **PNG RGB sem canal alfa**,
1242 × 2688. O canal alfa é o que faz o App Store Connect recusar sem dizer o
motivo — toda captura de simulador sai em RGBA. Ver a seção 6 do
[`ROTEIRO-PRINTS.md`](ROTEIRO-PRINTS.md).

**Review notes do produto:**
```
O paywall abre por Ajustes > Comprar o Vou Nadar completo, ou automaticamente ao tentar iniciar a quarta execução guiada no Apple Watch. Gerar treino é gratuito e ilimitado, no iPhone e no relógio, e nunca passa pelo paywall. As três primeiras execuções guiadas também são gratuitas. O preço exibido vem sempre do StoreKit, nunca fixo no código. "Restaurar compra" está no paywall e em Ajustes.
```

O produto e a versão 1.0.0 precisam ser enviados **juntos** para revisão na
primeira submissão. Se você enviar o app sem o produto, ele é aprovado sem a
compra e o paywall fica quebrado em produção.

---

## 6. App Review Information

| Campo | Valor |
|---|---|
| **Sign-in required** | **Não** — o app não tem conta, login nem cadastro |
| **Contato** | Alexandre / Siqueira · alexandre@dablab.com.br |
| **Demo account** | não se aplica |

### Notes (2.115/4.000)

O revisor **não vai entrar numa piscina**, e o treino guiado depende de HealthKit
num Apple Watch. Diga isso você, antes de ele descobrir — é o que separa aprovar
em dois dias de levar rejeição por "não conseguimos testar".

```
O Vou Nadar gera treinos de natação no iPhone e os executa no Apple Watch. Não há conta, login nem cadastro — não existe credencial de teste a fornecer.

COMO TESTAR SEM PISCINA
O app do iPhone funciona sozinho e concentra a maior parte da funcionalidade:
1. Na primeira abertura, escolha o tamanho da piscina (toque em "25 m").
2. Na aba Treino, ajuste a faixa de distância e toque em "Gerar treino".
3. O treino aparece com as quatro seções e o descanso de cada série.
4. "Copiar como texto" copia o treino formatado para a área de transferência.
5. "Favoritar" salva o treino, que passa a aparecer na aba Favoritos.
6. Em Ajustes > Piscina > Outro, escolha 16 m e gere de novo: as distâncias mudam para múltiplos de 16 (um 4x100 vira 4x96). É o principal diferencial do app.

O treino guiado roda no Apple Watch e usa HKWorkoutSession para medir a distância nadada. Fora da água ele inicia normalmente, mas a distância não avança — é o comportamento esperado, porque não há braçada a medir. A tela de descanso, a contagem regressiva e os avisos hápticos podem ser vistos usando o botão "Pular" na tela desbloqueada.

HEALTHKIT
- O app do iPhone SOMENTE LÊ do HealthKit, para montar a aba Histórico.
- O app do Apple Watch lê e escreve: grava a sessão como um treino de natação (HKWorkout) ao final, com distância, duração e tamanho da raia.
- A complication do mostrador lê apenas a distância nadada na semana.
- Nenhum dado de saúde sai do aparelho. Não há servidor, conta, login, anúncio, analytics nem SDK de terceiro.

COMPRA NO APP
Compra única, não-consumível (com.dablab.vounadar.completo). Gerar treino é gratuito e ilimitado, e nunca passa pelo paywall. As três primeiras execuções guiadas no Apple Watch também são gratuitas; a partir da quarta aparece a tela de compra. "Restaurar compra" está no paywall e em Ajustes.

PERMISSÕES
Apenas o app Saúde, pelos motivos acima. O app não usa câmera, galeria, microfone, localização, contatos, calendário, Bluetooth nem notificações.

Idioma: português do Brasil, único idioma do app.
Suporte: https://suportedablab.carrd.co/
Contato: alexandre@dablab.com.br
```

---

## 7. App Encryption Documentation

**Resposta: "None of the algorithms mentioned above".**

O app não implementa criptografia nenhuma e não faz sequer chamada de rede
própria. A única comunicação externa é o StoreKit, framework da Apple.

Isto **já está declarado no binário**: `ITSAppUsesNonExemptEncryption` está como
`false` em `VouNadar/Supporting/Info.plist`. Por causa disso o build não deve
aparecer com "Missing Compliance" no App Store Connect. Se aparecer mesmo assim,
responda pelo formulário com a mesma resposta acima.

---

## 8. Content Rights

**Resposta: "No, it does not contain, show, or access third-party content".**

O catálogo de 226 exercícios é conteúdo próprio, montado a partir de experiência
de atletas amadores. Os ícones são SF Symbols da Apple. Não há conteúdo
licenciado embutido no app.

**As fotos de apoio da galeria da loja são geradas por IA**, mas elas são
material de marketing e não estão dentro do app — não entram nesta resposta.
Como diz a seção 2 do roteiro, evite legenda que as apresente como cliente real
ou resultado real de usuário.

---

## 9. Classificação etária (expectativa: 4+)

Não há conteúdo gerado por usuário visível a terceiros, rede social, chat,
mensagens, IA generativa, compras de terceiros, apostas, álcool, violência nem
navegador embutido.

No questionário, responda "Nenhum" para todas as categorias de conteúdo. Três
perguntas que costumam confundir:

- **"O app tem conteúdo gerado por usuários?"** — Não. O único texto que a pessoa
  digita é o nome que ela dá a um treino favorito, no próprio aparelho, visível
  só para ela.
- **"O app tem acesso irrestrito à web?"** — Não. Os únicos links saem para a
  página de suporte, a política de privacidade e os Ajustes do iOS, todos no
  navegador do sistema.
- **"O app apresenta informação médica ou de tratamento?"** — Não, e este é o
  único item onde um app de saúde e fitness pode escorregar sem motivo. O Vou
  Nadar monta treino de natação para nadador saudável: não dá diagnóstico, não
  prescreve tratamento e não interpreta dado clínico. **[conferir]** Leia o
  enunciado exato antes de responder.

Resultado esperado: **4+**.

---

## 10. Build e envio

1. Confirme `MARKETING_VERSION = 1.1.0` e `CURRENT_PROJECT_VERSION = 2` no
   `VouNadar.xcconfig` (já estão). **O build tem que ser maior que o da versão
   já publicada**, ou o upload é recusado.
2. `xcodegen generate`, para o projeto refletir o `project.yml`.
3. No Xcode: destino **Any iOS Device (arm64)** → Product → Archive. O app do
   relógio e a complication vão embarcados; **não** existe archive separado.
4. No Organizer: Distribute App → App Store Connect → Upload.
5. O build leva de minutos a cerca de uma hora para aparecer processado.
6. Anexe o build à versão 1.0.0, **anexe o produto de compra**, escreva as notas
   de revisão (seção 6) e envie.

**A compilação precisa ser com Xcode 26 e SDK do iOS 26** — exigência da Apple
para submissão desde 28/04/2026.

**Antes de qualquer submissão: teste em piscina real.** Três sessões, conforme o
Definition of Done — uma de 25 m, uma em piscina de tamanho incomum e uma
encerrada antes do planejado. O app grava dado de saúde, e piscina mal
configurada grava dado **errado**; é o risco R1 do spec, e é o único item do
roteiro que não dá para adiantar.

---

## Verificação de limites

Medido com `check_limits.py`, não estimado:

```
Nome: 9/30 chars [OK]
Subtítulo: 30/30 chars [OK]
Texto promocional: 159/170 chars [OK]
Descrição: 2403/4000 chars [OK]
Keywords: 99/100 bytes [OK]
Novidades desta versão: 29/4000 chars [OK]
IAP display name: 18/30 chars [OK]
IAP descrição: 40/45 chars [OK]
Notas de revisão (IAP): 394/4000 chars [OK]
Notas de revisão (app): 2115/4000 chars [OK]
```
