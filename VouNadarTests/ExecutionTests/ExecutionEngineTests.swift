import Foundation
import Testing

@testable import VouNadar

/// A máquina de estados da execução (épico 8.8, máquina 12.2, regras 11.7 a
/// 11.10).
///
/// **É o teste que substitui a piscina para tudo que não depende da água.** A
/// seção 22 pede "contagem de voltas com distâncias simuladas, sem HealthKit
/// real", e é isso que estes casos fazem: alimentam voltas e segundos, e
/// afirmam estado e háptico.
///
/// O que eles **não** cobrem, e nenhum teste automatizado cobre: se o HealthKit
/// entrega o evento de volta a tempo (risco R3) e se o Water Lock se comporta
/// como esperado. Isso é o teste manual em piscina do Definition of Done.
struct ExecutionEngineTests {

    // MARK: - Planos de teste

    private func serie(
        _ indice: Int, repeticoes: Int, voltas: Int, descanso: Int, descansoDepois: Int,
        secao: TipoSecao = .principal
    ) -> ExecutionPlan.SeriePlanejada {
        ExecutionPlan.SeriePlanejada(
            indice: indice, secao: secao, nome: "Série \(indice)",
            repeticoes: repeticoes, distanciaM: voltas * 25, voltasPorRepeticao: voltas,
            descansoSeg: descanso, descansoDepoisSeg: descansoDepois)
    }

    /// `4×100` em raia de 25 m: 4 repetições de 4 voltas, 30 s de descanso.
    private var planoDeUmaSerie: ExecutionPlan {
        ExecutionPlan(
            series: [serie(0, repeticoes: 4, voltas: 4, descanso: 30, descansoDepois: 0)],
            tamanhoRaiaM: 25)
    }

    /// Duas séries, com 45 s entre elas.
    private var planoDeDuasSeries: ExecutionPlan {
        ExecutionPlan(
            series: [
                serie(0, repeticoes: 2, voltas: 2, descanso: 20, descansoDepois: 45),
                serie(1, repeticoes: 2, voltas: 4, descanso: 30, descansoDepois: 0),
            ],
            tamanhoRaiaM: 25)
    }

    /// Nada `quantas` voltas e devolve todos os hápticos, na ordem.
    @discardableResult
    private func nadar(_ voltas: Int, _ motor: inout ExecutionEngine) -> [ExecutionEngine.Haptico] {
        (0..<voltas).flatMap { _ in motor.processar(.voltaCompletada) }
    }

    /// Deixa passar `segundos` e devolve os hápticos.
    @discardableResult
    private func esperar(_ segundos: Int, _ motor: inout ExecutionEngine)
        -> [ExecutionEngine.Haptico]
    {
        (0..<segundos).flatMap { _ in motor.processar(.segundo) }
    }

    // MARK: - Regra 11.7: fim da repetição

    @Test("A repetição termina exatamente na volta prevista, nem antes nem depois")
    func repeticaoTerminaNaVoltaPrevista() {
        var motor = ExecutionEngine(plano: planoDeUmaSerie)
        motor.comecar()

        // Três voltas: ainda nadando na primeira repetição.
        nadar(3, &motor)
        #expect(motor.estado == .nadando(.init(serie: 0, repeticao: 1, voltasNaRepeticao: 3)))
        #expect(motor.repeticoesConcluidas == 0)

        // A quarta fecha a repetição e entra em descanso.
        let hapticos = nadar(1, &motor)
        #expect(hapticos == [.entradaEmDescanso])
        #expect(motor.repeticoesConcluidas == 1)
        if case .descansando(let d) = motor.estado {
            #expect(d.restanteSeg == 30)
            #expect(d.proxima.repeticao == 2)
        } else {
            Issue.record("deveria estar descansando, está \(motor.estado)")
        }
    }

    @Test("O treino inteiro avança repetição a repetição até concluir")
    func treinoInteiro() {
        var motor = ExecutionEngine(plano: planoDeUmaSerie)
        motor.comecar()

        // 4 repetições de 4 voltas, com 30 s de descanso entre elas.
        for repeticao in 1...4 {
            nadar(4, &motor)
            if repeticao < 4 {
                esperar(30, &motor)
            }
        }

        #expect(motor.estado == .concluido)
        #expect(motor.repeticoesConcluidas == 4)
        #expect(motor.seriesConcluidas == 1)
        #expect(motor.voltasTotais == 16)
        #expect(motor.metrosPercorridos == 400)
    }

    // MARK: - Regra 11.6: descanso entre séries e entre seções

    @Test("Entre séries vale o descanso depois da série, não o interno")
    func descansoEntreSeries() {
        var motor = ExecutionEngine(plano: planoDeDuasSeries)
        motor.comecar()

        // Primeira série: 2 repetições de 2 voltas, 20 s entre elas.
        nadar(2, &motor)
        if case .descansando(let d) = motor.estado {
            #expect(d.restanteSeg == 20, "descanso INTERNO da série")
        } else {
            Issue.record("deveria estar descansando")
        }
        esperar(20, &motor)

        // Segunda repetição fecha a série: agora vale o descanso DEPOIS.
        nadar(2, &motor)
        if case .descansando(let d) = motor.estado {
            #expect(d.restanteSeg == 45, "descanso DEPOIS da série")
            #expect(d.proxima.serie == 1)
            #expect(d.proxima.repeticao == 1)
        } else {
            Issue.record("deveria estar descansando entre séries")
        }
        #expect(motor.seriesConcluidas == 1)
    }

    @Test("Descanso zero não gera háptico e segue direto (regra 11.9)")
    func descansoZeroSegueDireto() {
        // Uma série de 2 repetições sem descanso interno — o caso de uma série
        // de repetição única encadeada.
        let plano = ExecutionPlan(
            series: [
                serie(0, repeticoes: 1, voltas: 2, descanso: 0, descansoDepois: 0),
                serie(1, repeticoes: 1, voltas: 2, descanso: 0, descansoDepois: 0),
            ],
            tamanhoRaiaM: 25)
        var motor = ExecutionEngine(plano: plano)
        motor.comecar()

        let hapticos = nadar(2, &motor)
        // Sem descanso não há entrada em descanso, e a regra 11.9 proíbe
        // háptico fora dos cinco eventos listados.
        #expect(hapticos.isEmpty)
        #expect(motor.estado == .nadando(.init(serie: 1, repeticao: 1, voltasNaRepeticao: 0)))
    }

    // MARK: - Regra 11.9: os cinco hápticos, e só eles

    @Test("Háptico ao entrar em descanso, nos 3 s finais, e ao sair (critério 8.8)")
    func hapticosDoDescanso() {
        var motor = ExecutionEngine(plano: planoDeUmaSerie)
        motor.comecar()

        #expect(nadar(4, &motor) == [.entradaEmDescanso])

        // 30 s de descanso: nada nos primeiros 26, um por segundo nos 3 finais,
        // e a saída no último.
        let primeiros26 = esperar(26, &motor)
        #expect(primeiros26.isEmpty, "háptico cedo demais: \(primeiros26)")

        #expect(esperar(1, &motor) == [.contagemFinal])  // restam 3
        #expect(esperar(1, &motor) == [.contagemFinal])  // restam 2
        #expect(esperar(1, &motor) == [.contagemFinal])  // resta 1
        #expect(esperar(1, &motor) == [.saidaDoDescanso])  // zerou
    }

    @Test("Háptico de conclusão na última série da última seção")
    func hapticoDeConclusao() {
        var motor = ExecutionEngine(plano: planoDeUmaSerie)
        motor.comecar()

        for repeticao in 1...3 {
            nadar(4, &motor)
            esperar(30, &motor)
            #expect(repeticao <= 3)
        }
        #expect(nadar(4, &motor) == [.conclusao])
        #expect(motor.estado == .concluido)
    }

    @Test("Nadar no meio de uma repetição não dispara háptico nenhum")
    func semHapticoNoMeioDaRepeticao() {
        var motor = ExecutionEngine(plano: planoDeUmaSerie)
        motor.comecar()
        // "Háptico demais vira ruído e o nadador para de prestar atenção."
        #expect(nadar(3, &motor).isEmpty)
    }

    @Test("Pausar, retomar e pular não disparam háptico (regra 11.9)")
    func acoesOpcionaisNaoVibram() {
        var motor = ExecutionEngine(plano: planoDeDuasSeries)
        motor.comecar()
        #expect(motor.processar(.pausar).isEmpty)
        #expect(motor.processar(.retomar).isEmpty)
        #expect(motor.processar(.pularSerie).isEmpty)
    }

    // MARK: - Regra 11.10: tolerância

    @Test("Nadar MAIS que o planejado não gera erro — a distância continua contando")
    func nadarMaisNaoQuebra() {
        var motor = ExecutionEngine(plano: planoDeUmaSerie)
        motor.comecar()
        for _ in 1...4 {
            nadar(4, &motor)
            esperar(30, &motor)
        }
        #expect(motor.estado == .concluido)

        // O nadador continua na água. Oito voltas extras.
        let extras = nadar(8, &motor)
        #expect(extras.isEmpty, "volta extra não pode disparar háptico")
        #expect(motor.estado == .concluido, "e não pode mudar de estado")
        #expect(motor.voltasTotais == 24)
        #expect(motor.metrosPercorridos == 600, "os 200 m extras contam")
        // O que foi de fato executado do plano não infla.
        #expect(motor.repeticoesConcluidas == 4)
        #expect(motor.seriesConcluidas == 1)
    }

    @Test("Descansar MAIS que o previsto não avança nada — o motor espera a volta")
    func descansarMaisNaoAvanca() {
        var motor = ExecutionEngine(plano: planoDeUmaSerie)
        motor.comecar()
        nadar(4, &motor)
        esperar(30, &motor)
        #expect(motor.estado == .nadando(.init(serie: 0, repeticao: 2, voltasNaRepeticao: 0)))

        // O nadador fica cinco minutos conversando na borda.
        let hapticos = esperar(300, &motor)
        #expect(hapticos.isEmpty)
        #expect(
            motor.estado == .nadando(.init(serie: 0, repeticao: 2, voltasNaRepeticao: 0)),
            "o tempo sozinho não pode avançar repetição")
        #expect(motor.repeticoesConcluidas == 1)
    }

    @Test("Sair do descanso antes da hora conta a volta, em vez de perdê-la")
    func sairAntesContaAVolta() {
        var motor = ExecutionEngine(plano: planoDeUmaSerie)
        motor.comecar()
        nadar(4, &motor)
        esperar(10, &motor)  // faltam 20 s

        // O nadador empurra a parede antes de a contagem zerar.
        let hapticos = motor.processar(.voltaCompletada)
        #expect(hapticos == [.saidaDoDescanso])
        // Ignorar esta volta faria a repetição seguinte terminar uma volta
        // atrasada, e o erro se acumularia até o fim do treino.
        #expect(motor.estado == .nadando(.init(serie: 0, repeticao: 2, voltasNaRepeticao: 1)))
        #expect(motor.voltasTotais == 5)
    }

    // MARK: - Pausa (máquina 12.2)

    @Test("Pausar preserva a posição e retomar volta exatamente de onde parou")
    func pausaPreservaAPosicao() {
        var motor = ExecutionEngine(plano: planoDeUmaSerie)
        motor.comecar()
        nadar(2, &motor)

        motor.processar(.pausar)
        #expect(
            motor.estado
                == .pausado(anterior: .nadando(.init(serie: 0, repeticao: 1, voltasNaRepeticao: 2))))

        // Pausado, nem volta nem tempo avançam nada.
        nadar(5, &motor)
        esperar(60, &motor)

        motor.processar(.retomar)
        #expect(motor.estado == .nadando(.init(serie: 0, repeticao: 1, voltasNaRepeticao: 2)))
    }

    @Test("Pausar durante o descanso retoma o descanso, não a natação")
    func pausaDuranteDescanso() {
        var motor = ExecutionEngine(plano: planoDeUmaSerie)
        motor.comecar()
        nadar(4, &motor)
        esperar(10, &motor)

        motor.processar(.pausar)
        motor.processar(.retomar)
        if case .descansando(let d) = motor.estado {
            #expect(d.restanteSeg == 20)
        } else {
            Issue.record("deveria retomar descansando, está \(motor.estado)")
        }
    }

    // MARK: - Pular série

    @Test("Pular vai para a próxima série e NÃO conta a pulada como concluída")
    func pularNaoInflaOContador() {
        var motor = ExecutionEngine(plano: planoDeDuasSeries)
        motor.comecar()
        nadar(1, &motor)

        motor.processar(.pularSerie)
        #expect(motor.estado == .nadando(.init(serie: 1, repeticao: 1, voltasNaRepeticao: 0)))
        // A série não foi nadada; inflar o contador falsearia o resumo.
        #expect(motor.seriesConcluidas == 0)
    }

    @Test("Pular a última série conclui o treino, com háptico")
    func pularAUltimaConclui() {
        var motor = ExecutionEngine(plano: planoDeUmaSerie)
        motor.comecar()
        #expect(motor.processar(.pularSerie) == [.conclusao])
        #expect(motor.estado == .concluido)
    }

    // MARK: - Estados de borda

    @Test("Antes de começar, volta e tempo não avançam nada")
    func preparandoNaoAvanca() {
        var motor = ExecutionEngine(plano: planoDeUmaSerie)
        #expect(motor.estado == .preparando)
        nadar(10, &motor)
        esperar(10, &motor)
        #expect(motor.estado == .preparando)
        // A volta ainda conta na distância: o nadador pode ter largado antes.
        #expect(motor.voltasTotais == 10)
    }

    @Test("Plano vazio nasce concluído em vez de travar")
    func planoVazio() {
        // Um treino cujas quatro seções ficaram vazias é estado válido da regra
        // 11.1. Travar em `preparando` deixaria o nadador com a tela parada.
        var motor = ExecutionEngine(plano: ExecutionPlan(series: [], tamanhoRaiaM: 25))
        #expect(motor.estado == .concluido)
        motor.comecar()
        #expect(motor.estado == .concluido)
    }

    // MARK: - O plano montado a partir do treino salvo

    @Test("O plano resolve qual dos dois descansos vale depois de cada série (11.6)")
    func planoResolveODescansoCerto() {
        let treino = Treino(
            origem: .gerado_iphone, distanciaTotalM: 800,
            distanciaMinSolicitadaM: 800, distanciaMaxSolicitadaM: 800,
            tamanhoRaiaM: 25, ritmoDescansoUsado: .normal,
            comEducativos: false, comPernada: false)

        let aquecimento = SecaoTreino(
            tipoSecao: .aquecimento, distanciaAlvoM: 400, descansoPosSecaoSeg: 45)
        aquecimento.series = [
            SerieTreino(
                exercicioId: "A", repeticoes: 2, distanciaM: 100, distanciaCatalogoM: 100,
                metrosTotais: 200, descansoSeg: 30, descansoPosSerieSeg: 30,
                voltasPorRepeticao: 4, nomeSnapshot: "2x100 Primeira",
                descricaoSnapshot: "", equipamentoExigido: "nenhum", modo: .nado,
                intensidade: .aquecimento, ordem: 1),
            SerieTreino(
                exercicioId: "B", repeticoes: 2, distanciaM: 100, distanciaCatalogoM: 100,
                metrosTotais: 200, descansoSeg: 30, descansoPosSerieSeg: 0,
                voltasPorRepeticao: 4, nomeSnapshot: "2x100 Última da seção",
                descricaoSnapshot: "", equipamentoExigido: "nenhum", modo: .nado,
                intensidade: .aquecimento, ordem: 2),
        ]
        let principal = SecaoTreino(
            tipoSecao: .principal, distanciaAlvoM: 400, descansoPosSecaoSeg: 0)
        principal.series = [
            SerieTreino(
                exercicioId: "C", repeticoes: 4, distanciaM: 100, distanciaCatalogoM: 100,
                metrosTotais: 400, descansoSeg: 30, descansoPosSerieSeg: 0,
                voltasPorRepeticao: 4, nomeSnapshot: "4x100 Principal",
                descricaoSnapshot: "", equipamentoExigido: "nenhum", modo: .nado,
                intensidade: .aerobico, ordem: 1)
        ]
        treino.secoes = [aquecimento, principal]

        let plano = ExecutionPlan(treino: treino)
        #expect(plano.series.count == 3)
        // Meio da seção: vale o descanso de série.
        #expect(plano.series[0].descansoDepoisSeg == 30)
        // Última da seção: vale o descanso de seção, e os dois nunca se somam.
        #expect(plano.series[1].descansoDepoisSeg == 45)
        // Última do treino: zero.
        #expect(plano.series[2].descansoDepoisSeg == 0)

        // O nome vem sem o prefixo de metragem do catálogo.
        #expect(plano.series[0].nome == "Primeira")
        #expect(plano.series[2].nome == "Principal")

        #expect(plano.voltasTotais == 32)
        #expect(plano.distanciaPlanejadaM == 800)
    }

    @Test("Seção vazia não vira série no plano, mas o treino continua executável")
    func secaoVaziaNaoViraSerie() {
        let treino = Treino(
            origem: .gerado_iphone, distanciaTotalM: 200,
            distanciaMinSolicitadaM: 200, distanciaMaxSolicitadaM: 200,
            tamanhoRaiaM: 25, ritmoDescansoUsado: .normal,
            comEducativos: false, comPernada: false)
        let vazia = SecaoTreino(
            tipoSecao: .progressao, distanciaAlvoM: 0, descansoPosSecaoSeg: 0)
        let comSerie = SecaoTreino(
            tipoSecao: .soltura, distanciaAlvoM: 200, descansoPosSecaoSeg: 0)
        comSerie.series = [
            SerieTreino(
                exercicioId: "S", repeticoes: 1, distanciaM: 200, distanciaCatalogoM: 200,
                metrosTotais: 200, descansoSeg: 0, descansoPosSerieSeg: 0,
                voltasPorRepeticao: 8, nomeSnapshot: "1x200 solto",
                descricaoSnapshot: "", equipamentoExigido: "nenhum", modo: .nado,
                intensidade: .soltura, ordem: 1)
        ]
        treino.secoes = [vazia, comSerie]

        let plano = ExecutionPlan(treino: treino)
        #expect(plano.series.count == 1)
        #expect(!plano.estaVazio)
    }
}
