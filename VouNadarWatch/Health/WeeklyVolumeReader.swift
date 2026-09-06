import Foundation
import HealthKit

/// Lê o volume nadado da semana corrente (épico 8.12, regra 11.16).
///
/// Recebe: nada além da autorização do usuário.
/// Devolve: metros nadados desde a segunda-feira, ou `nil` quando não há como
/// saber.
///
/// ## Por que ele existe separado do `HealthHistoryReader`
///
/// Aquele é do iPhone e devolve a lista inteira de sessões, para o Histórico
/// desenhar gráfico e lista. Este devolve **um número**, e é usado por dois
/// processos diferentes: o app do relógio (tela W1) e a **complication**, que
/// roda fora do app.
///
/// A complication não pode compartilhar o store SwiftData do app sem App Group —
/// que exigiria configuração de provisionamento no portal da Apple. O HealthKit
/// resolve isso de graça: os dois processos já têm o entitlement, e o dado é o
/// mesmo que o Histórico do iPhone mostra.
///
/// ## `nil` não é zero
///
/// Devolver `nil` quando o HealthKit não responde é a diferença entre "você não
/// nadou esta semana" e "não sei". A complication mostra **ícone e um traço** no
/// segundo caso (critério 8.12) — dizer zero para quem nadou 3 km seria mentir
/// no mostrador do relógio.
struct WeeklyVolumeReader {

    private let healthStore = HKHealthStore()

    /// O tipo lido. **Nada é escrito aqui** — quem escreve é a execução (8.9).
    static let tipoLido = HKQuantityType(.distanceSwimming)

    /// Metros nadados na semana corrente, ou `nil` quando não há dado confiável.
    ///
    /// A semana começa na **segunda-feira**, no fuso do aparelho (regra 11.16).
    func metrosDaSemana(agora: Date = .now, fuso: TimeZone = .current) async -> Int? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }

        let inicio = Semana.inicioDaSemanaAtual(agora: agora, fuso: fuso)
        let periodo = HKQuery.predicateForSamples(withStart: inicio, end: agora)

        let descritor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: Self.tipoLido, predicate: periodo),
            options: .cumulativeSum)

        do {
            let estatistica = try await descritor.result(for: healthStore)
            guard let soma = estatistica?.sumQuantity() else {
                // Sem amostra no período **é** zero: a consulta respondeu e não
                // havia nada. Diferente de a consulta falhar.
                return 0
            }
            return Int(soma.doubleValue(for: .meter()))
        } catch {
            // Não sei. Quem chama decide o que mostrar — e mostra um traço.
            return nil
        }
    }

    /// Pede autorização de leitura.
    ///
    /// A complication não pede: ela usa a autorização que o app já obteve. Este
    /// método existe para a tela W1, que é onde o usuário está com o app aberto.
    func pedirAutorizacao() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await healthStore.requestAuthorization(toShare: [], read: [Self.tipoLido])
    }
}
