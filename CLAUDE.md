# CLAUDE.md — Vou Nadar

Instruções para quem for mexer neste repositório, humano ou agente. Escrito
conforme a seção 18 do `spec-vou-nadar.md`.

Leia o `spec-vou-nadar.md` antes de mudar comportamento e o `prompt-design-vou-nadar.md`
antes de mudar interface. Este arquivo não os substitui — ele diz como o
repositório está montado e o que quebra se você não souber.

---

## Os quatro targets

| Target | Plataforma | O que é |
|---|---|---|
| `VouNadar` | iOS 18.0+ | App do iPhone. iPhone apenas, retrato apenas. **Só lê** do HealthKit |
| `VouNadarWatch` | watchOS 11.0+ | App do relógio. É quem **executa** o treino e **escreve** no HealthKit |
| `VouNadarWatchComplication` | watchOS 11.0+ | Extensão WidgetKit: volume da semana no mostrador |
| `VouNadarTests` | iOS 18.0+ | Testes. Rodam contra o target do iPhone, que hospeda as fontes compartilhadas |

O app do relógio é embarcado no do iPhone; a complication é embarcada no do
relógio.

---

## A regra que mais importa: as fontes compartilhadas

Estas pastas são compiladas nos **dois** targets de app, sem Swift Package no
meio (spec 4.2). São elas que fazem o relógio gerar treino com o iPhone
desligado.

```
VouNadar/Domain/            ← regras puras: gerador, descanso, execução, sync, compra
VouNadar/Data/Catalog/      ← carga e validação do catálogo embarcado
VouNadar/Data/Enums/        ← enums do schema e do catálogo
VouNadar/Data/Models/       ← entidades SwiftData
VouNadar/Data/Schema/       ← VersionedSchema e plano de migração
VouNadar/Data/Repositories/ ← acesso a preferências e treinos
VouNadar/DesignSystem/Symbols.swift  ← registro de SF Symbols (arquivo único)
```

**Nada aqui pode importar `SwiftUI`, `UIKit`, `WatchKit`, `HealthKit`,
`WidgetKit`, `AppKit` nem `WatchConnectivity`.** A única exceção é `SwiftData`,
permitido em `Data/Models/`, `Data/Schema/` e `Data/Repositories/`.

Isso não é convenção: **`SharedSourcePurityTests` lê os arquivos em disco e
reprova o build**. Se você precisa de um framework de plataforma numa regra, o
sinal é que a regra está no lugar errado — mova o código, não o teste.

Onde as coisas de plataforma vivem:

| Precisa de | Vai em |
|---|---|
| HealthKit no iPhone (ler) | `VouNadar/Data/Health/` |
| HealthKit no relógio (escrever) | `VouNadarWatch/Health/` |
| WatchConnectivity | `VouNadar/Connectivity/` e `VouNadarWatch/Connectivity/` |
| StoreKit | `VouNadar/Data/Purchase/` |
| SwiftUI | `Features/`, `App/`, `DesignSystem/` de cada target |

---

## O `.xcodeproj` não é versionado e não é editado à mão

O projeto é **gerado** pelo `project.yml`, que é a fonte de verdade da
configuração de build.

```bash
xcodegen generate
```

**Rode isso toda vez que adicionar, mover ou apagar um arquivo.** É o erro mais
fácil de cometer aqui: criar um arquivo, ver "cannot find type X in scope", e
procurar o problema no código. O arquivo simplesmente não está no projeto ainda.

O `.xcodeproj` está no `.gitignore`. Se você abrir o Xcode e mexer nas
configurações do target, sua mudança some no próximo `xcodegen generate` — mexa
no `project.yml`.

Instalar o XcodeGen: `brew install xcodegen`.

---

## Comandos

```bash
# Gerar o projeto (sempre depois de mexer em arquivos)
xcodegen generate

# Testes — 214 testes, e o portão de qualidade do repositório
xcodebuild -project VouNadar.xcodeproj -scheme VouNadar \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO test

# Build do iPhone (embarca o relógio e a complication)
xcodebuild -project VouNadar.xcodeproj -scheme VouNadar \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Release CODE_SIGNING_ALLOWED=NO build

# Build do relógio isolado
xcodebuild -project VouNadar.xcodeproj -scheme VouNadarWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -configuration Release CODE_SIGNING_ALLOWED=NO build
```

**Build sem nenhum warning é critério de aceite (8.1.4), não preferência.**
`SWIFT_TREAT_WARNINGS_AS_ERRORS` está ligado nos três targets de app. Há uma
exceção declarada e estreita: `GCC_TREAT_WARNINGS_AS_ERRORS` está desligado em
`VouNadarTests`, porque o header do `StoreKitTest` da Apple usa um símbolo
deprecado no iOS 18. Nenhum warning **nosso** é tolerado em lugar nenhum.

Pré-requisitos do ambiente, se a máquina for nova:

```bash
brew install xcodegen
xcodebuild -downloadPlatform watchOS          # ~3,8 GB
xcrun simctl create "iPhone 17 Pro" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-1
```

---

## Seis coisas que quebram em silêncio

Cada uma destas já mordeu durante a implementação. Nenhuma dá erro de compilação.

1. **Nome de SF Symbol errado não quebra o build** — vira um quadrado vazio em
   produção. Todo nome vive em `DesignSystem/Symbols.swift`, e `SymbolsTests`
   resolve cada um de verdade. Não escreva `Image(systemName: "algo")` numa View.

2. **`@Attribute(originalName:)` não gera coluna `snake_case`.** Ele declara o
   nome *anterior* de uma propriedade, para migração. As colunas saem
   `ZDISTANCIATOTALM`. Ver a divergência declarada em
   `Data/Schema/VouNadarSchema.swift`.

3. **A relação do SwiftData não tem ordem garantida.** Sempre leia por
   `secoesOrdenadas` e `seriesOrdenadas`, nunca por `secoes`/`series` cru — ler
   fora de ordem faz o nadador executar o treino trocado.

4. **`WCSession.delegate` é referência fraca**, e o `WCSession` processa a fila
   assim que ativa. Ativar numa `.task` de View perde entrega, e prender o
   serviço a um `@State` mata a recepção quando a View sai de cena. Por isso os
   dois serviços de sincronização são singletons ativados cedo.

5. **`activationState == .activated` não basta** para enviar ao relógio. São
   três condições: ativado, `isPaired` e `isWatchAppInstalled`. Sem as três o app
   tenta enviar para ninguém a cada gravação do banco.

6. **Nunca recalcule descanso, distância adaptada ou voltas na leitura.** Eles
   são snapshot congelado na geração (princípio 0.6). Recalcular faz o favorito
   mudar sozinho depois de uma atualização do app ou de uma troca de piscina.

---

## Comentários

Toda função, view, view model, repositório e rotina de sincronização leva
cabeçalho em **português** dizendo o que faz, o que recebe, o que devolve e
**qual regra do spec implementa, com o número**.

```swift
// Encerra a repetição quando as voltas previstas são atingidas (regra 11.7)
```

Comentário que repete a sintaxe é ruído. O que nomeia a regra é o que salva o
projeto daqui a seis meses — e é o que permite a alguém decidir se uma mudança
contradiz o produto ou só o código.

**Idioma:** banco e enums em português; código, variáveis, funções e nomes de
arquivo em inglês; interface e comentários em português. Zero string literal em
`View` — a copy vive em `DesignSystem/Copy.swift` (iPhone),
`VouNadarWatch/Features/WatchCopy.swift` (relógio) e `ComplicationCopy`.

---

## Documentação no mesmo commit

`CLAUDE.md`, `DOCUMENTACAO-TECNICA.md` e `README.md` acompanham a mudança que os
afeta. Um documento que descreve o que o código **já não faz** é pior que
documento nenhum: ele é acreditado.

Se você mudar uma regra de negócio, atualize também a seção de **divergências**
do `DOCUMENTACAO-TECNICA.md` — é lá que ficam as decisões em que o código se
afasta do spec, e por quê.

---

## O que NÃO implementar

Está no roadmap (spec 28) e ficou de fora do v1 de propósito. Nem "só a
estrutura", nem "deixando preparado", nem um campo "para depois":

intervalo de saída · pace base e tempo estimado · edição de descanso bloco a
bloco · edição de treino · outros nados · águas abertas · CloudKit · sync
Watch→iPhone · widget de Smart Stack · compartilhamento em imagem · tela de conta
ou login · gráfico de pace · jardas · iPad · inglês.

Se algo do roadmap parecer necessário para o v1 funcionar, isso é uma pergunta
para o Alexandre, não uma decisão de implementação.
