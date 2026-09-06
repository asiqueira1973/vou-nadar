import Foundation

/// A semana do produto (regra 11.16).
///
/// **É função pura**, e é compartilhada pelos dois targets porque os dois contam
/// volume semanal: o relógio na tela W1, o iPhone no Histórico.
///
/// A regra é curta e tem três partes que erram fácil separadas:
/// 1. a semana **começa na segunda-feira**, não no domingo — o padrão de `pt_BR`
///    no `Calendar` é domingo, e usar o padrão daria o número errado toda
///    segunda;
/// 2. o fuso é o **do aparelho no momento da consulta**, não um fixo;
/// 3. uma sessão que atravessa a meia-noite conta na semana do `iniciada_em` —
///    quem nada 23h40 de domingo termina na segunda, e o treino é de domingo.
enum Semana {

    /// Segunda-feira. `Calendar` numera domingo como 1.
    static let primeiroDiaDaSemana = 2

    /// O calendário do produto: o do aparelho, com a semana começando na
    /// segunda.
    static func calendario(fuso: TimeZone = .current) -> Calendar {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = fuso
        calendario.firstWeekday = primeiroDiaDaSemana
        return calendario
    }

    /// O instante em que a semana de uma data começou.
    ///
    /// Recebe: a data e, opcionalmente, o fuso.
    /// Devolve: a meia-noite da segunda-feira daquela semana.
    static func inicio(de data: Date, fuso: TimeZone = .current) -> Date {
        let calendario = calendario(fuso: fuso)
        let componentes = calendario.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: data)
        return calendario.date(from: componentes) ?? data
    }

    /// O início da semana corrente.
    static func inicioDaSemanaAtual(agora: Date = .now, fuso: TimeZone = .current) -> Date {
        inicio(de: agora, fuso: fuso)
    }

    /// Os inícios das últimas `quantidade` semanas, da mais antiga para a mais
    /// recente, terminando na semana corrente.
    ///
    /// É o eixo do gráfico do Histórico (épico 8.10). **Semana sem treino tem
    /// que aparecer como barra vazia**, nunca como buraco no eixo — e para isso
    /// o eixo precisa existir independentemente de haver dado.
    static func inicios(ultimas quantidade: Int, agora: Date = .now, fuso: TimeZone = .current)
        -> [Date]
    {
        guard quantidade > 0 else { return [] }
        let calendario = calendario(fuso: fuso)
        let atual = inicioDaSemanaAtual(agora: agora, fuso: fuso)
        return (0..<quantidade).reversed().compactMap {
            calendario.date(byAdding: .weekOfYear, value: -$0, to: atual)
        }
    }
}
