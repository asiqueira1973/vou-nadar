import Foundation

/// Uma sessão como o Histórico a enxerga (tela P4).
///
/// **Não é `sessao_natacao`.** É o denominador comum entre o que o app gravou e
/// o que veio de outro app pelo HealthKit — porque o critério 8.10 exige que os
/// dois apareçam na mesma lista. O HealthKit é do usuário, não do Vou Nadar.
struct SessaoDoHistorico: Sendable, Equatable, Identifiable {

    let id: UUID
    let iniciadaEm: Date
    let duracao: TimeInterval

    /// Distância **real** nadada, em metros.
    let distanciaM: Int

    /// O título do treino, quando o registro veio deste app. Nulo em treino de
    /// outro app, que não tem como saber disso.
    let titulo: String?

    /// Gravado por **outro** app.
    ///
    /// Ganha o selo "fora do app" na lista (DESIGN-SYSTEM.md seção 3). Não é
    /// demérito: é contexto. Sem a marca, o usuário veria um treino que ele não
    /// reconhece e acharia que o app inventou.
    let origemExterna: Bool
}

/// Uma barra do gráfico de volume (tela P4).
struct SemanaDeVolume: Sendable, Equatable, Identifiable {

    /// A meia-noite da segunda-feira daquela semana (regra 11.16).
    let inicio: Date

    /// Metros somados na semana.
    let metrosM: Int

    var id: Date { inicio }

    /// Semana sem nenhum treino.
    ///
    /// **Aparece como barra vazia, nunca como buraco no eixo** (critério 8.10):
    /// um buraco faria o gráfico mentir sobre o intervalo, e a semana em que não
    /// se nadou é informação, não ausência de informação.
    var estaVazia: Bool { metrosM == 0 }
}

/// Agrega sessões em volume por semana (regra 11.16, critério 8.10).
///
/// **É função pura**, sem HealthKit e sem SwiftData: a agregação é o que erra
/// com mais facilidade — semana começando no dia errado, sessão que atravessa a
/// meia-noite caindo na semana errada, semana vazia sumindo do eixo — e nada
/// disso precisa de aparelho para ser verificado.
enum VolumeSemanal {

    /// Quantas semanas o gráfico da tela P4 mostra.
    ///
    /// Seis cabem na largura do iPhone sem as barras ficarem finas demais para
    /// serem lidas, e cobrem um mês e meio — horizonte suficiente para o nadador
    /// amador ver constância sem virar gráfico de treinador.
    static let semanasNoGrafico = 6

    /// Soma o volume de cada uma das últimas `quantidade` semanas.
    ///
    /// Recebe: as sessões e quantas semanas mostrar.
    /// Devolve: uma entrada **por semana**, da mais antiga para a mais recente,
    /// **inclusive as vazias**.
    ///
    /// Sessão que atravessa a meia-noite conta na semana do `iniciada_em`
    /// (regra 11.16): quem nada às 23h40 de domingo termina na segunda, e o
    /// treino é de domingo.
    static func porSemana(
        _ sessoes: [SessaoDoHistorico],
        quantidade: Int = semanasNoGrafico,
        agora: Date = .now,
        fuso: TimeZone = .current
    ) -> [SemanaDeVolume] {
        let inicios = Semana.inicios(ultimas: quantidade, agora: agora, fuso: fuso)

        // Indexa as sessões pelo início da semana delas, numa passada só.
        var porInicio: [Date: Int] = [:]
        for sessao in sessoes {
            let inicio = Semana.inicio(de: sessao.iniciadaEm, fuso: fuso)
            porInicio[inicio, default: 0] += sessao.distanciaM
        }

        return inicios.map { SemanaDeVolume(inicio: $0, metrosM: porInicio[$0] ?? 0) }
    }

    /// Metros nadados na semana corrente.
    static func daSemanaAtual(
        _ sessoes: [SessaoDoHistorico], agora: Date = .now, fuso: TimeZone = .current
    ) -> Int {
        let inicio = Semana.inicioDaSemanaAtual(agora: agora, fuso: fuso)
        return sessoes
            .filter { $0.iniciadaEm >= inicio }
            .reduce(0) { $0 + $1.distanciaM }
    }

    /// A média semanal das semanas mostradas no gráfico.
    ///
    /// **Inclui as semanas vazias no divisor.** Uma média que ignora as semanas
    /// paradas é uma média de "quando eu treino", não de constância — e
    /// constância é o que o nadador amador está tentando ver.
    static func mediaSemanal(_ semanas: [SemanaDeVolume]) -> Int {
        guard !semanas.isEmpty else { return 0 }
        return semanas.reduce(0) { $0 + $1.metrosM } / semanas.count
    }
}
