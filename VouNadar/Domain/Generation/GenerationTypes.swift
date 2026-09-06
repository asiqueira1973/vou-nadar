import Foundation

/// O que o usuário pediu na Home ou na tela Gerar do relógio (contrato 13.1).
///
/// É a entrada da geração e **não conhece SwiftData**: o repositório traduz
/// `Preferencias` para cá antes de chamar o gerador, e traduz o resultado de
/// volta para `Treino` depois. A fronteira de idioma e a fronteira de
/// persistência são a mesma (spec 7.0 e 18).
struct GenerationRequest: Sendable, Equatable {

    /// `preferencias.distancia_min_m`. Piso da faixa pedida.
    let minMeters: Int

    /// `preferencias.distancia_max_m`. **Pode ser igual ao piso**: faixa fechada
    /// é permitida e suportada (spec 7.7).
    let maxMeters: Int

    /// `equipamento_id` marcados. **Vazio é estado válido e comum** — nadador
    /// sem equipamento nenhum —, e aí só entram exercícios com
    /// `equipamento_exigido = nenhum` (critério 8.4).
    let selectedEquipment: Set<String>

    /// Interruptor de educativos da Home.
    let includeDrills: Bool

    /// Interruptor de pernada da Home.
    let includeKick: Bool

    /// **O comprimento da raia, em metros.** É o parâmetro que o gerador do
    /// Swim Builder não tinha e que muda tudo: ele decide quais exercícios
    /// sobrevivem à guarda de desvio e quantos metros cada repetição tem de
    /// verdade (regra 11.3).
    let laneLengthM: Int

    /// **O ritmo de descanso global.** O outro parâmetro novo: alimenta a tabela
    /// da regra 11.5 e os descansos entre séries e seções da 11.6.
    let restPace: RitmoDescanso

    /// `exercicio_id` do treino que está na tela, para "Gerar outro" não
    /// devolver o mesmo conjunto. `nil` na primeira geração.
    let previousExerciseIds: [String]?

    init(
        minMeters: Int,
        maxMeters: Int,
        selectedEquipment: Set<String> = [],
        includeDrills: Bool = false,
        includeKick: Bool = false,
        laneLengthM: Int,
        restPace: RitmoDescanso = .normal,
        previousExerciseIds: [String]? = nil
    ) {
        self.minMeters = minMeters
        self.maxMeters = maxMeters
        self.selectedEquipment = selectedEquipment
        self.includeDrills = includeDrills
        self.includeKick = includeKick
        self.laneLengthM = laneLengthM
        self.restPace = restPace
        self.previousExerciseIds = previousExerciseIds
    }
}

/// Uma série pronta, com o descanso já carimbado (spec 7.6).
///
/// É o retrato exato do que vai virar uma linha de `serie_treino`, e é montado
/// **na geração** — nunca recalculado na leitura (princípio 0.6). O repositório
/// do épico 8.5 só copia campo a campo.
struct GeneratedSet: Sendable, Equatable {

    /// Referência lógica ao catálogo, sem chave estrangeira (spec 7.6).
    let exercicioId: String

    let repeticoes: Int

    /// **Distância real por repetição, já adaptada à raia** (regra 11.3). É o
    /// que a interface exibe em todo lugar.
    let distanciaM: Int

    /// O que o catálogo pedia, antes da adaptação. Só rastreabilidade — a
    /// interface nunca mostra.
    let distanciaCatalogoM: Int

    /// `repeticoes × distanciaM`, sobre a distância real.
    let metrosTotais: Int

    /// Descanso ENTRE as repetições, em segundos (regra 11.5).
    let descansoSeg: Int

    /// Descanso entre esta série e a próxima da mesma seção (regra 11.6).
    /// **Zero na última série da seção** — ali vale o descanso de seção.
    let descansoPosSerieSeg: Int

    /// Voltas que o relógio conta para saber que a repetição acabou
    /// (regras 11.3 e 11.7).
    let voltasPorRepeticao: Int

    let nomeSnapshot: String
    let descricaoSnapshot: String
    let equipamentoExigido: String
    let modo: ModoExercicio
    let intensidade: Intensidade

    /// Ordem contígua a partir de 1 dentro da seção (spec 7.11).
    let ordem: Int
}

/// Uma das quatro seções de um treino recém-gerado.
///
/// **Existe sempre, mesmo vazia**: treino curto deixa aquecimento, progressão e
/// parte principal sem série nenhuma, e os quatro registros continuam sendo
/// criados (regra 11.1).
struct GeneratedSection: Sendable, Equatable {

    let tipo: TipoSecao

    /// Alvo que o algoritmo tinha para a seção. Vai para
    /// `secao_treino.distancia_alvo_m` e **nunca é recalculado depois**.
    let alvoM: Int

    /// Descanso entre esta seção e a próxima (regra 11.6). **Zero na última.**
    let descansoPosSecaoSeg: Int

    /// As séries sorteadas, na ordem em que foram inseridas.
    let series: [GeneratedSet]

    var metrosTotais: Int { series.reduce(0) { $0 + $1.metrosTotais } }
}

/// O treino que o gerador produziu (contrato 13.1).
///
/// **Não existe caso de falha.** A regra 11.2 é explícita: se o sorteio não
/// fechar dentro da faixa em até 50 tentativas, o gerador aceita o resultado
/// mais próximo — *nunca falha para o usuário*. É por isso que este tipo não tem
/// um par `GenerationError`, ao contrário do gerador do Swim Builder de onde ele
/// veio (spec 4.4 e assunção 24.2).
struct GenerationResult: Sendable, Equatable {

    /// `alvo_total` sorteado no início da montagem.
    let alvoTotalM: Int

    /// **Sempre quatro**, na ordem da regra 11.1.
    let secoes: [GeneratedSection]

    /// Soma real de `metros_totais`, sobre as distâncias **adaptadas à raia**.
    /// A verificação da faixa (regra 11.2) é feita contra este número, nunca
    /// contra a soma das distâncias do catálogo.
    let totalM: Int

    /// A raia para a qual este treino foi montado. Vira
    /// `treino.tamanho_raia_m`, congelado (spec 7.4).
    let laneLengthM: Int

    /// O ritmo com que os descansos foram calculados. Vira
    /// `treino.ritmo_descanso_usado`, congelado (princípio 0.6).
    let restPace: RitmoDescanso

    /// Dados de depuração da geração.
    let trace: GenerationTrace

    /// Todos os `exercicio_id`, na ordem das seções. É o multiconjunto que
    /// "Gerar outro" compara com o treino anterior.
    var allExerciseIds: [String] {
        secoes.flatMap { $0.series.map(\.exercicioId) }
    }

    /// Verdadeiro quando alguma série teve a distância mudada pela adaptação
    /// (regra 11.3). Decide se a nota da copy 15.18 aparece no Detalhe.
    var teveDistanciaAjustada: Bool {
        secoes.contains { $0.series.contains { $0.distanciaM != $0.distanciaCatalogoM } }
    }
}

/// O que aconteceu durante a geração, para depuração.
///
/// É **dado, não efeito colateral**: o gerador é função pura (contrato 13.1) e
/// não escreve log nem toca em `OSLog`. Quem registra é a camada de cima, em
/// `#if DEBUG`. Como efeito colateral bom, isso torna o próprio log testável.
struct GenerationTrace: Sendable, Equatable {

    /// Por que uma seção parou antes de fechar o alvo.
    enum SectionOutcome: String, Sendable {
        /// Fechou o alvo normalmente.
        case reachedTarget
        /// Nenhum candidato coube no que restava.
        case noCandidateLeft
        /// A seção nem chegou a ser tentada, porque o alvo era zero.
        case emptyTarget
    }

    var alvoTotalM = 0
    var alvoAquecimentoM = 0
    var alvoProgressaoM = 0
    var alvoPrincipalM = 0
    var alvoSolturaM = 0

    /// +100 m transferidos da parte principal para o aquecimento quando o
    /// interruptor de educativos está ligado. `alvo_total` não muda — o
    /// educativo não alonga o treino, ele troca uma parte da série principal por
    /// técnica.
    var bonusEducativoM = 0

    var desfechos: [TipoSecao: SectionOutcome] = [:]

    /// A soltura ficou vazia e precisou do resgate de "insere o menor bloco que
    /// couber": sair da água sem soltura é pior que estourar o alvo da seção.
    var usouResgateDaSoltura = false

    /// Quantas tentativas a regra 11.2 consumiu, de 1 a 50.
    var tentativas = 1

    /// Quantas vezes um treino foi descartado por ser idêntico ao anterior.
    var rejeicoesPorIdentidade = 0

    /// **Verdadeiro quando as 50 tentativas se esgotaram sem fechar o mínimo** e
    /// o gerador devolveu o melhor rascunho que conseguiu (regra 11.2).
    ///
    /// Não é erro e não vira mensagem: a decisão do Alexandre para a pergunta Q5
    /// foi **treino menor** em vez de forçar repetição. O campo existe para o
    /// log de depuração dizer que isso aconteceu.
    var aceitouAbaixoDoMinimo = false

    /// Quantos candidatos a combinação de raia, equipamentos e interruptores
    /// deixou (regra 11.19). Abaixo de 30 a interface avisa.
    var candidatosDisponiveis = 0

    var escolhidos: [TipoSecao: [String]] = [:]
}
