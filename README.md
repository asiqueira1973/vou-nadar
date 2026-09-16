# Vou Nadar

Treino de natação gerado no aparelho, executado no pulso.

O nadador diz quanto quer nadar, que equipamento tem na mochila e qual é o
tamanho da piscina. O app monta um treino completo — aquecimento, progressão,
parte principal e soltura — **com o descanso de cada bloco já definido**. No
Apple Watch, o treino roda sozinho: conta as voltas pela distância do HealthKit,
avisa por vibração quando entra e quando sai do descanso, e grava a sessão no app
Saúde no fim.

Em português. Sem conta, sem login, sem servidor.

---

## O que o torna diferente

- **Piscina de qualquer tamanho, de 10 a 50 m.** Piscina de condomínio de 16 m é
  caso de primeira classe, não gambiarra: o `4×100` do catálogo vira `4×96` —
  seis voltas —, e é `4×96` que aparece na tela, no relógio e no total.
- **Descanso automático no pulso.** Nenhuma ação obrigatória depende de tocar na
  tela durante o treino. O visor está molhado e a mão, na água.
- **Funciona com o iPhone desligado.** O relógio gera treino sozinho, com o
  catálogo embarcado. Nada no app de treino depende de rede.
- **Catálogo de 226 exercícios vindos de experiência real de nadadores amadores**,
  não gerados por IA.
- **O treino salvo é imutável.** Descanso, distância adaptada e voltas são
  congelados na geração e nunca recalculados na leitura — um favorito não muda
  sozinho depois de uma atualização do app ou de uma troca de piscina.

---

## Estado

v1.0.0 publicado na App Store. Doze épicos implementados e validados critério a
critério, 214 testes em 21 suítes, iOS e watchOS compilando em Release **sem nenhum warning**.

Falta o teste em piscina real — ver a checklist da seção 26 do
`spec-vou-nadar.md`.

---

## Requisitos

- Xcode 26 ou mais recente
- iOS 18.0+ (iPhone, retrato) e watchOS 11.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

**Zero dependências de terceiros.** Não há Swift Package, não há
`Package.resolved`, não há chave de API nem variável de ambiente. Se aparecer
uma, é sinal de que alguém está introduzindo backend contra o anti-escopo.

---

## Rodando

O projeto é **gerado** a partir do `project.yml` — o `.xcodeproj` não é
versionado e não é editado à mão.

```bash
xcodegen generate
open VouNadar.xcodeproj
```

Rode `xcodegen generate` toda vez que adicionar, mover ou apagar um arquivo.

Testes:

```bash
xcodebuild -project VouNadar.xcodeproj -scheme VouNadar -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO test
```

---

## Estrutura

```
VouNadar/                    app do iPhone
  Domain/                    regras puras — gerador, descanso, execução, sync
  Data/                      catálogo, modelos SwiftData, repositórios, HealthKit, StoreKit
  DesignSystem/              tokens, copy, símbolos, componentes
  Features/                  as sete telas
VouNadarWatch/               app do relógio — executa o treino e grava no Saúde
VouNadarWatchComplication/   volume da semana no mostrador
VouNadarTests/               214 testes
```

`Domain/`, `Data/Catalog/`, `Data/Enums/`, `Data/Models/`, `Data/Schema/` e
`Data/Repositories/` são compilados nos **dois** apps e não importam framework de
plataforma — é isso que faz o relógio funcionar sozinho. Há um teste que reprova
o build se alguém quebrar essa regra.

---

## Documentação

| Documento | Para quê |
|---|---|
| [`spec-vou-nadar.md`](spec-vou-nadar.md) | O comportamento: modelo de dados, regras de negócio, fluxos, critérios de aceite, copy |
| [`prompt-design-vou-nadar.md`](prompt-design-vou-nadar.md) | A implementação visual: tokens, tipografia, componentes, símbolos |
| [`DOCUMENTACAO-TECNICA.md`](DOCUMENTACAO-TECNICA.md) | O sistema como ficou, incluindo as divergências em relação ao spec |
| [`CLAUDE.md`](CLAUDE.md) | Como mexer no repositório sem quebrar o que quebra em silêncio |

---

## Privacidade

Nenhum dado sai do aparelho. Não há analytics, não há rastreamento, não há conta.
Os treinos ficam no SwiftData local e as sessões no app Saúde, que é do usuário.
A única comunicação com a rede é comprar e restaurar a compra na App Store.

Apagar o app apaga os treinos. As sessões no app Saúde permanecem — são dado de
saúde do usuário, não nosso.
