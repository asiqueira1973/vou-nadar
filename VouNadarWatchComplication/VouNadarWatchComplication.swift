import SwiftUI
import WidgetKit

/// A complication do Vou Nadar (épico 8.12).
///
/// Mostra **o volume nadado desde segunda-feira**, no mostrador. É a única
/// superfície do produto que o usuário vê sem abrir nada — e por isso ela mostra
/// o número que responde à única pergunta que cabe num relance: *estou nadando o
/// suficiente esta semana?*
@main
struct VouNadarWatchComplicationBundle: WidgetBundle {
    var body: some Widget {
        WeeklyVolumeComplication()
    }
}

/// Complication de volume semanal (critério 8.12).
struct WeeklyVolumeComplication: Widget {

    /// Identificador estável. Mudá-lo faz o usuário perder a complication já
    /// posicionada no mostrador.
    static let tipo = "VolumeSemanal"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.tipo, provider: WeeklyVolumeProvider()) { entrada in
            WeeklyVolumeView(entrada: entrada)
                // Tocar abre o app (critério 8.12). O destino é a tela Início,
                // que é a raiz do `NavigationStack` do relógio — o app trata
                // esta URL desempilhando o que estiver aberto.
                .widgetURL(URL(string: "vounadar://inicio"))
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(Text(ComplicationCopy.nome))
        .description(Text(ComplicationCopy.descricao))
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular])
    }
}

/// Uma leitura do volume semanal no mostrador.
struct WeeklyVolumeEntry: TimelineEntry {

    let date: Date

    /// Metros nadados na semana.
    ///
    /// **`nil` não é zero.** Nulo é "não sei" — o HealthKit não respondeu, ou o
    /// usuário não autorizou. Zero é "respondeu, e você não nadou". A tela
    /// distingue os dois: o critério 8.12 manda mostrar **ícone e um traço**
    /// quando não há dado, e dizer zero para quem nadou 3 km seria mentir no
    /// mostrador.
    let metros: Int?
}

/// Fornece as entradas da linha do tempo (critério 8.12).
struct WeeklyVolumeProvider: TimelineProvider {

    /// De quanto em quanto tempo a complication se atualiza.
    ///
    /// **Uma vez por hora, no máximo** (critério 8.12). Volume semanal muda
    /// devagar: atualizar mais que isso gastaria bateria e orçamento de
    /// atualização do sistema sem mudar o número na tela.
    static let intervalo: TimeInterval = 60 * 60

    func placeholder(in context: Context) -> WeeklyVolumeEntry {
        // O placeholder aparece na galeria de complications, antes de haver
        // dado. Um número plausível mostra a forma; um traço mostraria a
        // complication parecendo quebrada.
        WeeklyVolumeEntry(date: .now, metros: 4300)
    }

    // Os dois retornos de chamada são declarados `@Sendable`.
    //
    // Sem isso o Swift 6 barra: consultar o HealthKit é assíncrono, o que obriga
    // uma `Task`, e capturar dentro dela um `completion` não-`Sendable` seria
    // levar um retorno de chamada para outro contexto de isolamento. Marcá-lo
    // `@Sendable` é o que declara que atravessar é seguro — e é, porque o
    // WidgetKit o chama uma vez só.

    func getSnapshot(
        in context: Context, completion: @escaping @Sendable (WeeklyVolumeEntry) -> Void
    ) {
        Task {
            let metros = await WeeklyVolumeReader().metrosDaSemana()
            completion(WeeklyVolumeEntry(date: .now, metros: metros))
        }
    }

    func getTimeline(
        in context: Context,
        completion: @escaping @Sendable (Timeline<WeeklyVolumeEntry>) -> Void
    ) {
        Task {
            let metros = await WeeklyVolumeReader().metrosDaSemana()
            completion(
                Timeline(
                    entries: [WeeklyVolumeEntry(date: .now, metros: metros)],
                    // Uma entrada só, e a próxima atualização daqui a uma hora
                    // (critério 8.12).
                    policy: .after(Date().addingTimeInterval(Self.intervalo))))
        }
    }
}

/// O desenho da complication, nas três famílias (critério 8.12).
///
/// Cada família tem espaço diferente, e forçar o mesmo desenho nas três daria
/// uma que cabe e duas que truncam:
/// - **circular**: só o número, com o ícone acima. É a menor;
/// - **corner**: o número, com o rótulo na curva;
/// - **rectangular**: rótulo e número lado a lado, que é a única com espaço para
///   dizer o que o número significa.
struct WeeklyVolumeView: View {

    let entrada: WeeklyVolumeEntry

    @Environment(\.widgetFamily) private var familia

    var body: some View {
        switch familia {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: Simbolos.abaTreino)
                    .font(.system(size: 11))
                Text(verbatim: textoCurto)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

        case .accessoryCorner:
            Text(verbatim: textoCurto)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.6)
                // `widgetLabel` com view, e não com texto solto: a sobrecarga
                // de `String` não aceita `Text`, e passar a chave crua perderia
                // a localização.
                .widgetLabel { Text(ComplicationCopy.rotulo) }

        default:
            HStack(spacing: 5) {
                Image(systemName: Simbolos.abaTreino)
                VStack(alignment: .leading, spacing: 0) {
                    Text(ComplicationCopy.rotulo)
                        .font(.system(size: 12))
                    Text(verbatim: textoLongo)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
        }
    }

    /// O número curto, para as famílias apertadas: `4,3 km`, `800 m` ou `—`.
    ///
    /// Acima de mil metros vira quilômetro: `4.300 m` não cabe no círculo, e
    /// `4,3 km` diz a mesma coisa num relance — que é o que uma complication
    /// tem de tempo.
    private var textoCurto: String {
        guard let metros = entrada.metros else { return ComplicationCopy.semDado }
        if metros >= 1000 {
            let km = Double(metros) / 1000
            return km.formatted(
                .number.precision(.fractionLength(1)).locale(Locale(identifier: "pt_BR"))) + " km"
        }
        return "\(metros) m"
    }

    /// O número completo, para a família retangular: `4.300 m` ou `—`.
    private var textoLongo: String {
        guard let metros = entrada.metros else { return ComplicationCopy.semDado }
        return metros.formatted(.number.locale(Locale(identifier: "pt_BR"))) + " m"
    }
}

/// A copy da complication (requisito 17.11: zero string em `View`).
///
/// Separada da copy do app do relógio porque a complication é outro processo,
/// com o próprio bundle e o próprio catálogo de strings.
enum ComplicationCopy {

    /// Nome na galeria de complications do mostrador.
    static let nome = LocalizedStringResource("Volume da semana")

    /// Descrição na galeria.
    static let descricao = LocalizedStringResource(
        "Quantos metros você nadou desde segunda-feira.")

    /// Rótulo ao lado do número.
    static let rotulo = LocalizedStringResource("Esta semana")

    /// Sem dado: **ícone e um traço** (critério 8.12).
    ///
    /// É o travessão U+2014, não um hífen: no mostrador, hífen parece sinal de
    /// menos.
    static let semDado = "\u{2014}"
}
