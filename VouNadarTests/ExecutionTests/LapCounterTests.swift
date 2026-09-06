import Foundation
import Testing

@testable import VouNadar

/// A contagem de voltas a partir da distância (regra 11.7, risco R3).
///
/// É o teste que a seção 22 pede nominalmente: "contagem de voltas com
/// distâncias simuladas, sem HealthKit real".
struct LapCounterTests {

    @Test("Cada múltiplo da raia fecha uma volta")
    func voltasPorMultiplo() {
        var contador = LapCounter(tamanhoRaiaM: 25)
        #expect(contador.registrar(distanciaTotalM: 10) == 0)
        #expect(contador.registrar(distanciaTotalM: 25) == 1)
        #expect(contador.registrar(distanciaTotalM: 40) == 0)
        #expect(contador.registrar(distanciaTotalM: 50) == 1)
        #expect(contador.voltasContabilizadas == 2)
    }

    @Test("Amostra atrasada que pula duas voltas contabiliza as DUAS")
    func amostraAtrasadaNaoPerdeVolta() {
        // É a razão de contar por distância e não por evento discreto: com
        // eventos, uma volta perdida é perdida para sempre, e a repetição
        // terminaria atrasada até o fim do treino (risco R3).
        var contador = LapCounter(tamanhoRaiaM: 25)
        #expect(contador.registrar(distanciaTotalM: 75) == 3)
        #expect(contador.voltasContabilizadas == 3)
    }

    @Test("Distância que regride NÃO desconta volta")
    func regressaoNaoDesconta() {
        // O HealthKit pode corrigir a distância para baixo entre amostras. Uma
        // repetição não "desacontece", e desfazer um avanço no meio do treino
        // confundiria o nadador sem nenhum ganho.
        var contador = LapCounter(tamanhoRaiaM: 25)
        #expect(contador.registrar(distanciaTotalM: 100) == 4)
        #expect(contador.registrar(distanciaTotalM: 60) == 0)
        #expect(contador.voltasContabilizadas == 4)
        // E a próxima volta de verdade só conta a partir do maior já visto.
        #expect(contador.registrar(distanciaTotalM: 125) == 1)
    }

    @Test("Piscina de tamanho incomum conta certo", arguments: [12, 15, 16, 18, 20, 33, 50])
    func raiasIncomuns(raia: Int) {
        var contador = LapCounter(tamanhoRaiaM: raia)
        // Seis voltas exatas.
        #expect(contador.registrar(distanciaTotalM: Double(raia * 6)) == 6)
        // Meia volta a mais não fecha a sétima.
        #expect(contador.registrar(distanciaTotalM: Double(raia * 6) + Double(raia) / 2) == 0)
    }

    @Test("Raia inválida não divide por zero")
    func raiaInvalida() {
        // A validação de 10 a 50 é do repositório (spec 7.11); isto é a defesa
        // final, para um dado corrompido não derrubar o app dentro d'água.
        var contador = LapCounter(tamanhoRaiaM: 0)
        #expect(contador.registrar(distanciaTotalM: 3) == 3)
    }

    @Test("O contador alimenta o motor e o treino avança de verdade")
    func integracaoComOMotor() {
        // Junta as duas peças puras: distância simulada entra, série avança.
        let plano = ExecutionPlan(
            series: [
                .init(
                    indice: 0, secao: .principal, nome: "Crawl", repeticoes: 2,
                    distanciaM: 100, voltasPorRepeticao: 4, descansoSeg: 30,
                    descansoDepoisSeg: 0)
            ],
            tamanhoRaiaM: 25)
        var motor = ExecutionEngine(plano: plano)
        var contador = LapCounter(tamanhoRaiaM: 25)
        motor.comecar()

        // O nadador completa 100 m: quatro voltas, fim da primeira repetição.
        var hapticos: [ExecutionEngine.Haptico] = []
        for metros in stride(from: 25.0, through: 100.0, by: 25.0) {
            for _ in 0..<contador.registrar(distanciaTotalM: metros) {
                hapticos += motor.processar(.voltaCompletada)
            }
        }
        #expect(hapticos == [.entradaEmDescanso])
        #expect(motor.repeticoesConcluidas == 1)
        #expect(motor.metrosPercorridos == 100)
    }
}
