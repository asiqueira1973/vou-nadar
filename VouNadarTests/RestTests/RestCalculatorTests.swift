import Foundation
import Testing

@testable import VouNadar

/// A tabela de descanso (regras 11.5 e 11.6) — critérios de aceite do épico 8.2.
///
/// A regra 11.5 é o núcleo do produto junto com a 11.3: é ela que separa o Vou
/// Nadar de um gerador de lista. Sem descanso definido não existe tela de borda,
/// não existe contagem regressiva e não existe execução guiada (princípio 0.2).
/// Por isso ela é testada contra o catálogo real, e não contra exemplos
/// inventados.
struct RestCalculatorTests {

    private func catalogo() throws -> CatalogStore { try CatalogStore() }

    // MARK: - Os sete exemplos da tabela da regra 11.5

    @Test("CD_08x25 — 8×25 soltura/nado: 15 × 0,75 × 1,0 = 11,25 → 10 s")
    func exemploSolturaCurta() throws {
        let e = try #require(try catalogo().exercise(id: "CD_08x25"))
        #expect(e.distancia_m == 25)
        #expect(e.intensidade == .soltura)
        #expect(e.modo == .nado)
        #expect(
            RestCalculator.descansoSegundos(
                distanciaM: e.distancia_m, intensidade: e.intensidade, modo: e.modo, ritmo: .normal)
                == 10)
    }

    @Test("ED_04x25_CATCHUP — 4×25 aquecimento/educativo: 15 × 0,75 × 0,75 = 8,4 → 10 s (piso)")
    func exemploEducativoNoPiso() throws {
        let e = try #require(try catalogo().exercise(id: "ED_04x25_CATCHUP"))
        #expect(e.distancia_m == 25)
        #expect(e.intensidade == .aquecimento)
        #expect(e.modo == .educativo)
        #expect(
            RestCalculator.descansoSegundos(
                distanciaM: e.distancia_m, intensidade: e.intensidade, modo: e.modo, ritmo: .normal)
                == 10)
    }

    @Test("4×50 aeróbico/nado: 20 × 1,0 × 1,0 = 20 → 20 s")
    func exemploAerobicoNado() {
        #expect(
            RestCalculator.descansoSegundos(
                distanciaM: 50, intensidade: .aerobico, modo: .nado, ritmo: .normal) == 20)
    }

    @Test("6×50 aeróbico/pernada: 20 × 1,0 × 1,25 = 25 → 25 s")
    func exemploAerobicoPernada() {
        #expect(
            RestCalculator.descansoSegundos(
                distanciaM: 50, intensidade: .aerobico, modo: .pernada, ritmo: .normal) == 25)
    }

    @Test("3×100 resistência/nado: 30 × 1,25 × 1,0 = 37,5 → 40 s")
    func exemploResistenciaArredondaParaCima() {
        // 37,5 tem que virar 40, não 35: é o caso que prova que o
        // arredondamento é meio-para-cima e não bancário.
        #expect(
            RestCalculator.descansoSegundos(
                distanciaM: 100, intensidade: .resistencia, modo: .nado, ritmo: .normal) == 40)
    }

    @Test("2×200 moderado/nado: 45 × 1,0 × 1,0 = 45 → 45 s")
    func exemploModeradoLongo() {
        #expect(
            RestCalculator.descansoSegundos(
                distanciaM: 200, intensidade: .moderado, modo: .nado, ritmo: .normal) == 45)
    }

    @Test("KI_01x300_PRANCHA — 1×300 aeróbico/pernada: 60 × 1,0 × 1,25 = 75 → 75 s")
    func exemploPernadaLonga() throws {
        let e = try #require(try catalogo().exercise(id: "KI_01x300_PRANCHA"))
        #expect(e.distancia_m == 300)
        #expect(e.intensidade == .aerobico)
        #expect(e.modo == .pernada)
        #expect(
            RestCalculator.descansoSegundos(
                distanciaM: e.distancia_m, intensidade: e.intensidade, modo: e.modo, ritmo: .normal)
                == 75)
    }

    // MARK: - Varredura sobre os 226 exercícios reais (critério 8.2)

    @Test("Nenhum dos 226 sai de 10–90 s em nenhum dos três ritmos (critério 8.2)")
    func nenhumValorForaDosLimites() throws {
        let catalogo = try catalogo()
        for e in catalogo.allExercises {
            for ritmo in RitmoDescanso.allCases {
                let descanso = RestCalculator.descansoSegundos(
                    distanciaM: e.distancia_m, intensidade: e.intensidade, modo: e.modo,
                    ritmo: ritmo)
                #expect(
                    (10...90).contains(descanso),
                    "\(e.exercicio_id) no ritmo \(ritmo.rawValue): \(descanso)s fora de 10–90")
            }
        }
    }

    @Test("Todo descanso é múltiplo de 5 (regra 11.5)")
    func todosMultiplosDeCinco() throws {
        let catalogo = try catalogo()
        for e in catalogo.allExercises {
            for ritmo in RitmoDescanso.allCases {
                let descanso = RestCalculator.descansoSegundos(
                    distanciaM: e.distancia_m, intensidade: e.intensidade, modo: e.modo,
                    ritmo: ritmo)
                #expect(descanso % 5 == 0, "\(e.exercicio_id) no \(ritmo.rawValue): \(descanso)s")
            }
        }
    }

    @Test("A amplitude por ritmo bate com a verificação declarada na regra 11.5")
    func amplitudePorRitmo() throws {
        let catalogo = try catalogo()

        func amplitude(_ ritmo: RitmoDescanso) -> (min: Int, max: Int) {
            let valores = catalogo.allExercises.map {
                RestCalculator.descansoSegundos(
                    distanciaM: $0.distancia_m, intensidade: $0.intensidade, modo: $0.modo,
                    ritmo: ritmo)
            }
            return (valores.min() ?? 0, valores.max() ?? 0)
        }

        // "10 a 75 s no ritmo normal, 10 a 55 s no curto, 15 a 90 s no longo."
        #expect(amplitude(.curto) == (10, 55))
        #expect(amplitude(.normal) == (10, 75))
        #expect(amplitude(.longo) == (15, 90))
    }

    @Test("Só o ritmo longo encosta no teto de 90 s (regra 11.5)")
    func tetoSoNoRitmoLongo() throws {
        let catalogo = try catalogo()
        for ritmo in [RitmoDescanso.curto, .normal] {
            let encostou = catalogo.allExercises.contains {
                RestCalculator.descansoSegundos(
                    distanciaM: $0.distancia_m, intensidade: $0.intensidade, modo: $0.modo,
                    ritmo: ritmo) == 90
            }
            #expect(!encostou, "o ritmo \(ritmo.rawValue) bateu no teto de 90 s")
        }
    }

    // MARK: - A leitura da tabela fora das linhas dela

    @Test("A adaptação à raia não muda o descanso de nenhum exercício (regras 11.3 e 11.5)")
    func descansoNaoMudaComAAdaptacaoDaRaia() throws {
        // Este é o teste que sustenta a decisão de ler a tabela pela LINHA MAIS
        // PRÓXIMA, documentada em `RestCalculator.base`. A regra 11.5 diz
        // `base(distancia_m)` e a 11.3 muda `distancia_m` conforme a piscina;
        // a tabela é discreta e 96 m não é linha dela.
        //
        // A propriedade que torna isso seguro: a guarda de desvio de 25%
        // (assunção 24.3b) tira do sorteio exatamente os exercícios que a
        // adaptação empurraria para outra linha. Se um catálogo futuro ou uma
        // raia nova quebrarem isso, este teste reprova — em vez de o descanso
        // de todo mundo mudar em silêncio.
        let catalogo = try catalogo()
        let raias = [10, 12, 15, 16, 18, 20, 25, 50]

        for raia in raias {
            for e in catalogo.allExercises {
                let voltas = LaneAdapter.voltasPorRepeticao(
                    distanciaCatalogoM: e.distancia_m, tamanhoRaiaM: raia)
                let adaptada = voltas * raia
                guard
                    LaneAdapter.desvioAceitavel(
                        distanciaCatalogoM: e.distancia_m, distanciaAdaptadaM: adaptada)
                else { continue }

                for ritmo in RitmoDescanso.allCases {
                    let comCatalogo = RestCalculator.descansoSegundos(
                        distanciaM: e.distancia_m, intensidade: e.intensidade, modo: e.modo,
                        ritmo: ritmo)
                    let comAdaptada = RestCalculator.descansoSegundos(
                        distanciaM: adaptada, intensidade: e.intensidade, modo: e.modo, ritmo: ritmo)
                    #expect(
                        comCatalogo == comAdaptada,
                        """
                        \(e.exercicio_id) em raia de \(raia) m, ritmo \(ritmo.rawValue): \
                        catálogo \(e.distancia_m) m → \(comCatalogo)s, \
                        adaptado \(adaptada) m → \(comAdaptada)s
                        """)
                }
            }
        }
    }

    @Test("Empate na tabela resolve para a linha maior, isto é, mais descanso")
    func empateResolveParaMaisDescanso() {
        // 125 m fica a 25 m de 100 e de 150. Distância maior com descanso a
        // menos é o erro que machuca o nadador; o contrário só o deixa
        // esperando.
        #expect(RestCalculator.base(distanciaM: 125) == 40)
        #expect(RestCalculator.base(distanciaM: 225) == 50)
    }

    @Test("Distância de 300 m ou mais usa sempre a última linha, 60 s (regra 11.5)")
    func linhaAbertaADireita() {
        #expect(RestCalculator.base(distanciaM: 300) == 60)
        #expect(RestCalculator.base(distanciaM: 800) == 60)
        // O catálogo vai até 1500 m por repetição.
        #expect(RestCalculator.base(distanciaM: 1500) == 60)
    }

    // MARK: - Regra 11.6

    @Test("Descanso entre séries: 25 s curto, 30 s normal, 45 s longo (regra 11.6)")
    func descansoEntreSeriesPorRitmo() {
        // 30 × 0,75 = 22,5, e o múltiplo de 5 mais próximo é 25 — meio para
        // cima, o mesmo arredondamento que o exemplo `37,5 → 40` da regra 11.5
        // exige. Arredondamento bancário devolveria 20, e está errado aqui.
        #expect(RestCalculator.descansoEntreSeries(ritmo: .curto) == 25)
        #expect(RestCalculator.descansoEntreSeries(ritmo: .normal) == 30)
        #expect(RestCalculator.descansoEntreSeries(ritmo: .longo) == 45)
    }

    @Test("Descanso entre seções: 35 s curto, 45 s normal, 70 s longo (regra 11.6)")
    func descansoEntreSecoesPorRitmo() {
        #expect(RestCalculator.descansoEntreSecoes(ritmo: .curto) == 35)
        #expect(RestCalculator.descansoEntreSecoes(ritmo: .normal) == 45)
        #expect(RestCalculator.descansoEntreSecoes(ritmo: .longo) == 70)
    }

    @Test("Os valores nominais da 11.6 são os da assunção 24.6: 30 s e 45 s")
    func valoresNominaisDaRegra116() {
        #expect(RestCalculator.baseEntreSeries == 30)
        #expect(RestCalculator.baseEntreSecoes == 45)
    }

    // MARK: - Pureza (contrato 13.2)

    @Test("A função é pura: a mesma entrada devolve sempre a mesma saída")
    func funcaoEhDeterministica() {
        let primeira = RestCalculator.descansoSegundos(
            distanciaM: 100, intensidade: .resistencia, modo: .pernada, ritmo: .longo)
        for _ in 0..<100 {
            #expect(
                RestCalculator.descansoSegundos(
                    distanciaM: 100, intensidade: .resistencia, modo: .pernada, ritmo: .longo)
                    == primeira)
        }
    }

    @Test("Os multiplicadores são exatamente os da regra 11.5")
    func multiplicadoresLiterais() {
        #expect(RestCalculator.multiplicador(intensidade: .aquecimento) == 0.75)
        #expect(RestCalculator.multiplicador(intensidade: .soltura) == 0.75)
        #expect(RestCalculator.multiplicador(intensidade: .moderado) == 1.0)
        #expect(RestCalculator.multiplicador(intensidade: .aerobico) == 1.0)
        #expect(RestCalculator.multiplicador(intensidade: .variavel) == 1.0)
        #expect(RestCalculator.multiplicador(intensidade: .resistencia) == 1.25)

        #expect(RestCalculator.multiplicador(modo: .nado) == 1.0)
        #expect(RestCalculator.multiplicador(modo: .bracada) == 1.0)
        #expect(RestCalculator.multiplicador(modo: .educativo) == 0.75)
        #expect(RestCalculator.multiplicador(modo: .pernada) == 1.25)

        #expect(RitmoDescanso.curto.multiplicador == 0.75)
        #expect(RitmoDescanso.normal.multiplicador == 1.0)
        #expect(RitmoDescanso.longo.multiplicador == 1.5)
    }
}
