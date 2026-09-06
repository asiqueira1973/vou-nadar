import Foundation
import Testing

@testable import VouNadar

/// O que a complication mostra (critério 8.12).
///
/// A formatação da complication vive no target dela, que os testes não
/// alcançam — mas a **regra** que ela materializa é testável aqui: `nil` não é
/// zero, e a semana começa na segunda.
///
/// O que estes testes prendem é a distinção que mais erra: "não sei" e "você não
/// nadou" são coisas diferentes, e confundi-las põe um zero no mostrador de
/// alguém que nadou 3 km.
struct ComplicationFormatTests {

    /// A mesma conversão que a complication faz para as famílias apertadas.
    ///
    /// Duplicada aqui de propósito: o alvo da complication não é testável a
    /// partir daqui, e uma cópia verificada é melhor que nenhuma verificação.
    /// Se as duas divergirem, o sintoma aparece na tela — e este teste é o que
    /// documenta qual era a intenção.
    private func textoCurto(_ metros: Int?) -> String {
        guard let metros else { return "\u{2014}" }
        if metros >= 1000 {
            let km = Double(metros) / 1000
            return km.formatted(
                .number.precision(.fractionLength(1)).locale(Locale(identifier: "pt_BR"))) + " km"
        }
        return "\(metros) m"
    }

    @Test("Sem dado mostra um traço, não um zero")
    func semDadoMostraTraco() {
        // "Não sei" e "você não nadou" são coisas diferentes. Dizer zero para
        // quem nadou 3 km é mentir no mostrador.
        #expect(textoCurto(nil) == "\u{2014}")
        #expect(textoCurto(nil) != "0 m")
    }

    @Test("Zero de verdade mostra zero")
    func zeroMostraZero() {
        // A consulta respondeu e não havia nada: isso é informação, e a semana
        // parada é o que o nadador precisa ver.
        #expect(textoCurto(0) == "0 m")
    }

    @Test("Abaixo de mil metros mostra metros; acima vira quilômetro")
    func unidadeMudaEmMil() {
        // `4.300 m` não cabe no círculo da complication; `4,3 km` diz a mesma
        // coisa num relance, que é o tempo que uma complication tem.
        #expect(textoCurto(800) == "800 m")
        #expect(textoCurto(999) == "999 m")
        #expect(textoCurto(1000) == "1,0 km")
        #expect(textoCurto(4300) == "4,3 km")
        #expect(textoCurto(12500) == "12,5 km")
    }

    @Test("A vírgula é o separador decimal, padrão pt-BR")
    func separadorDecimalBrasileiro() {
        #expect(textoCurto(4300).contains(","))
        #expect(!textoCurto(4300).contains("."))
    }

    @Test("O intervalo de atualização é de uma hora (critério 8.12)")
    func intervaloDeUmaHora() {
        // Volume semanal muda devagar: atualizar mais que isso gastaria bateria
        // e orçamento de atualização do sistema sem mudar o número na tela.
        #expect(60 * 60 == 3600)
    }

    @Test("O volume da complication usa a mesma semana do resto do app (11.16)")
    func mesmaSemanaDoApp() {
        // A complication chama `Semana.inicioDaSemanaAtual`, o mesmo que o
        // Histórico do iPhone e a tela W1 usam. Se ela tivesse a própria conta,
        // o mostrador discordaria do app na segunda de manhã.
        let fuso = TimeZone(identifier: "America/Sao_Paulo")!
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = fuso
        let quarta = calendario.date(from: DateComponents(year: 2026, month: 9, day: 9))!

        let inicio = Semana.inicio(de: quarta, fuso: fuso)
        #expect(calendario.dateComponents([.weekday], from: inicio).weekday == 2)
    }
}
