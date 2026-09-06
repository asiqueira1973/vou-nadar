import SwiftUI
import UIKit

/// P4 — Histórico (épico 8.10).
///
/// Lê: o HealthKit. Escreve: nada.
///
/// ## Por que a fonte é o HealthKit, e o que isso implica
///
/// O iPhone **não tem** as sessões: elas nascem no relógio, no store dele, e não
/// há sincronização Watch → iPhone (princípio 0.7). O que atravessa é o
/// `HKWorkout`, que o HealthKit propaga sozinho (decisão 4.3) — é por isso que
/// as sessões "aparecem sem ação do usuário" (critério 8.10).
///
/// A consequência é que **treinos de outros apps também aparecem**, com o selo
/// "fora do app". O HealthKit é do usuário, não do Vou Nadar.
///
/// Estrutura (DESIGN-SYSTEM.md seção 3): números soltos, gráfico, e `List`. O
/// gráfico é o **segundo e último** contêiner desenhado à mão do app.
struct HistoryView: View {

    @State private var leitor = HealthHistoryReader()
    @State private var sessoes: [SessaoDoHistorico] = []
    @State private var semanas: [SemanaDeVolume] = []
    @State private var semAutorizacao = false
    @State private var carregando = true

    var body: some View {
        Group {
            if carregando {
                ProgressView()
            } else if semAutorizacao {
                SemAutorizacao()
            } else if sessoes.isEmpty {
                vazio
            } else {
                conteudo
            }
        }
        .navigationTitle(Text(Copy.abaHistorico))
        .navigationBarTitleDisplayMode(.large)
        .task { await carregar() }
    }

    /// Estado vazio (DESIGN-SYSTEM.md seção 6).
    private var vazio: some View {
        ContentUnavailableView {
            Label {
                Text(Copy.historicoVazioTitulo)
            } icon: {
                Image(systemName: Simbolos.abaTreino)
            }
        } description: {
            Text(Copy.historicoVazioCorpo)
        }
    }

    private var conteudo: some View {
        List {
            Section {
                NumerosDaSemana(
                    estaSemanaM: VolumeSemanal.daSemanaAtual(sessoes),
                    mediaM: VolumeSemanal.mediaSemanal(semanas),
                    sessoesNoPeriodo: sessoes.count)
                GraficoDeVolume(semanas: semanas)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 12, trailing: 20))

            Section {
                ForEach(sessoes) { sessao in
                    LinhaDeSessao(sessao: sessao)
                }
            } header: {
                Text(Copy.historicoSecaoSessoes)
            }
        }
        .listaDoApp()
    }

    /// Carrega o histórico. Falha de autorização **não quebra a tela**
    /// (critério 8.10).
    private func carregar() async {
        carregando = true
        defer { carregando = false }
        do {
            try await leitor.pedirAutorizacao()
            // Busca um pouco além das semanas do gráfico, para a lista ter o que
            // mostrar mesmo quando o gráfico está vazio.
            let desde =
                Semana.inicios(ultimas: VolumeSemanal.semanasNoGrafico).first
                ?? Date(timeIntervalSinceNow: -60 * 60 * 24 * 60)
            sessoes = try await leitor.sessoes(desde: desde)
            semanas = VolumeSemanal.porSemana(sessoes)
            semAutorizacao = false
        } catch {
            semAutorizacao = true
        }
    }
}

/// Os números soltos acima do gráfico (DESIGN-SYSTEM.md seções 3 e 5).
///
/// `HStack` de `VStack`s com 26 pt entre eles, **sem caixa** — números dentro de
/// caixa de largura fixa são a reprovação 8 do design system. O alinhamento vem
/// de `.monospacedDigit()`; o que evita truncar é `.minimumScaleFactor(0.7)`,
/// a única exceção de Dynamic Type do app, para caber "96.800 m".
private struct NumerosDaSemana: View {

    let estaSemanaM: Int
    let mediaM: Int
    let sessoesNoPeriodo: Int

    var body: some View {
        HStack(alignment: .top, spacing: Medidas.numerosSemanaEspacamento) {
            Numero(valor: "\(Formato.metros(estaSemanaM)) m", rotulo: Copy.historicoEstaSemana)
            Numero(valor: "\(Formato.metros(mediaM)) m", rotulo: Copy.historicoMediaSemanal)
            Numero(valor: "\(sessoesNoPeriodo)", rotulo: Copy.historicoTreinos)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct Numero: View {
        let valor: String
        let rotulo: LocalizedStringResource

        var body: some View {
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: valor)
                    .font(.numeroDaSemana)
                    .foregroundStyle(Color.textoPrimario)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(rotulo)
                    .font(.caption)
                    .foregroundStyle(Color.textoSecundario)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// O gráfico de volume por semana (DESIGN-SYSTEM.md seções 3 e 5).
///
/// **Contêiner desenhado à mão**, o segundo e último permitido: `HStack` de
/// 6 pt, altura 112 pt, barras com canto de 2 pt e largura por
/// `frame(maxWidth: .infinity)` — **sem moldura e sem fundo**.
///
/// **Semana sem treino é barra vazia, nunca buraco no eixo** (critério 8.10):
/// 6% da altura com traço de `Hairline`. Um buraco faria o gráfico mentir sobre
/// o intervalo; a semana parada é informação.
private struct GraficoDeVolume: View {

    let semanas: [SemanaDeVolume]

    /// A altura da barra vazia, como fração da altura total.
    private static let fracaoDaBarraVazia = 0.06

    private var maior: Int {
        max(1, semanas.map(\.metrosM).max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: Medidas.graficoEspacamentoBarras) {
                ForEach(semanas) { semana in
                    barra(de: semana)
                }
            }
            .frame(height: Medidas.graficoAltura)

            HStack(spacing: Medidas.graficoEspacamentoBarras) {
                ForEach(semanas) { semana in
                    Text(verbatim: Formato.diaEMes(semana.inicio))
                        .font(.caption2)
                        .foregroundStyle(Color.textoSecundario)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func barra(de semana: SemanaDeVolume) -> some View {
        let altura =
            semana.estaVazia
            ? Medidas.graficoAltura * Self.fracaoDaBarraVazia
            : max(
                Medidas.graficoAltura * Self.fracaoDaBarraVazia,
                Medidas.graficoAltura * Double(semana.metrosM) / Double(maior))

        Group {
            if semana.estaVazia {
                // Traço, não preenchimento: a semana existe no eixo e se vê que
                // ela está vazia.
                RoundedRectangle(cornerRadius: Medidas.graficoCantoBarra)
                    .stroke(Color.hairline, lineWidth: 1)
            } else {
                // O traço do gráfico é um dos usos permitidos do `AccentTint`
                // (DESIGN-SYSTEM.md seção 1).
                RoundedRectangle(cornerRadius: Medidas.graficoCantoBarra)
                    .fill(Color.destaque)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: altura)
        .accessibilityLabel(Text(verbatim: Formato.diaEMes(semana.inicio)))
        .accessibilityValue(Text(verbatim: "\(Formato.metros(semana.metrosM)) m"))
    }
}

/// Uma linha da lista de sessões (tela P4).
private struct LinhaDeSessao: View {

    let sessao: SessaoDoHistorico

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: sessao.titulo ?? Formato.dataPorExtenso(sessao.iniciadaEm))
                    .font(.body)
                    .foregroundStyle(Color.textoPrimario)

                HStack(spacing: 6) {
                    Text(verbatim: Formato.dataPorExtenso(sessao.iniciadaEm))
                    if sessao.origemExterna {
                        // Selo "fora do app": `Label` com `arrow.up.forward`,
                        // `.caption2`, cor secundária. Não é demérito, é
                        // contexto — sem ele o usuário veria um treino que não
                        // reconhece e acharia que o app inventou.
                        Label {
                            Text(Copy.historicoForaDoApp)
                        } icon: {
                            Image(systemName: Simbolos.foraDoApp)
                        }
                        .font(.caption2)
                    }
                }
                .font(.footnote)
                .foregroundStyle(Color.textoSecundario)
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text(verbatim: "\(Formato.metros(sessao.distanciaM)) m")
                .font(.metragemSerie)
                .foregroundStyle(Color.textoSecundario)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Sem autorização de leitura: explica e oferece o caminho, **sem quebrar**
/// (critério 8.10).
private struct SemAutorizacao: View {

    @Environment(\.openURL) private var abrirURL

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(Copy.historicoSemAutorizacaoTitulo)
            } icon: {
                Image(systemName: Simbolos.semAutorizacao)
            }
        } description: {
            Text(Copy.historicoSemAutorizacaoCorpo)
        } actions: {
            Button {
                // No iPhone existe caminho de verdade para os Ajustes do app.
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    abrirURL(url)
                }
            } label: {
                Text(Copy.historicoAbrirAjustes)
            }
        }
    }
}
