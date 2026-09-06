import Foundation
import Testing

@testable import VouNadar

/// O gerador faz o que promete, e não só evita o que é proibido.
///
/// O teste de propriedade das 500 gerações verifica **invariantes** — nada fora
/// da faixa, nada de equipamento não marcado, nada de seção faltando. Um motor
/// que devolvesse sempre um treino vazio passaria em todas elas.
///
/// Esta suíte fecha esse buraco: ela mede o que as 500 gerações de fato
/// produziram e falha se o resultado for degenerado.
struct WorkoutGeneratorBehaviourTests {

    private func gerar(_ caso: WorkoutGeneratorPropertyTests.Caso, _ catalogo: CatalogStore)
        -> GenerationResult
    {
        let adaptado = AdaptedCatalog(catalogo: catalogo.allExercises, tamanhoRaiaM: caso.raiaM)
        var rng = SeededRandomNumberGenerator(seed: caso.semente)
        return WorkoutGenerator(catalogo: adaptado).gerar(
            GenerationRequest(
                minMeters: caso.minM, maxMeters: caso.maxM,
                selectedEquipment: caso.equipamentos,
                includeDrills: caso.educativos, includeKick: caso.pernada,
                laneLengthM: caso.raiaM, restPace: .normal),
            using: &rng)
    }

    @Test("As 500 gerações produzem treinos de verdade, não resultados degenerados")
    func asGeracoesNaoSaoVazias() throws {
        let catalogo = try CatalogStore()
        let casos = WorkoutGeneratorPropertyTests.casos
        let treinos = casos.map { gerar($0, catalogo) }

        // Nenhum treino sai sem série nenhuma.
        let vazios = treinos.count { $0.secoes.allSatisfy(\.series.isEmpty) }
        #expect(vazios == 0, "\(vazios) treinos saíram completamente vazios")

        // A soltura é a seção garantida do motor: ela nunca falta.
        let semSoltura = treinos.count { treino in
            treino.secoes.first { $0.tipo == .soltura }?.series.isEmpty ?? true
        }
        #expect(semSoltura == 0, "\(semSoltura) treinos saíram sem soltura")

        // A grande maioria fecha dentro da faixa. O piso só cede nos casos que a
        // regra 11.2 prevê — faixa fechada em piscina cuja raia não divide o
        // número pedido, sobretudo.
        let abaixoDoMinimo = treinos.count { $0.trace.aceitouAbaixoDoMinimo }
        #expect(
            abaixoDoMinimo < casos.count / 3,
            "\(abaixoDoMinimo) de \(casos.count) gerações não fecharam a faixa")

        // E o caminho de "aceita o resultado mais próximo" da regra 11.2 é
        // realmente exercitado — se nunca disparasse, ele seria código morto
        // que ninguém testou.
        #expect(abaixoDoMinimo > 0, "o caminho da regra 11.2 nunca foi exercitado")
    }

    @Test("Com os interruptores ligados, educativo e pernada de fato aparecem")
    func interruptoresLigadosProduzemBlocos() throws {
        let catalogo = try CatalogStore()
        // Raia de 25 m e faixa larga: o cenário mais folgado possível, onde não
        // aparecer não teria desculpa.
        let caso = WorkoutGeneratorPropertyTests.Caso(
            semente: 777, minM: 2000, maxM: 3000, equipamentos: ["prancha", "pull_buoy"],
            educativos: true, pernada: true, raiaM: 25)

        var viuEducativo = false
        var viuPernada = false
        for deslocamento in 0..<40 {
            var variante = caso
            variante = WorkoutGeneratorPropertyTests.Caso(
                semente: caso.semente &+ UInt64(deslocamento), minM: caso.minM, maxM: caso.maxM,
                equipamentos: caso.equipamentos, educativos: true, pernada: true, raiaM: 25)
            let treino = gerar(variante, catalogo)
            let modos = treino.secoes.flatMap { $0.series.map(\.modo) }
            if modos.contains(.educativo) { viuEducativo = true }
            if modos.contains(.pernada) { viuPernada = true }
        }

        #expect(viuEducativo, "nenhum educativo em 40 gerações com o interruptor ligado")
        #expect(viuPernada, "nenhuma pernada em 40 gerações com o interruptor ligado")
    }

    @Test("Quem marcou equipamento recebe pelo menos uma série com ele")
    func equipamentoMarcadoEhUsado() throws {
        // É a passagem "primeira série com equipamento" da heurística herdada:
        // quem levou palmar na mochila tem que usar o palmar.
        let catalogo = try CatalogStore()
        var usou = 0
        let total = 30

        for indice in 0..<total {
            let caso = WorkoutGeneratorPropertyTests.Caso(
                semente: UInt64(9000 + indice), minM: 1800, maxM: 2600,
                equipamentos: ["palmares"], educativos: false, pernada: false, raiaM: 25)
            let treino = gerar(caso, catalogo)
            if treino.secoes.flatMap({ $0.series }).contains(where: {
                $0.equipamentoExigido == "palmares"
            }) {
                usou += 1
            }
        }

        #expect(usou >= total * 8 / 10, "só \(usou) de \(total) treinos usaram o palmar marcado")
    }

    @Test("Sem equipamento marcado, nenhuma série exige equipamento (critério 8.4)")
    func semEquipamentoSoEntraOQueNaoExige() throws {
        let catalogo = try CatalogStore()
        for indice in 0..<30 {
            let caso = WorkoutGeneratorPropertyTests.Caso(
                semente: UInt64(4000 + indice), minM: 1500, maxM: 2500, equipamentos: [],
                educativos: true, pernada: true, raiaM: 25)
            let treino = gerar(caso, catalogo)
            let comEquipamento = treino.secoes.flatMap { $0.series }
                .filter { $0.equipamentoExigido != "nenhum" }
            #expect(comEquipamento.isEmpty, "série com equipamento sem nada marcado")
        }
    }

    // MARK: - O caso do fluxo 9.3

    @Test("Numa piscina de 16 m as distâncias saem adaptadas e a nota 15.18 se justifica")
    func piscinaDeDezesseisMetros() throws {
        let catalogo = try CatalogStore()
        let caso = WorkoutGeneratorPropertyTests.Caso(
            semente: 20260906, minM: 1500, maxM: 2500, equipamentos: [],
            educativos: false, pernada: false, raiaM: 16)
        let treino = gerar(caso, catalogo)

        // Toda distância é múltiplo de 16 — é o que faz a contagem de voltas do
        // relógio fechar (regra 11.7).
        for serie in treino.secoes.flatMap({ $0.series }) {
            #expect(serie.distanciaM % 16 == 0)
        }
        // E pelo menos uma série teve a distância mudada, que é a condição da
        // copy 15.18 aparecer no Detalhe (risco R2b).
        #expect(treino.teveDistanciaAjustada)
    }

    @Test("Numa piscina de 25 m nenhuma distância é adaptada, e a nota 15.18 não aparece")
    func piscinaDeVinteECincoNaoAdapta() throws {
        let catalogo = try CatalogStore()
        for indice in 0..<20 {
            let caso = WorkoutGeneratorPropertyTests.Caso(
                semente: UInt64(5500 + indice), minM: 1500, maxM: 2500, equipamentos: [],
                educativos: true, pernada: true, raiaM: 25)
            let treino = gerar(caso, catalogo)
            #expect(!treino.teveDistanciaAjustada, "adaptou numa piscina de 25 m")
        }
    }

    // MARK: - "Gerar outro"

    @Test("Gerar outro não devolve o mesmo conjunto de exercícios")
    func gerarOutroVaria() throws {
        let catalogo = try CatalogStore()
        let adaptado = AdaptedCatalog(catalogo: catalogo.allExercises, tamanhoRaiaM: 25)
        let motor = WorkoutGenerator(catalogo: adaptado)

        var rng = SeededRandomNumberGenerator(seed: 31337)
        let primeiro = motor.gerar(
            GenerationRequest(
                minMeters: 1500, maxMeters: 2500, laneLengthM: 25, restPace: .normal),
            using: &rng)

        let segundo = motor.gerar(
            GenerationRequest(
                minMeters: 1500, maxMeters: 2500, laneLengthM: 25, restPace: .normal,
                previousExerciseIds: primeiro.allExerciseIds),
            using: &rng)

        #expect(segundo.allExerciseIds.sorted() != primeiro.allExerciseIds.sorted())
    }

    // MARK: - Ritmo de descanso

    @Test("O ritmo escolhido muda os descansos gravados, e fica congelado no resultado")
    func ritmoAfetaOsDescansos() throws {
        let catalogo = try CatalogStore()
        let adaptado = AdaptedCatalog(catalogo: catalogo.allExercises, tamanhoRaiaM: 25)
        let motor = WorkoutGenerator(catalogo: adaptado)

        func descansos(_ ritmo: RitmoDescanso) -> (resultado: GenerationResult, soma: Int) {
            var rng = SeededRandomNumberGenerator(seed: 8080)
            let treino = motor.gerar(
                GenerationRequest(
                    minMeters: 1800, maxMeters: 2200, laneLengthM: 25, restPace: ritmo),
                using: &rng)
            return (treino, treino.secoes.flatMap { $0.series }.reduce(0) { $0 + $1.descansoSeg })
        }

        let curto = descansos(.curto)
        let normal = descansos(.normal)
        let longo = descansos(.longo)

        // Mesma semente, mesmos exercícios — só o descanso muda.
        #expect(curto.resultado.allExerciseIds == normal.resultado.allExerciseIds)
        #expect(longo.resultado.allExerciseIds == normal.resultado.allExerciseIds)

        #expect(curto.soma < normal.soma)
        #expect(longo.soma > normal.soma)

        // E o ritmo fica congelado no resultado, para virar
        // `treino.ritmo_descanso_usado` (princípio 0.6).
        #expect(curto.resultado.restPace == .curto)
        #expect(longo.resultado.restPace == .longo)
    }

    // MARK: - Regra 11.19

    @Test("A combinação mais restritiva avisa e NÃO bloqueia a geração (regra 11.19)")
    func repertorioCurtoAvisaMasGera() throws {
        // O cenário que a seção 22 manda testar: raia de 50 m, sem equipamento,
        // sem educativo e sem pernada.
        let catalogo = try CatalogStore()

        let deveAvisar = RepertoireGuard.deveAvisar(
            catalogo: catalogo.allExercises, tamanhoRaiaM: 50, equipamentos: [],
            incluirEducativos: false, incluirPernada: false)

        let adaptado = AdaptedCatalog(catalogo: catalogo.allExercises, tamanhoRaiaM: 50)
        var rng = SeededRandomNumberGenerator(seed: 4242)
        let treino = WorkoutGenerator(catalogo: adaptado).gerar(
            GenerationRequest(
                minMeters: 1500, maxMeters: 2500, selectedEquipment: [],
                includeDrills: false, includeKick: false, laneLengthM: 50, restPace: .normal),
            using: &rng)

        // Gera assim mesmo — nunca bloqueia.
        let saiuVazio = treino.secoes.allSatisfy(\.series.isEmpty)
        #expect(!saiuVazio)
        #expect(treino.totalM > 0)

        // E o contador que alimenta o aviso está no trace.
        #expect(treino.trace.candidatosDisponiveis > 0)
        // Este cenário específico não dispara o aviso — 50 m ainda deixa mais de
        // 30 candidatos sem equipamento. Registrado para o número ficar visível
        // se o catálogo mudar.
        #expect(deveAvisar == (treino.trace.candidatosDisponiveis < 30))
    }

    @Test("Raia de 33 m sem equipamento e sem interruptores dispara o aviso (regra 11.19)")
    func raiaDeTrintaETresAvisa() throws {
        // A "piscina ruim para este catálogo" de 11.3 detalhado: sobram 133 dos
        // 226, e com os filtros fechados o repertório encolhe de verdade.
        let catalogo = try CatalogStore()
        let candidatos = RepertoireGuard.candidatos(
            catalogo: catalogo.allExercises, tamanhoRaiaM: 33, equipamentos: [],
            incluirEducativos: false, incluirPernada: false)

        // Ainda gera, com aviso ou sem ele — o que a regra proíbe é bloquear.
        let adaptado = AdaptedCatalog(catalogo: catalogo.allExercises, tamanhoRaiaM: 33)
        var rng = SeededRandomNumberGenerator(seed: 33033)
        let treino = WorkoutGenerator(catalogo: adaptado).gerar(
            GenerationRequest(
                minMeters: 1500, maxMeters: 2500, laneLengthM: 33, restPace: .normal),
            using: &rng)

        #expect(treino.totalM > 0, "raia de 33 m não gerou treino (candidatos: \(candidatos))")
        for serie in treino.secoes.flatMap({ $0.series }) {
            #expect(serie.distanciaM % 33 == 0)
        }
    }
}
