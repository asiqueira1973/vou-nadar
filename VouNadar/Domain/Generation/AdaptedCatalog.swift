import Foundation

/// Um exercício do catálogo já adaptado a uma piscina específica (regra 11.3).
///
/// Guarda lado a lado o que o catálogo pedia e o que o nadador vai de fato
/// nadar. **Todo cálculo de orçamento do gerador usa `metrosTotais`, que é o
/// número adaptado** — é essa troca que faz a regra 11.2 (total dentro da faixa)
/// ser verificada sobre a distância real sem uma linha a mais no laço de
/// sorteio.
struct AdaptedExercise: Sendable, Equatable {

    /// O registro original, intocado.
    let exercicio: ExercicioCatalogo

    /// Voltas por repetição nesta piscina (regra 11.3). Congelado na série.
    let voltasPorRepeticao: Int

    /// Distância real por repetição: `voltasPorRepeticao × raia`.
    let distanciaM: Int

    /// `repeticoes × distanciaM`. **É o que o gerador soma**, nunca
    /// `exercicio.metros_totais`.
    let metrosTotais: Int

    var exercicioId: String { exercicio.exercicio_id }

    /// A distância **do catálogo** por repetição.
    ///
    /// Alguns filtros de composição têm que usar este número, e não o adaptado —
    /// ver `AdaptedCatalog.progressao`.
    var distanciaCatalogoM: Int { exercicio.distancia_m }

    /// Monta a versão adaptada de um exercício para uma raia (regra 11.3).
    init(_ exercicio: ExercicioCatalogo, tamanhoRaiaM: Int) {
        self.exercicio = exercicio
        self.voltasPorRepeticao = LaneAdapter.voltasPorRepeticao(
            distanciaCatalogoM: exercicio.distancia_m, tamanhoRaiaM: tamanhoRaiaM)
        self.distanciaM = voltasPorRepeticao * tamanhoRaiaM
        self.metrosTotais = exercicio.repeticoes * distanciaM
    }
}

/// O catálogo inteiro adaptado a uma piscina, com os pools de sorteio prontos.
///
/// **É aqui que a regra 11.3 acontece, uma vez por geração.** Depois disto o
/// motor de composição não sabe que piscina existe: ele só soma `metrosTotais`,
/// e esses metros já são os reais.
///
/// Essa foi a decisão de arquitetura que permitiu **copiar e adaptar** o
/// `WorkoutGenerator` do Swim Builder (spec 4.4, assunção 24.2) em vez de
/// reescrevê-lo. O algoritmo de lá decide tudo por `metros_totais`; trocando a
/// fonte desse número por um catálogo já adaptado, a heurística de composição —
/// reservas, divisão 20/80, bônus de educativo, anti-dois-longos, primeira série
/// com equipamento, complemento — sobrevive intacta.
///
/// A guarda de desvio de 25% (assunção 24.3b) é aplicada **na construção**: um
/// exercício que a adaptação distorceria demais simplesmente não entra em pool
/// nenhum naquela piscina.
struct AdaptedCatalog: Sendable {

    /// A raia para a qual este catálogo foi adaptado.
    let tamanhoRaiaM: Int

    /// Todos os ativos que sobreviveram à guarda de desvio, adaptados.
    let utilizaveis: [AdaptedExercise]

    // MARK: - Os pools de composição
    //
    // Herdados do Swim Builder (spec 4.4). O spec do Vou Nadar **não numera** a
    // composição interna das seções — ele exige o resultado (regra 11.1: quatro
    // seções sempre; regra 11.2: total dentro da faixa). Os filtros abaixo são
    // conhecimento de produto validado no app irmão, e estão aqui em vez de
    // espalhados pelo motor para o teste poder contá-los.

    /// Aquecimento: intensidade `aquecimento`, sem educativo (que tem passagem
    /// própria) e sem pernada (que só entra na parte principal).
    let aquecimento: [AdaptedExercise]

    /// Educativos, só para a primeira escolha do aquecimento, e só com o
    /// interruptor ligado.
    let educativos: [AdaptedExercise]

    /// Soltura: intensidade `soltura` e **obrigatoriamente sem equipamento**.
    /// Soltura nunca usa equipamento, e é por isso que ela é a reserva garantida
    /// do treino.
    let soltura: [AdaptedExercise]

    /// Progressão: os quatro controles aceitos, as três intensidades do miolo,
    /// modo `nado` ou `bracada`, e **distância de catálogo** de exatamente 50 ou
    /// 100 m.
    ///
    /// **Este é o único filtro que usa `distancia_catalogo_m` e não a adaptada,
    /// e é de propósito.** "Ser um conjunto de tiros de 50" é propriedade
    /// estrutural do exercício, não da piscina: numa raia de 16 m o bloco de 50
    /// vira 48 m, e comparar 48 com 50 esvaziaria a progressão inteira em toda
    /// piscina de tamanho incomum.
    let progressao: [AdaptedExercise]

    /// Parte principal: `constante` ou `continuo`, as quatro intensidades de
    /// trabalho, modo `nado` ou `bracada`.
    let principal: [AdaptedExercise]

    /// Pernada, só na parte principal e só com o interruptor ligado.
    let pernada: [AdaptedExercise]

    /// Complemento: como a parte principal, mais os três controles de
    /// progressão — aqui o objetivo é fechar a lacuna com o bloco de tamanho
    /// mais próximo, não variar.
    let complemento: [AdaptedExercise]

    /// Adapta o catálogo inteiro a uma piscina (regra 11.3).
    ///
    /// Recebe: os exercícios do catálogo e o comprimento da raia.
    /// Devolve: os sete pools prontos, já sem os exercícios que a guarda de
    /// desvio removeu.
    ///
    /// Custo: uma passada sobre os 226 por geração. O orçamento da regra 11.2 é
    /// de 1 segundo para o treino inteiro, e isto custa microssegundos.
    init(catalogo: [ExercicioCatalogo], tamanhoRaiaM: Int) {
        self.tamanhoRaiaM = tamanhoRaiaM

        // A guarda de desvio de 25% e o filtro de `ativo` acontecem aqui, uma
        // vez: nenhum pool abaixo precisa repeti-los.
        let adaptados =
            catalogo
            .filter { $0.ativo && LaneAdapter.podeSerSorteado($0, tamanhoRaiaM: tamanhoRaiaM) }
            .map { AdaptedExercise($0, tamanhoRaiaM: tamanhoRaiaM) }
        self.utilizaveis = adaptados

        self.aquecimento = adaptados.filter {
            $0.exercicio.intensidade == .aquecimento
                && $0.exercicio.modo != .educativo
                && $0.exercicio.modo != .pernada
        }

        self.educativos = adaptados.filter { $0.exercicio.modo == .educativo }

        self.soltura = adaptados.filter {
            $0.exercicio.intensidade == .soltura && $0.exercicio.equipamento_exigido == "nenhum"
        }

        self.progressao = adaptados.filter {
            [.progressivo, .crescente, .split_negativo, .constante]
                .contains($0.exercicio.tipo_controle)
                && [.variavel, .aerobico, .moderado].contains($0.exercicio.intensidade)
                && [.nado, .bracada].contains($0.exercicio.modo)
                // Distância DO CATÁLOGO — ver a documentação de `progressao`.
                && ($0.distanciaCatalogoM == 50 || $0.distanciaCatalogoM == 100)
        }

        self.principal = adaptados.filter {
            [.constante, .continuo].contains($0.exercicio.tipo_controle)
                && [.moderado, .aerobico, .resistencia, .variavel]
                    .contains($0.exercicio.intensidade)
                && [.nado, .bracada].contains($0.exercicio.modo)
        }

        self.pernada = adaptados.filter { $0.exercicio.modo == .pernada }

        self.complemento = adaptados.filter {
            [.constante, .continuo, .progressivo, .crescente, .split_negativo]
                .contains($0.exercicio.tipo_controle)
                && [.moderado, .aerobico, .resistencia, .variavel]
                    .contains($0.exercicio.intensidade)
                && [.nado, .bracada].contains($0.exercicio.modo)
        }

        // Nenhum pool inclui `intervalo_fixo`: os dois exercícios com esse
        // controle são inalcançáveis pela geração enquanto não existir intervalo
        // de saída, que é v2 (roadmap 28.1).
    }
}
