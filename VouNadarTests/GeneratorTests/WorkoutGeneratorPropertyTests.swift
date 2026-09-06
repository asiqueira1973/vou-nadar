import Foundation
import Testing

@testable import VouNadar

/// Teste de propriedade do gerador — critérios de aceite do épico 8.4 e da
/// seção 22.
///
/// **500 gerações com sementes variadas**, cobrindo faixa de distância,
/// equipamentos, interruptores e — o que o gerador do Swim Builder não tinha —
/// **tamanho de raia**. Cada geração é conferida contra todos os critérios de
/// uma vez, porque um treino que respeita a faixa mas perde uma seção é tão
/// inválido quanto o contrário.
struct WorkoutGeneratorPropertyTests {

    /// Um caso do teste de propriedade.
    struct Caso: Sendable, CustomStringConvertible {
        let semente: UInt64
        let minM: Int
        let maxM: Int
        let equipamentos: Set<String>
        let educativos: Bool
        let pernada: Bool
        let raiaM: Int

        var description: String {
            "semente \(semente), \(minM)–\(maxM) m, raia \(raiaM) m, "
                + "equip \(equipamentos.sorted()), educ \(educativos), pern \(pernada)"
        }
    }

    /// Os 500 casos, montados deterministicamente.
    ///
    /// A semente sai da **identidade** do caso, nunca de `hashValue` do Swift —
    /// o `Hasher` é aleatorizado a cada processo, e um teste semeado por ele
    /// mudaria de resultado a cada execução.
    ///
    /// As raias cobrem as oito da tabela de "11.3 detalhado" mais a de 33 m, que
    /// é o pior caso conhecido do catálogo.
    static let casos: [Caso] = {
        let raias = [10, 12, 15, 16, 18, 20, 25, 33, 50]
        let equipamentosPossiveis: [Set<String>] = [
            [],
            ["pull_buoy"],
            ["palmares"],
            ["nadadeiras"],
            ["prancha"],
            ["pull_buoy", "palmares"],
            ["pull_buoy", "nadadeiras", "prancha"],
            ["pull_buoy", "palmares", "nadadeiras", "prancha"],
        ]
        let faixas: [(Int, Int)] = [
            (400, 800), (800, 1200), (1000, 2000), (1500, 2500),
            (2000, 2000), (2500, 4000), (3000, 6000), (600, 600),
        ]

        return (0..<500).map { indice in
            let raia = raias[indice % raias.count]
            let equipamentos = equipamentosPossiveis[(indice / 3) % equipamentosPossiveis.count]
            let faixa = faixas[(indice / 7) % faixas.count]
            let educativos = (indice / 2) % 2 == 0
            let pernada = (indice / 5) % 2 == 0
            let semente = SeededRandomNumberGenerator.seed(from: [
                "\(indice)", "\(raia)", "\(faixa.0)-\(faixa.1)",
                equipamentos.sorted().joined(separator: ","),
                "\(educativos)", "\(pernada)",
            ])
            return Caso(
                semente: semente, minM: faixa.0, maxM: faixa.1, equipamentos: equipamentos,
                educativos: educativos, pernada: pernada, raiaM: raia)
        }
    }()

    /// Gera um treino para um caso.
    private func gerar(_ caso: Caso, catalogo: CatalogStore) -> GenerationResult {
        let adaptado = AdaptedCatalog(
            catalogo: catalogo.allExercises, tamanhoRaiaM: caso.raiaM)
        var rng = SeededRandomNumberGenerator(seed: caso.semente)
        return WorkoutGenerator(catalogo: adaptado).gerar(
            GenerationRequest(
                minMeters: caso.minM, maxMeters: caso.maxM,
                selectedEquipment: caso.equipamentos,
                includeDrills: caso.educativos, includeKick: caso.pernada,
                laneLengthM: caso.raiaM, restPace: .normal),
            using: &rng)
    }

    // MARK: - As 500 gerações

    @Test("500 gerações com sementes variadas não violam nenhum critério do 8.4")
    func quinhentasGeracoes() throws {
        let catalogo = try CatalogStore()
        let ativos = Set(catalogo.allExercises.filter(\.ativo).map(\.exercicio_id))
        var violacoes: [String] = []

        for caso in Self.casos {
            let treino = gerar(caso, catalogo: catalogo)

            func exigir(_ condicao: Bool, _ mensagem: @autoclosure () -> String) {
                if !condicao { violacoes.append("[\(caso)] \(mensagem())") }
            }

            // Regra 11.1 — quatro seções sempre, na ordem, inclusive vazias.
            exigir(treino.secoes.count == 4, "não tem 4 seções")
            exigir(treino.secoes.map(\.tipo) == TipoSecao.allCases, "seções fora de ordem")

            // Regra 11.2 — o teto é rígido; o piso pode ceder (decisão da Q5).
            exigir(treino.totalM <= caso.maxM, "total \(treino.totalM) passou do teto \(caso.maxM)")
            if !treino.trace.aceitouAbaixoDoMinimo {
                exigir(
                    treino.totalM >= caso.minM,
                    "total \(treino.totalM) abaixo do piso \(caso.minM) sem marcar o trace")
            }

            // O total declarado é a soma real das séries, sobre a distância
            // ADAPTADA (regras 11.2 e 11.3).
            let somaDasSeries = treino.secoes.reduce(0) { $0 + $1.metrosTotais }
            exigir(
                treino.totalM == somaDasSeries,
                "total \(treino.totalM) != soma das séries \(somaDasSeries)")

            for secao in treino.secoes {
                for (indice, serie) in secao.series.enumerated() {
                    let onde = "\(secao.tipo.rawValue)/\(serie.exercicioId)"

                    // Só sorteia exercício ativo (critério 8.4).
                    exigir(ativos.contains(serie.exercicioId), "\(onde) não está ativo")

                    // Regra 11.3 — distância real, múltiplo exato da raia.
                    exigir(
                        serie.distanciaM % caso.raiaM == 0,
                        "\(onde): \(serie.distanciaM) m não é múltiplo de \(caso.raiaM)")
                    exigir(
                        serie.voltasPorRepeticao >= 1, "\(onde): voltas < 1")
                    exigir(
                        serie.distanciaM == serie.voltasPorRepeticao * caso.raiaM,
                        "\(onde): distância != voltas × raia")
                    exigir(
                        serie.metrosTotais == serie.repeticoes * serie.distanciaM,
                        "\(onde): metros_totais não bate com a distância REAL")

                    // A guarda de desvio de 25% (assunção 24.3b).
                    exigir(
                        LaneAdapter.desvioAceitavel(
                            distanciaCatalogoM: serie.distanciaCatalogoM,
                            distanciaAdaptadaM: serie.distanciaM),
                        "\(onde): desvio acima de 25%")

                    // O snapshot do catálogo é o original, não o adaptado.
                    let original = catalogo.exercise(id: serie.exercicioId)
                    exigir(
                        serie.distanciaCatalogoM == original?.distancia_m,
                        "\(onde): distancia_catalogo_m não é a do catálogo")

                    // Equipamento respeitado (critério 8.4).
                    exigir(
                        serie.equipamentoExigido == "nenhum"
                            || caso.equipamentos.contains(serie.equipamentoExigido),
                        "\(onde): equipamento \(serie.equipamentoExigido) não foi marcado")

                    // Interruptores respeitados (critério 8.4).
                    if serie.modo == .educativo {
                        exigir(caso.educativos, "\(onde): educativo com o interruptor desligado")
                    }
                    if serie.modo == .pernada {
                        exigir(caso.pernada, "\(onde): pernada com o interruptor desligado")
                    }

                    // Descanso e voltas preenchidos (critério 8.4).
                    exigir(
                        serie.repeticoes > 1
                            ? (10...90).contains(serie.descansoSeg)
                            : serie.descansoSeg == 0,
                        "\(onde): descanso \(serie.descansoSeg)s com \(serie.repeticoes) repetições")

                    // Regra 11.6 — zero na última série da seção, valor nas
                    // outras.
                    let ehUltima = indice == secao.series.count - 1
                    exigir(
                        ehUltima
                            ? serie.descansoPosSerieSeg == 0
                            : serie.descansoPosSerieSeg == RestCalculator.descansoEntreSeries(
                                ritmo: .normal),
                        "\(onde): descanso pós-série errado")

                    // Ordem contígua a partir de 1 (spec 7.11).
                    exigir(serie.ordem == indice + 1, "\(onde): ordem \(serie.ordem) fora de série")
                }
            }

            // Regra 11.6 — a última seção COM SÉRIE não tem descanso depois, e
            // seção vazia também não.
            let ultimaComSerie = treino.secoes.last { !$0.series.isEmpty }?.tipo
            for secao in treino.secoes {
                let deveSerZero = secao.series.isEmpty || secao.tipo == ultimaComSerie
                exigir(
                    deveSerZero
                        ? secao.descansoPosSecaoSeg == 0
                        : secao.descansoPosSecaoSeg == RestCalculator.descansoEntreSecoes(
                            ritmo: .normal),
                    "seção \(secao.tipo.rawValue): descanso pós-seção errado")
            }
        }

        #expect(
            violacoes.isEmpty,
            """
            \(violacoes.count) violações em \(Self.casos.count) gerações:
            \(violacoes.prefix(20).joined(separator: "\n"))
            """)
    }

    // MARK: - Determinismo e desempenho

    @Test("A mesma semente devolve sempre o mesmo treino (contrato 13.1)")
    func geracaoEhDeterministica() throws {
        let catalogo = try CatalogStore()
        let caso = Self.casos[42]
        let primeira = gerar(caso, catalogo: catalogo)
        for _ in 0..<20 {
            #expect(gerar(caso, catalogo: catalogo) == primeira)
        }
    }

    @Test("Sementes diferentes produzem treinos diferentes")
    func sementesDiferentesVariam() throws {
        // Se o motor devolvesse sempre o mesmo treino, todos os testes acima
        // passariam e o produto seria inútil.
        let catalogo = try CatalogStore()
        let variantes = Set(
            (0..<40).map { indice in
                gerar(Self.casos[indice], catalogo: catalogo).allExerciseIds.joined(separator: ",")
            })
        #expect(variantes.count > 30, "só \(variantes.count) treinos distintos em 40 gerações")
    }

    @Test("Geração em 1 segundo ou menos (requisito 17.2)")
    func geracaoRapida() throws {
        let catalogo = try CatalogStore()
        // Mede o pior caso conhecido: raia de 33 m, que derruba 93 exercícios e
        // força mais tentativas, com faixa larga.
        let caso = Caso(
            semente: 12345, minM: 3000, maxM: 6000, equipamentos: [],
            educativos: false, pernada: false, raiaM: 33)

        let inicio = ContinuousClock.now
        _ = gerar(caso, catalogo: catalogo)
        let duracao = ContinuousClock.now - inicio

        #expect(duracao < .seconds(1), "geração levou \(duracao)")
    }
}
