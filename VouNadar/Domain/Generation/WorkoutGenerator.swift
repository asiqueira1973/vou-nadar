import Foundation

/// O motor que monta o treino (contrato 13.1).
///
/// Recebe: uma `GenerationRequest` e uma fonte de aleatoriedade injetada.
/// Devolve: um `GenerationResult` com as quatro seções da regra 11.1, cada série
/// já com o descanso da regra 11.5 e as voltas da regra 11.3 carimbados.
/// Erros: **nenhum**. Ver "A regra 11.2 e a decisão da Q5", abaixo.
///
/// **É função pura.** Não importa SwiftData, não importa SwiftUI, não lê disco,
/// não escreve log e não consulta relógio. Tudo o que ele sabe do mundo entra
/// pelo `AdaptedCatalog` e pela `GenerationRequest`; tudo o que decide sai no
/// resultado. É essa disciplina que torna as 500 gerações do teste de
/// propriedade possíveis (seção 22).
///
/// ## De onde ele veio
///
/// Copiado e adaptado do Swim Builder (spec 4.4, assunção 24.2). A heurística de
/// composição é a de lá, validada em produção: reservas de aquecimento e
/// soltura por faixa de alvo, divisão 20/80 entre progressão e parte principal,
/// bônus de educativo, primeira série com equipamento, anti-dois-longos, e
/// complemento por lacuna. A ordem de montagem também é a de lá — aquecimento,
/// soltura, progressão, parte principal, complemento —, e a soltura vem antes do
/// miolo de propósito: ela é a reserva garantida, e o resto se acomoda ao que
/// sobra.
///
/// **O spec do Vou Nadar não numera essa composição interna.** Ele exige o
/// resultado (regra 11.1: quatro seções sempre; regra 11.2: total dentro da
/// faixa). O que está aqui é conhecimento de produto herdado, e é por isso que
/// cada passagem diz de onde veio em vez de citar um número de regra que não
/// existe neste documento.
///
/// ## O que mudou em relação ao Swim Builder
///
/// 1. **A raia entrou** (regra 11.3), mas não neste arquivo: ela é
///    pré-transformação do catálogo (`AdaptedCatalog`). Como todo orçamento
///    daqui é somado em `metrosTotais` e esse número já vem adaptado, a
///    verificação da faixa (regra 11.2) passa a ser feita sobre a distância real
///    sem uma linha a mais no laço.
/// 2. **O descanso entrou** (regras 11.5 e 11.6), como passagem final —
///    `carimbarDescansos`. Ele não influencia a escolha dos exercícios, só é
///    gravado sobre ela.
/// 3. **20 tentativas viraram 50** (regra 11.2).
/// 4. **O gerador deixou de lançar erro.** Ver abaixo.
///
/// ## A regra 11.2 e a decisão da Q5
///
/// O gerador do Swim Builder lança `GenerationError.belowMinimum` quando as
/// tentativas se esgotam. Aqui isso é proibido: a regra 11.2 diz que se o
/// sorteio não fechar dentro da faixa em até 50 tentativas, o gerador "aceita o
/// resultado mais próximo e registra em log — **nunca falha para o usuário**".
///
/// E a pergunta Q5 do spec — quando a faixa não fecha, vence treino menor ou
/// exercício repetido? — foi respondida pelo Alexandre: **treino menor**. Por
/// isso o motor não ganhou nenhuma máquina nova de repetição para forçar o
/// mínimo; ele guarda o melhor rascunho das 50 tentativas e devolve esse. Os
/// limites de repetição herdados (2 vezes no treino, 3 no complemento)
/// continuam como estavam, porque são parte da heurística de variedade do Swim
/// Builder, não um mecanismo de fechar a faixa.
///
/// O caso concreto onde isso aparece: faixa fechada em 2.000 m numa piscina de
/// 16 m. Toda distância adaptada é múltiplo de 16, e 2.000 não é — então nenhum
/// treino fecha exatamente, e o resultado sai um pouco abaixo, com
/// `trace.aceitouAbaixoDoMinimo` verdadeiro.
struct WorkoutGenerator {

    /// Máximo de tentativas de montar um treino dentro da faixa (regra 11.2).
    static let maxTentativas = 50

    /// Máximo de vezes que um treino é descartado por ser idêntico ao anterior
    /// em "Gerar outro". Na quarta vez o resultado é aceito como está.
    static let maxRejeicoesPorIdentidade = 3

    /// A partir de quantos metros um bloco `continuo` conta como "longo", para o
    /// filtro anti-dois-longos.
    ///
    /// A comparação é sobre os metros **adaptados**, e não os do catálogo: o que
    /// torna dois blocos seguidos um treino ruim é a distância que o nadador
    /// nada de fato.
    static let metrosDeBlocoLongo = 500

    private let catalogo: AdaptedCatalog

    init(catalogo: AdaptedCatalog) {
        self.catalogo = catalogo
    }

    // MARK: - Entrada única (contrato 13.1)

    /// Monta um treino.
    ///
    /// Aplica dois laços de retentativa, independentes e com propósitos
    /// diferentes:
    ///
    /// - **validade** (regra 11.2): se o rascunho não fechou o mínimo pedido,
    ///   guarda-o como candidato e recomeça, até 50 vezes. Esgotando, devolve o
    ///   melhor — nunca falha.
    /// - **variedade**: se o treino saiu com exatamente o mesmo conjunto de
    ///   exercícios do que está na tela ("Gerar outro"), descarta e gera outro,
    ///   até 3 vezes; na quarta, aceita.
    ///
    /// Nada é gravado aqui — a gravação é do repositório, depois.
    func gerar(
        _ pedido: GenerationRequest,
        using rng: inout some RandomNumberGenerator
    ) -> GenerationResult {
        var rejeicoesPorIdentidade = 0
        var melhorRascunho: Rascunho?

        for tentativa in 1...Self.maxTentativas {
            var rascunho = montarUmaVez(pedido, using: &rng)
            rascunho.trace.tentativas = tentativa
            rascunho.trace.rejeicoesPorIdentidade = rejeicoesPorIdentidade
            rascunho.trace.candidatosDisponiveis = candidatosDisponiveis(pedido)

            // Descarte por identidade: mesmo multiconjunto do treino anterior.
            if let anterior = pedido.previousExerciseIds,
                rejeicoesPorIdentidade < Self.maxRejeicoesPorIdentidade,
                mesmoMulticonjunto(rascunho.todosOsIds, anterior)
            {
                rejeicoesPorIdentidade += 1
                continue
            }

            // Fechou dentro da faixa: é o resultado.
            if rascunho.total >= pedido.minMeters {
                return resultado(de: rascunho, pedido: pedido)
            }

            // Não fechou. Guarda o mais próximo do mínimo — "mais próximo" é o
            // de maior total, porque o teto rígido já garante que nenhum
            // rascunho passa do máximo pedido.
            if melhorRascunho == nil || rascunho.total > melhorRascunho!.total {
                melhorRascunho = rascunho
            }
        }

        // Regra 11.2: aceita o melhor resultado. **Nunca falha para o usuário.**
        var melhor = melhorRascunho ?? montarUmaVez(pedido, using: &rng)
        melhor.trace.tentativas = Self.maxTentativas
        melhor.trace.aceitouAbaixoDoMinimo = true
        melhor.trace.candidatosDisponiveis = candidatosDisponiveis(pedido)
        return resultado(de: melhor, pedido: pedido)
    }

    /// Quantos candidatos esta combinação deixa (regra 11.19), para o trace e
    /// para a interface decidir se mostra a copy 15.17.
    private func candidatosDisponiveis(_ pedido: GenerationRequest) -> Int {
        catalogo.utilizaveis.count {
            equipamentoPermitido($0, pedido.selectedEquipment)
                && modoPermitido($0, pedido)
        }
    }

    // MARK: - Alvo total e divisão entre as seções

    /// Sorteia o alvo total entre os múltiplos de 100 da faixa pedida.
    ///
    /// Herdado do Swim Builder. O caminho do `else` só é alcançável com faixas
    /// como `[1520, 1580]`, que não têm múltiplo de 100 dentro — a interface não
    /// produz isso (o slider anda de 100 em 100), mas o motor se defende de quem
    /// o chamar direto.
    static func sortearAlvoTotal(
        min minMeters: Int, max maxMeters: Int, using rng: inout some RandomNumberGenerator
    ) -> Int {
        let primeiroMultiplo = Int((Double(minMeters) / 100).rounded(.up)) * 100
        let ultimoMultiplo = (maxMeters / 100) * 100

        if primeiroMultiplo <= ultimoMultiplo {
            let opcoes = Array(stride(from: primeiroMultiplo, through: ultimoMultiplo, by: 100))
            return opcoes.randomElement(using: &rng) ?? primeiroMultiplo
        }

        var alvo = primeiroMultiplo
        if alvo > maxMeters { alvo = ultimoMultiplo }
        if alvo <= 0 { alvo = minMeters }
        return alvo
    }

    /// Reserva fixa de aquecimento e de soltura, por faixa de alvo total.
    ///
    /// Herdado do Swim Builder. Abaixo de 200 m o treino inteiro é uma soltura:
    /// aquecimento, progressão e parte principal ficam vazios, **e os quatro
    /// registros de seção continuam sendo criados** (regra 11.1).
    static func reservas(paraAlvo alvoTotal: Int) -> (aquecimento: Int, soltura: Int) {
        guard alvoTotal >= 200 else { return (aquecimento: 0, soltura: alvoTotal) }
        let aquecimento = alvoTotal <= 1200 ? 200 : (alvoTotal <= 1800 ? 300 : 400)
        return (aquecimento: aquecimento, soltura: 200)
    }

    /// Divide o que sobra entre progressão e parte principal.
    ///
    /// Herdado do Swim Builder. A progressão fica com 20% do restante,
    /// arredondado ao múltiplo de 100 mais próximo, **meio para cima** —
    /// `floor(x + 0,5)`, não bancário, que devolveria 200 onde a heurística
    /// original dá 300.
    ///
    /// Bônus de educativo: com o interruptor ligado e a parte principal tendo ao
    /// menos 300 m, transfere 100 m dela para o aquecimento. **O alvo total não
    /// muda** — o educativo não alonga o treino, troca uma parte da série
    /// principal por técnica.
    static func divisao(
        alvo alvoTotal: Int, aquecimento: Int, soltura: Int, comEducativos: Bool
    ) -> (progressao: Int, principal: Int, bonusEducativo: Int) {
        let restante = max(0, alvoTotal - aquecimento - soltura)
        let progressao = Int((Double(restante) * 0.20 / 100 + 0.5).rounded(.down)) * 100
        var principal = restante - progressao

        var bonus = 0
        if comEducativos && principal >= 300 {
            bonus = 100
            principal -= 100
        }
        return (progressao: progressao, principal: principal, bonusEducativo: bonus)
    }

    // MARK: - Uma tentativa completa

    /// Monta um treino do zero, uma vez.
    ///
    /// Devolve o rascunho, que pode ter fechado abaixo do mínimo — quem decide o
    /// que fazer com isso é a regra 11.2, no laço de cima.
    private func montarUmaVez(
        _ pedido: GenerationRequest, using rng: inout some RandomNumberGenerator
    ) -> Rascunho {
        var rascunho = Rascunho()

        let alvoTotal = Self.sortearAlvoTotal(
            min: pedido.minMeters, max: pedido.maxMeters, using: &rng)
        let reservas = Self.reservas(paraAlvo: alvoTotal)
        let divisao = Self.divisao(
            alvo: alvoTotal, aquecimento: reservas.aquecimento, soltura: reservas.soltura,
            comEducativos: pedido.includeDrills)

        let alvoAquecimento = reservas.aquecimento + divisao.bonusEducativo

        rascunho.trace.alvoTotalM = alvoTotal
        rascunho.trace.alvoAquecimentoM = alvoAquecimento
        rascunho.trace.alvoSolturaM = reservas.soltura
        rascunho.trace.alvoProgressaoM = divisao.progressao
        rascunho.trace.alvoPrincipalM = divisao.principal
        rascunho.trace.bonusEducativoM = divisao.bonusEducativo

        montarAquecimento(&rascunho, alvo: alvoAquecimento, pedido: pedido, using: &rng)
        montarSoltura(&rascunho, alvo: reservas.soltura, pedido: pedido, using: &rng)
        montarProgressao(&rascunho, alvo: divisao.progressao, pedido: pedido, using: &rng)
        montarPrincipal(&rascunho, alvo: divisao.principal, pedido: pedido, using: &rng)
        completar(&rascunho, pedido: pedido, using: &rng)

        return rascunho
    }

    // MARK: - Aquecimento

    /// Monta o aquecimento, com a passagem de educativo na primeira escolha.
    private func montarAquecimento(
        _ rascunho: inout Rascunho, alvo: Int, pedido: GenerationRequest,
        using rng: inout some RandomNumberGenerator
    ) {
        guard alvo > 0 else {
            rascunho.trace.desfechos[.aquecimento] = .emptyTarget
            return
        }

        var acumulado = 0
        var naSecao = Set<String>()
        var jaTemEducativo = false
        rascunho.trace.desfechos[.aquecimento] = .reachedTarget

        while acumulado < alvo {
            let restante = alvo - acumulado
            var escolhido: AdaptedExercise?

            // Primeira escolha tenta um educativo, uma vez só por treino. Esta
            // passagem NÃO checa "não repetido na seção": `jaTemEducativo` já
            // garante que ela roda uma vez.
            if pedido.includeDrills && !jaTemEducativo {
                escolhido = catalogo.educativos.filter {
                    $0.metrosTotais <= restante
                        && equipamentoPermitido($0, pedido.selectedEquipment)
                        && rascunho.contagemGlobal[$0.exercicioId, default: 0] < 2
                        && rascunho.cabe($0, max: pedido.maxMeters)
                }.randomElement(using: &rng)
            }

            if escolhido == nil {
                let candidatos = catalogo.aquecimento.filter {
                    $0.metrosTotais <= restante
                        && equipamentoPermitido($0, pedido.selectedEquipment)
                        && !naSecao.contains($0.exercicioId)
                        && rascunho.contagemGlobal[$0.exercicioId, default: 0] < 2
                        && rascunho.cabe($0, max: pedido.maxMeters)
                }
                guard let sorteado = candidatos.randomElement(using: &rng) else {
                    rascunho.trace.desfechos[.aquecimento] = .noCandidateLeft
                    break
                }
                escolhido = sorteado
            }

            guard let exercicio = escolhido else { break }
            rascunho.inserir(exercicio, em: .aquecimento)
            naSecao.insert(exercicio.exercicioId)
            acumulado += exercicio.metrosTotais
            if exercicio.exercicio.modo == .educativo { jaTemEducativo = true }
        }
    }

    // MARK: - Soltura

    /// Monta a soltura e aplica o resgate quando ela fica vazia.
    ///
    /// A soltura é a única seção que o motor garante, e é por isso que ela é
    /// montada antes da progressão e da parte principal: o miolo do treino se
    /// acomoda no que sobra, e não o contrário.
    ///
    /// Aqui não há limite global de 2 repetições — a não-repetição dentro da
    /// seção já basta, e o pool de soltura é pequeno.
    private func montarSoltura(
        _ rascunho: inout Rascunho, alvo: Int, pedido: GenerationRequest,
        using rng: inout some RandomNumberGenerator
    ) {
        guard alvo > 0 else {
            rascunho.trace.desfechos[.soltura] = .emptyTarget
            return
        }

        var acumulado = 0
        var naSecao = Set<String>()
        rascunho.trace.desfechos[.soltura] = .reachedTarget

        while acumulado < alvo {
            let restante = alvo - acumulado
            // O pool de soltura já exige `equipamento_exigido = nenhum`.
            let candidatos = catalogo.soltura.filter {
                $0.metrosTotais <= restante
                    && !naSecao.contains($0.exercicioId)
                    && rascunho.cabe($0, max: pedido.maxMeters)
            }
            guard let exercicio = candidatos.randomElement(using: &rng) else {
                rascunho.trace.desfechos[.soltura] = .noCandidateLeft
                break
            }
            rascunho.inserir(exercicio, em: .soltura)
            naSecao.insert(exercicio.exercicioId)
            acumulado += exercicio.metrosTotais
        }

        // Resgate: se a seleção não fechou o alvo e a seção ficou VAZIA, insere
        // o bloco de soltura de menor metragem que caiba no teto, ignorando o
        // alvo da seção. Sair da água sem soltura é pior que estourar o desenho.
        if rascunho.soltura.isEmpty {
            let cabem = catalogo.soltura.filter { rascunho.cabe($0, max: pedido.maxMeters) }
            if let menor = cabem.min(by: { $0.metrosTotais < $1.metrosTotais }) {
                rascunho.inserir(menor, em: .soltura)
                rascunho.trace.usouResgateDaSoltura = true
            }
            // Se nem o menor couber, a soltura fica vazia e o motor segue — o
            // motivo já está no trace, e a regra 11.1 exige que a seção exista,
            // não que tenha série.
        }
    }

    // MARK: - Progressão

    private func montarProgressao(
        _ rascunho: inout Rascunho, alvo: Int, pedido: GenerationRequest,
        using rng: inout some RandomNumberGenerator
    ) {
        guard alvo > 0 else {
            rascunho.trace.desfechos[.progressao] = .emptyTarget
            return
        }

        // "Não veio do aquecimento". Com o catálogo atual este filtro nunca faz
        // nada — aquecimento exige intensidade `aquecimento` e a progressão
        // exige `variavel`, `aerobico` ou `moderado`, conjuntos disjuntos. Fica
        // implementado porque é a intenção da heurística original e passa a ter
        // efeito assim que o catálogo ganhar aquecimento com outra intensidade.
        // Não remova achando que é redundante.
        let idsDoAquecimento = Set(rascunho.aquecimento.map(\.exercicioId))

        var acumulado = 0
        var naSecao = Set<String>()
        rascunho.trace.desfechos[.progressao] = .reachedTarget

        while acumulado < alvo {
            let restante = alvo - acumulado
            let base = catalogo.progressao.filter {
                // Tolerância de estouro de 100 m NA SEÇÃO — mas o teto rígido,
                // aplicado por `cabe`, prevalece sobre ela.
                $0.metrosTotais <= restante + 100
                    && equipamentoPermitido($0, pedido.selectedEquipment)
                    && !naSecao.contains($0.exercicioId)
                    && !idsDoAquecimento.contains($0.exercicioId)
                    && rascunho.contagemGlobal[$0.exercicioId, default: 0] < 2
                    && rascunho.cabe($0, max: pedido.maxMeters)
            }
            guard !base.isEmpty else {
                rascunho.trace.desfechos[.progressao] = .noCandidateLeft
                break
            }

            // Prioridade: primeiro os três controles que são progressão de
            // verdade. Só se não houver nenhum é que entra um `constante`.
            let preferidos = base.filter {
                [.progressivo, .split_negativo, .crescente].contains($0.exercicio.tipo_controle)
            }
            let sorteio = preferidos.isEmpty ? base : preferidos
            guard let exercicio = sorteio.randomElement(using: &rng) else { break }

            rascunho.inserir(exercicio, em: .progressao)
            naSecao.insert(exercicio.exercicioId)
            acumulado += exercicio.metrosTotais
        }
    }

    // MARK: - Parte principal

    /// Monta a parte principal, em três passagens: bloco de pernada, primeira
    /// série com equipamento, e seleção geral.
    private func montarPrincipal(
        _ rascunho: inout Rascunho, alvo: Int, pedido: GenerationRequest,
        using rng: inout some RandomNumberGenerator
    ) {
        guard alvo > 0 else {
            rascunho.trace.desfechos[.principal] = .emptyTarget
            return
        }

        var acumulado = 0
        var jaUsouEquipamento = false
        var jaTemPernada = false
        rascunho.trace.desfechos[.principal] = .reachedTarget

        while acumulado < alvo {
            let restante = alvo - acumulado
            var escolhido: AdaptedExercise?

            // No máximo um bloco de pernada por treino, e só com o interruptor
            // ligado.
            if pedido.includeKick && !jaTemPernada {
                escolhido = catalogo.pernada.filter {
                    $0.metrosTotais <= restante
                        && equipamentoPermitido($0, pedido.selectedEquipment)
                        && rascunho.contagemGlobal[$0.exercicioId, default: 0] < 2
                        && rascunho.cabe($0, max: pedido.maxMeters)
                }.randomElement(using: &rng)
            }

            // A primeira série com equipamento, uma vez por treino. O filtro
            // aqui é mais forte que o normal: exige OBRIGATORIAMENTE um dos
            // selecionados, nunca `nenhum`. É o que garante que quem levou
            // palmar na mochila use o palmar.
            if escolhido == nil, !pedido.selectedEquipment.isEmpty, !jaUsouEquipamento {
                escolhido = catalogo.principal.filter {
                    $0.metrosTotais <= restante
                        && pedido.selectedEquipment.contains($0.exercicio.equipamento_exigido)
                        && rascunho.contagemGlobal[$0.exercicioId, default: 0] < 2
                        && !violaDoisLongos($0, rascunho: rascunho)
                        && rascunho.cabe($0, max: pedido.maxMeters)
                }.randomElement(using: &rng)
            }

            if escolhido == nil {
                let candidatos = catalogo.principal.filter {
                    $0.metrosTotais <= restante
                        && equipamentoPermitido($0, pedido.selectedEquipment)
                        && rascunho.contagemGlobal[$0.exercicioId, default: 0] < 2
                        && !violaDoisLongos($0, rascunho: rascunho)
                        && rascunho.cabe($0, max: pedido.maxMeters)
                }
                guard let sorteado = candidatos.randomElement(using: &rng) else {
                    rascunho.trace.desfechos[.principal] = .noCandidateLeft
                    break
                }
                escolhido = sorteado
            }

            guard let exercicio = escolhido else { break }
            rascunho.inserir(exercicio, em: .principal)
            acumulado += exercicio.metrosTotais
            if exercicio.exercicio.modo == .pernada { jaTemPernada = true }
            if exercicio.exercicio.equipamento_exigido != "nenhum" { jaUsouEquipamento = true }
        }
    }

    // MARK: - Complemento

    /// Fecha o mínimo pedido com blocos extras no fim da parte principal.
    ///
    /// Duas diferenças em relação às outras passagens, as duas herdadas: o
    /// limite global aqui é **3**, não 2, e a escolha não é uniforme — ordena
    /// por distância da lacuna e sorteia entre os empatados, porque o objetivo
    /// aqui é fechar a conta, não variar.
    ///
    /// Este **não** é o mecanismo da Q5: ele não força o mínimo a qualquer
    /// custo, ele só usa o repertório que já existe. Quando os candidatos
    /// acabam, o laço para e o treino sai menor (regra 11.2).
    private func completar(
        _ rascunho: inout Rascunho, pedido: GenerationRequest,
        using rng: inout some RandomNumberGenerator
    ) {
        while rascunho.total < pedido.minMeters {
            let lacuna = pedido.minMeters - rascunho.total
            let candidatos = catalogo.complemento.filter {
                rascunho.cabe($0, max: pedido.maxMeters)
                    && equipamentoPermitido($0, pedido.selectedEquipment)
                    && rascunho.contagemGlobal[$0.exercicioId, default: 0] < 3
                    && !violaDoisLongos($0, rascunho: rascunho)
            }
            guard !candidatos.isEmpty else { break }

            let menorDistancia = candidatos.map { abs($0.metrosTotais - lacuna) }.min() ?? 0
            let empatados = candidatos.filter { abs($0.metrosTotais - lacuna) == menorDistancia }
            guard let exercicio = empatados.randomElement(using: &rng) else { break }

            rascunho.inserir(exercicio, em: .principal)
        }
    }

    // MARK: - Filtros compartilhados

    /// Equipamento aceito: `nenhum` ou um dos marcados.
    private func equipamentoPermitido(
        _ exercicio: AdaptedExercise, _ selecionados: Set<String>
    ) -> Bool {
        RepertoireGuard.equipamentoPermitido(exercicio.exercicio, selecionados)
    }

    /// Modo aceito pelos dois interruptores.
    private func modoPermitido(_ exercicio: AdaptedExercise, _ pedido: GenerationRequest) -> Bool {
        RepertoireGuard.modoPermitido(
            exercicio.exercicio, incluirEducativos: pedido.includeDrills,
            incluirPernada: pedido.includeKick)
    }

    /// Um bloco `continuo` de 500 m adaptados ou mais.
    static func ehBlocoLongo(_ exercicio: AdaptedExercise) -> Bool {
        exercicio.exercicio.tipo_controle == .continuo
            && exercicio.metrosTotais >= metrosDeBlocoLongo
    }

    /// Anti-dois-longos: proibido dois contínuos de 500 m ou mais seguidos na
    /// parte principal. Nadar 600 contínuos e emendar outros 600 é um treino
    /// ruim, não uma variação.
    ///
    /// Vale nas TRÊS passagens que escrevem na parte principal, inclusive o
    /// complemento.
    private func violaDoisLongos(_ candidato: AdaptedExercise, rascunho: Rascunho) -> Bool {
        guard let anterior = rascunho.principal.last else { return false }
        return Self.ehBlocoLongo(anterior) && Self.ehBlocoLongo(candidato)
    }

    /// Dois multiconjuntos de `exercicio_id` são iguais? Mesmos exercícios nas
    /// mesmas quantidades, independentemente da ordem.
    private func mesmoMulticonjunto(_ a: [String], _ b: [String]) -> Bool {
        guard a.count == b.count else { return false }
        var contagem: [String: Int] = [:]
        for id in a { contagem[id, default: 0] += 1 }
        for id in b {
            guard let restante = contagem[id], restante > 0 else { return false }
            contagem[id] = restante - 1
        }
        return true
    }

    // MARK: - Descanso (regras 11.5 e 11.6)

    /// Carimba os descansos sobre um rascunho pronto e monta o resultado.
    ///
    /// Roda **depois** da escolha dos exercícios: o descanso não influencia
    /// quais blocos entram, só é gravado sobre eles. Cada número vira snapshot
    /// em `serie_treino` e nunca é recalculado na leitura (princípio 0.6).
    ///
    /// Três decisões que a regra 11.5 e a 11.6 não escrevem com todas as letras,
    /// e a razão de cada uma:
    ///
    /// - **Série de uma repetição só sai com `descanso_seg = 0`.** Não há
    ///   "entre as repetições" quando só existe uma. É o que a seção 7.2 diz ao
    ///   observar que "166 dos 226 têm valor maior que 1 — são os que ganham
    ///   descanso interno", e é o que o exemplo da seção 14.1 mostra: `1×300
    ///   crawl leve` sai sem sufixo de descanso, `4×50 pernada — 20s` sai com.
    /// - **A última série da seção tem `descanso_pos_serie_seg = 0`** (regra
    ///   11.6): ali vale o descanso de seção, e os dois nunca se somam.
    /// - **Seção vazia e última seção com série têm `descanso_pos_secao_seg =
    ///   0`.** A regra 11.6 diz "zero na última seção"; estender isso à seção
    ///   vazia é consequência direta — descansar depois de uma seção sem
    ///   nenhuma série faria o relógio parar por 45 segundos no nada.
    private func resultado(de rascunho: Rascunho, pedido: GenerationRequest) -> GenerationResult {
        let ritmo = pedido.restPace
        let descansoEntreSeries = RestCalculator.descansoEntreSeries(ritmo: ritmo)
        let descansoEntreSecoes = RestCalculator.descansoEntreSecoes(ritmo: ritmo)

        let porTipo: [TipoSecao: [AdaptedExercise]] = [
            .aquecimento: rascunho.aquecimento,
            .progressao: rascunho.progressao,
            .principal: rascunho.principal,
            .soltura: rascunho.soltura,
        ]
        let alvoPorTipo: [TipoSecao: Int] = [
            .aquecimento: rascunho.trace.alvoAquecimentoM,
            .progressao: rascunho.trace.alvoProgressaoM,
            .principal: rascunho.trace.alvoPrincipalM,
            .soltura: rascunho.trace.alvoSolturaM,
        ]

        // A última seção COM SÉRIE não tem descanso de seção depois dela.
        let ultimaComSerie = TipoSecao.allCases.last { !(porTipo[$0] ?? []).isEmpty }

        let secoes = TipoSecao.allCases.map { tipo -> GeneratedSection in
            let exercicios = porTipo[tipo] ?? []

            let series = exercicios.enumerated().map { indice, adaptado -> GeneratedSet in
                let ehUltimaDaSecao = indice == exercicios.count - 1
                let repeticoes = adaptado.exercicio.repeticoes
                return GeneratedSet(
                    exercicioId: adaptado.exercicioId,
                    repeticoes: repeticoes,
                    distanciaM: adaptado.distanciaM,
                    distanciaCatalogoM: adaptado.distanciaCatalogoM,
                    metrosTotais: adaptado.metrosTotais,
                    descansoSeg: repeticoes > 1
                        ? RestCalculator.descansoSegundos(
                            distanciaM: adaptado.distanciaM,
                            intensidade: adaptado.exercicio.intensidade,
                            modo: adaptado.exercicio.modo,
                            ritmo: ritmo)
                        : 0,
                    descansoPosSerieSeg: ehUltimaDaSecao ? 0 : descansoEntreSeries,
                    voltasPorRepeticao: adaptado.voltasPorRepeticao,
                    nomeSnapshot: adaptado.exercicio.nome,
                    descricaoSnapshot: adaptado.exercicio.descricao,
                    equipamentoExigido: adaptado.exercicio.equipamento_exigido,
                    modo: adaptado.exercicio.modo,
                    intensidade: adaptado.exercicio.intensidade,
                    ordem: indice + 1)
            }

            return GeneratedSection(
                tipo: tipo,
                alvoM: alvoPorTipo[tipo] ?? 0,
                descansoPosSecaoSeg: (exercicios.isEmpty || tipo == ultimaComSerie)
                    ? 0 : descansoEntreSecoes,
                series: series)
        }

        return GenerationResult(
            alvoTotalM: rascunho.trace.alvoTotalM,
            secoes: secoes,
            totalM: rascunho.total,
            laneLengthM: pedido.laneLengthM,
            restPace: ritmo,
            trace: rascunho.trace)
    }

    // MARK: - Rascunho

    /// Estado de uma tentativa de geração. Existe só dentro do gerador.
    private struct Rascunho {
        var aquecimento: [AdaptedExercise] = []
        var progressao: [AdaptedExercise] = []
        var principal: [AdaptedExercise] = []
        var soltura: [AdaptedExercise] = []

        /// Soma corrente de metros **adaptados**. É contra ela que o teto rígido
        /// é avaliado, e é ela que a regra 11.2 verifica.
        var total = 0

        /// Quantas vezes cada `exercicio_id` já entrou no treino inteiro.
        var contagemGlobal: [String: Int] = [:]

        var trace = GenerationTrace()

        var todosOsIds: [String] {
            (aquecimento + progressao + principal + soltura).map(\.exercicioId)
        }

        /// Teto rígido global: nenhuma inserção, em nenhuma seção, em nenhuma
        /// passagem, pode fazer o total projetado passar do máximo pedido.
        ///
        /// É avaliado DEPOIS de todos os outros filtros e ANTES do sorteio, e
        /// prevalece sobre a tolerância de +100 da progressão.
        func cabe(_ exercicio: AdaptedExercise, max maxMeters: Int) -> Bool {
            total + exercicio.metrosTotais <= maxMeters
        }

        mutating func inserir(_ exercicio: AdaptedExercise, em secao: TipoSecao) {
            switch secao {
            case .aquecimento: aquecimento.append(exercicio)
            case .progressao: progressao.append(exercicio)
            case .principal: principal.append(exercicio)
            case .soltura: soltura.append(exercicio)
            }
            contagemGlobal[exercicio.exercicioId, default: 0] += 1
            total += exercicio.metrosTotais
            trace.escolhidos[secao, default: []].append(exercicio.exercicioId)
        }
    }
}
