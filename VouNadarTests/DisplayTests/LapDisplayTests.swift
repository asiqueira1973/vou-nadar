import Foundation
import Testing

@testable import VouNadar

/// A contagem de chegadas e piscinas (feature de 15/09/2026).
///
/// São três regras, e cada uma quebra de um jeito diferente se alguém mexer sem
/// saber: par vira chegada, ímpar vira piscina, e nada aparece em raia de 25 m
/// ou maior.
struct LapDisplayTests {

    // MARK: - Par vira chegada, ímpar vira piscina

    @Test(
        "Travessias pares viram chegadas; ímpares viram piscinas",
        arguments: [
            (voltas: 1, esperado: LapDisplay.Contagem.piscinas(1)),
            (voltas: 2, esperado: .chegadas(1)),
            (voltas: 3, esperado: .piscinas(3)),
            (voltas: 4, esperado: .chegadas(2)),
            (voltas: 6, esperado: .chegadas(3)),
            (voltas: 11, esperado: .piscinas(11)),
            (voltas: 12, esperado: .chegadas(6)),
        ])
    func parOuImpar(caso: (voltas: Int, esperado: LapDisplay.Contagem)) {
        // Raia de 18 m: abaixo do limite, então a contagem aparece.
        #expect(
            LapDisplay.contagem(voltasPorRepeticao: caso.voltas, tamanhoRaiaM: 18)
                == caso.esperado)
    }

    @Test("O caso que motivou a feature: 2×54 em raia de 18 m são 3 piscinas")
    func casoDoAlexandre() {
        // 54 m em raia de 18 m são três travessias — não fecham em par, então
        // não há como chamar de chegada. É o exemplo que ele deu ao pedir.
        let voltas = LaneAdapter.voltasPorRepeticao(distanciaCatalogoM: 50, tamanhoRaiaM: 18)
        #expect(voltas == 3)
        #expect(
            LapDisplay.contagem(voltasPorRepeticao: voltas, tamanhoRaiaM: 18) == .piscinas(3))
    }

    // MARK: - O limite de 25 m

    @Test(
        "Raia de 25 m ou maior não mostra contagem: a conta é óbvia",
        arguments: [25, 26, 33, 50])
    func raiaGrandeNaoMostra(raia: Int) {
        // Qualquer número de travessias, em qualquer paridade.
        for voltas in 1...12 {
            #expect(
                LapDisplay.contagem(voltasPorRepeticao: voltas, tamanhoRaiaM: raia) == nil,
                "raia de \(raia) m não deveria mostrar contagem")
        }
    }

    @Test(
        "Raia menor que 25 m mostra contagem", arguments: [10, 12, 15, 16, 18, 20, 24])
    func raiaPequenaMostra(raia: Int) {
        #expect(LapDisplay.contagem(voltasPorRepeticao: 4, tamanhoRaiaM: raia) != nil)
    }

    @Test("O limite é 25, e é exclusivo")
    func limiteDeclarado() {
        #expect(LapDisplay.raiaMaximaM == 25)
        #expect(LapDisplay.contagem(voltasPorRepeticao: 4, tamanhoRaiaM: 24) != nil)
        #expect(LapDisplay.contagem(voltasPorRepeticao: 4, tamanhoRaiaM: 25) == nil)
    }

    // MARK: - Dado inválido não vira "0 piscinas"

    @Test("Zero ou negativo não produz contagem", arguments: [0, -1])
    func semVoltasNaoMostra(voltas: Int) {
        #expect(LapDisplay.contagem(voltasPorRepeticao: voltas, tamanhoRaiaM: 18) == nil)
    }

    // MARK: - Varredura sobre o catálogo real

    @Test("Nos 226 exercícios, a contagem sempre fecha com as travessias")
    func varreduraSobreOCatalogo() throws {
        let catalogo = try CatalogStore()
        let raias = [10, 12, 15, 16, 18, 20, 24]

        for raia in raias {
            for exercicio in catalogo.allExercises
            where LaneAdapter.podeSerSorteado(exercicio, tamanhoRaiaM: raia) {
                let voltas = LaneAdapter.voltasPorRepeticao(
                    distanciaCatalogoM: exercicio.distancia_m, tamanhoRaiaM: raia)
                let contagem = try #require(
                    LapDisplay.contagem(voltasPorRepeticao: voltas, tamanhoRaiaM: raia))

                switch contagem {
                case .chegadas(let quantas):
                    // Chegada é ida e volta: o dobro tem que reconstruir as
                    // travessias, sem sobra.
                    #expect(quantas * 2 == voltas)
                    #expect(voltas.isMultiple(of: 2))
                case .piscinas(let quantas):
                    #expect(quantas == voltas)
                    #expect(!voltas.isMultiple(of: 2))
                }
            }
        }
    }

    // MARK: - A copy

    @Test("Singular e plural das duas unidades")
    func copySingularEPlural() {
        #expect(String(localized: Copy.travessias(.chegadas(1))) == "1 chegada")
        #expect(String(localized: Copy.travessias(.chegadas(2))) == "2 chegadas")
        #expect(String(localized: Copy.travessias(.chegadas(6))) == "6 chegadas")
        #expect(String(localized: Copy.travessias(.piscinas(1))) == "1 piscina")
        #expect(String(localized: Copy.travessias(.piscinas(3))) == "3 piscinas")
        #expect(String(localized: Copy.travessias(.piscinas(11))) == "11 piscinas")
    }
}
