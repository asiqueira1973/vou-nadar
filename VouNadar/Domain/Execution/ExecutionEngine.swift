import Foundation

/// A máquina de estados da execução guiada (épico 8.8, máquina 12.2).
///
/// **É função pura em forma de struct**: sem HealthKit, sem timer, sem relógio
/// do sistema, sem UI. Recebe eventos, devolve efeitos. É isso que permite
/// testar a contagem de voltas "com distâncias simuladas, sem HealthKit real",
/// como a seção 22 exige — e é isso que faz o coração do produto ser verificável
/// fora d'água.
///
/// Quem fala com o `HKWorkoutSession` é o controlador; ele traduz evento de
/// volta e passagem de segundo para cá, e traduz os efeitos em háptico.
///
/// ## As três regras que ela materializa
///
/// - **11.7 — fim da repetição.** A repetição termina quando `voltasPorRepeticao`
///   voltas são contabilizadas desde o início dela. Nunca por tempo, nunca por
///   toque.
/// - **11.8 — início do descanso.** O descanso começa quando a repetição
///   termina, **não quando o nadador para**. Se a detecção de volta atrasar, o
///   descanso começa atrasado — é tolerável e está no risco R3.
/// - **11.10 — tolerância.** Nadar mais não é erro: o treino é dado por
///   concluído, mas as voltas extras continuam contando. Descansar mais não
///   avança nada — o motor espera a volta seguinte.
///
/// ## O princípio 0.1 em forma de código
///
/// **Nenhum evento obrigatório é um toque.** Os únicos eventos que fazem o
/// treino andar são `voltaCompletada` e `segundo`. Pausar, pular e encerrar
/// existem, mas são opcionais e só alcançáveis com o Water Lock destravado.
struct ExecutionEngine: Equatable {

    // MARK: - Estado

    /// Onde a execução está (máquina 12.2).
    enum Estado: Equatable {
        /// Contagem regressiva de 3 s antes de começar (tela W6).
        case preparando
        /// Nadando (tela W7).
        case nadando(Posicao)
        /// Descansando (tela W8) — a contagem é o elemento dominante da tela.
        case descansando(Descanso)
        /// Pausado. Guarda o estado anterior para retomar de onde parou.
        case pausado(anterior: Anterior)
        /// Treino concluído. **Continua aceitando voltas** (regra 11.10).
        case concluido
    }

    /// A posição dentro do treino.
    struct Posicao: Equatable {
        /// Índice da série no plano achatado.
        let serie: Int
        /// Repetição atual, contando de 1 — é o `3` de "3 de 4".
        let repeticao: Int
        /// Voltas já feitas nesta repetição.
        var voltasNaRepeticao: Int = 0
    }

    /// O descanso em curso.
    struct Descanso: Equatable {
        /// Segundos que faltam. **É o número gigante da tela W8.**
        var restanteSeg: Int
        /// Quantos segundos o descanso tinha ao começar.
        let totalSeg: Int
        /// Para onde vai quando zerar.
        let proxima: Posicao
        /// Verdadeiro nos últimos 3 segundos: a tela muda de cor **e** aumenta o
        /// número **e** pulsa (requisito 17.12 — nenhum estado é sinalizado só
        /// por cor).
        var estaNosUltimosTresSegundos: Bool { restanteSeg <= 3 && restanteSeg > 0 }
    }

    /// O que estava acontecendo antes de pausar.
    enum Anterior: Equatable {
        case nadando(Posicao)
        case descansando(Descanso)
    }

    // MARK: - Eventos e efeitos

    enum Evento: Equatable {
        /// Uma volta foi contabilizada. **É o único evento que faz o treino
        /// avançar** (princípio 0.1).
        case voltaCompletada
        /// Passou um segundo.
        case segundo
        /// Ações opcionais, alcançáveis só com o Water Lock destravado (W9).
        case pausar
        case retomar
        case pularSerie
    }

    /// Os hápticos da regra 11.9, e **nada além deles**.
    ///
    /// A regra é explícita: "**Nenhum háptico em qualquer outro evento** —
    /// háptico demais vira ruído e o nadador para de prestar atenção". Por isso
    /// este enum tem exatamente cinco casos e o motor nunca emite fora deles.
    enum Haptico: Equatable {
        /// Entrada em descanso — `.notification`.
        case entradaEmDescanso
        /// Cada um dos três segundos finais — `.directionUp`.
        case contagemFinal
        /// Saída do descanso — `.start`.
        case saidaDoDescanso
        /// Conclusão do treino — `.success`.
        case conclusao
    }

    // MARK: - Propriedades

    let plano: ExecutionPlan
    private(set) var estado: Estado
    /// Voltas contabilizadas desde o início, **incluindo as extras** da regra
    /// 11.10.
    private(set) var voltasTotais = 0
    private(set) var seriesConcluidas = 0
    private(set) var repeticoesConcluidas = 0

    init(plano: ExecutionPlan) {
        self.plano = plano
        self.estado = plano.estaVazio ? .concluido : .preparando
    }

    /// Metros percorridos segundo a contagem de voltas.
    ///
    /// **Não é o que vai para o `HKWorkout`.** Lá vale a distância medida pelo
    /// HealthKit (regra 11.10 e critério 8.9); este número é o que a tela mostra
    /// enquanto se nada, e ele é derivado das voltas justamente para ficar
    /// coerente com o avanço das séries.
    var metrosPercorridos: Int { voltasTotais * plano.tamanhoRaiaM }

    /// A série em execução, quando há uma.
    var serieAtual: ExecutionPlan.SeriePlanejada? {
        switch estado {
        case .nadando(let p): plano.series[safe: p.serie]
        case .descansando(let d): plano.series[safe: d.proxima.serie]
        case .pausado(.nadando(let p)): plano.series[safe: p.serie]
        case .pausado(.descansando(let d)): plano.series[safe: d.proxima.serie]
        case .preparando: plano.series.first
        case .concluido: nil
        }
    }

    // MARK: - Transições

    /// Sai da contagem inicial e começa a nadar.
    ///
    /// Separado de `processar` porque é a única transição que vem do relógio do
    /// sistema e não de um evento da água.
    mutating func comecar() {
        guard case .preparando = estado, !plano.estaVazio else { return }
        estado = .nadando(Posicao(serie: 0, repeticao: 1))
    }

    /// Processa um evento e devolve os hápticos a disparar.
    ///
    /// Devolver os efeitos em vez de dispará-los é o que mantém o motor puro e
    /// testável: o teste afirma **quais** hápticos aconteceram e em que ordem,
    /// sem precisar de aparelho.
    @discardableResult
    mutating func processar(_ evento: Evento) -> [Haptico] {
        switch evento {
        case .voltaCompletada: contabilizarVolta()
        case .segundo: passarSegundo()
        case .pausar: pausar()
        case .retomar: retomar()
        case .pularSerie: pular()
        }
    }

    // MARK: - Volta contabilizada (regra 11.7)

    private mutating func contabilizarVolta() -> [Haptico] {
        voltasTotais += 1

        switch estado {
        case .nadando(var posicao):
            guard let serie = plano.series[safe: posicao.serie] else { return [] }
            posicao.voltasNaRepeticao += 1

            guard posicao.voltasNaRepeticao >= serie.voltasPorRepeticao else {
                // Ainda no meio da repetição.
                estado = .nadando(posicao)
                return []
            }
            return concluirRepeticao(posicao, serie: serie)

        case .descansando(let descanso):
            // O nadador saiu antes de a contagem zerar. **Contar a volta é o
            // certo**: ignorá-la faria a repetição seguinte terminar uma volta
            // atrasada, e o erro se acumularia até o fim do treino. A regra
            // 11.10 manda nunca punir o nadador por descompasso de detecção.
            var posicao = descanso.proxima
            posicao.voltasNaRepeticao = 1
            estado = .nadando(posicao)
            return [.saidaDoDescanso]

        case .concluido, .preparando, .pausado:
            // Regra 11.10: nadar mais que o planejado não gera erro — a volta
            // conta na distância e nada avança.
            return []
        }
    }

    /// Fecha uma repetição e decide o que vem depois (regras 11.6 e 11.7).
    private mutating func concluirRepeticao(
        _ posicao: Posicao, serie: ExecutionPlan.SeriePlanejada
    ) -> [Haptico] {
        repeticoesConcluidas += 1

        // Ainda há repetição nesta série: descanso interno (regra 11.5).
        if posicao.repeticao < serie.repeticoes {
            let proxima = Posicao(serie: posicao.serie, repeticao: posicao.repeticao + 1)
            return entrarEmDescanso(de: serie.descansoSeg, indo: proxima)
        }

        // A série acabou.
        seriesConcluidas += 1

        guard posicao.serie + 1 < plano.series.count else {
            // Última série da última seção: háptico de conclusão (fluxo 8.8).
            estado = .concluido
            return [.conclusao]
        }

        let proxima = Posicao(serie: posicao.serie + 1, repeticao: 1)
        return entrarEmDescanso(de: serie.descansoDepoisSeg, indo: proxima)
    }

    /// Entra em descanso, ou segue direto quando não há descanso a fazer.
    private mutating func entrarEmDescanso(de segundos: Int, indo proxima: Posicao) -> [Haptico] {
        guard segundos > 0 else {
            // Sem descanso não há entrada em descanso, e portanto **não há
            // háptico**: a regra 11.9 proíbe háptico em qualquer evento fora
            // dos cinco listados.
            estado = .nadando(proxima)
            return []
        }
        estado = .descansando(
            Descanso(restanteSeg: segundos, totalSeg: segundos, proxima: proxima))
        return [.entradaEmDescanso]
    }

    // MARK: - Passagem de tempo

    private mutating func passarSegundo() -> [Haptico] {
        guard case .descansando(var descanso) = estado else {
            // Fora do descanso o tempo não faz nada avançar. É o outro lado da
            // regra 11.10: descansar mais que o previsto não adianta a série —
            // o motor espera a volta seguinte.
            return []
        }

        descanso.restanteSeg -= 1

        if descanso.restanteSeg <= 0 {
            estado = .nadando(descanso.proxima)
            return [.saidaDoDescanso]
        }

        estado = .descansando(descanso)
        // Três segundos finais: um háptico por segundo (regra 11.9).
        return descanso.restanteSeg <= 3 ? [.contagemFinal] : []
    }

    // MARK: - Ações opcionais (tela W9)

    private mutating func pausar() -> [Haptico] {
        switch estado {
        case .nadando(let p): estado = .pausado(anterior: .nadando(p))
        case .descansando(let d): estado = .pausado(anterior: .descansando(d))
        default: break
        }
        // Sem háptico: a regra 11.9 não lista pausa.
        return []
    }

    private mutating func retomar() -> [Haptico] {
        guard case .pausado(let anterior) = estado else { return [] }
        switch anterior {
        case .nadando(let p): estado = .nadando(p)
        case .descansando(let d): estado = .descansando(d)
        }
        return []
    }

    /// Pula para a próxima série, sem descanso e sem háptico.
    ///
    /// A série pulada **não** conta como concluída: ela não foi nadada, e
    /// inflar o contador falsearia o resumo.
    private mutating func pular() -> [Haptico] {
        let serieAtual: Int? =
            switch estado {
            case .nadando(let p): p.serie
            case .descansando(let d): d.proxima.serie
            case .pausado(.nadando(let p)): p.serie
            case .pausado(.descansando(let d)): d.proxima.serie
            case .preparando, .concluido: nil
            }
        guard let atual = serieAtual else { return [] }

        guard atual + 1 < plano.series.count else {
            estado = .concluido
            return [.conclusao]
        }
        estado = .nadando(Posicao(serie: atual + 1, repeticao: 1))
        return []
    }
}

extension Array {

    /// Acesso por índice que devolve `nil` fora dos limites.
    ///
    /// O motor de execução indexa o plano em vários pontos; um índice fora da
    /// faixa por bug de transição derrubaria o app **no meio de um treino, com o
    /// aparelho debaixo d'água**. Devolver `nil` transforma isso num estado
    /// degradado em vez de num crash.
    subscript(safe indice: Int) -> Element? {
        indices.contains(indice) ? self[indice] : nil
    }
}
