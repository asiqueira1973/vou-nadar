import SwiftUI
import UIKit

/// P2 — Detalhe do treino (critérios 8.4 e 8.5).
///
/// Lê: o `WorkoutPresentation`, que já traz tudo congelado pela geração.
/// Escreve: nada diretamente — favoritar é uma fechadura que o chamador
/// entrega, porque quem sabe persistir é o repositório, não a tela.
///
/// Estrutura (DESIGN-SYSTEM.md seção 3): numeral herói **fora** do `List`, e um
/// `List` com as quatro `Section` da regra 11.1. O bloco do herói é um dos
/// **exatamente dois** contêineres desenhados à mão que o design system permite
/// — o outro é o gráfico do Histórico.
///
/// **A tela não recalcula nada.** Descanso, distância adaptada e voltas foram
/// congelados na geração (princípio 0.6); aqui é leitura pura.
struct WorkoutDetailView: View {

    let treino: WorkoutPresentation

    /// Favorita o treino com o título digitado (regra 11.14).
    ///
    /// `nil` quando o treino já é favorito — e aí a barra inferior não aparece.
    var aoFavoritar: ((String) throws -> Void)?

    /// Gera outro treino com os mesmos parâmetros. Vai no menu da barra.
    var aoGerarOutro: (() -> Void)?

    /// Valor exibido no herói. Anima de 0 até o total em 0,4 s — **a única
    /// animação do app inteiro** (DESIGN-SYSTEM.md seção 8).
    @State private var distanciaExibida = 0

    /// O alerta que pede o título ao favoritar (regra 11.14).
    @State private var pedindoTitulo = false
    @State private var tituloDigitado = ""
    @State private var erroDoTitulo: String?

    /// A confirmação "Treino copiado." (copy 15.19). Some sozinha.
    @State private var mostrandoConfirmacaoDeCopia = false

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    var body: some View {
        listaDasSecoes
            // O herói fica FORA do `List`, acima dele.
            .safeAreaInset(edge: .top, spacing: 0) {
                NumeralHeroi(distanciaExibida: distanciaExibida, treino: treino)
            }
            .safeAreaInset(edge: .bottom) { barraInferior }
            .navigationTitle(tituloDaBarra)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { menuDaBarra }
            .alert(Text(Copy.detalheFavoritarTitulo), isPresented: $pedindoTitulo) {
                TextField(text: $tituloDigitado) { Text(Copy.detalheFavoritarCampo) }
                Button(role: .cancel) { tituloDigitado = "" } label: {
                    Text(Copy.acaoCancelar)
                }
                Button { confirmarFavoritar() } label: { Text(Copy.acaoSalvar) }
            } message: {
                Text(Copy.detalheFavoritarAjuda)
            }
            .alert(
                Text(Copy.detalheFavoritarTitulo),
                isPresented: Binding(
                    get: { erroDoTitulo != nil }, set: { if !$0 { erroDoTitulo = nil } }),
                presenting: erroDoTitulo
            ) { _ in
                Button(role: .cancel) { erroDoTitulo = nil } label: { Text(Copy.acaoEntendi) }
            } message: { mensagem in
                Text(mensagem)
            }
            .task { animarNumeral() }
    }

    // MARK: - Partes

    /// As quatro seções da regra 11.1, cada uma numa `Section` do `List`.
    private var listaDasSecoes: some View {
        List {
            ForEach(treino.secoes, id: \.tipo) { secao in
                Section {
                    if secao.estaVazia {
                        // Seção vazia é uma linha comum com texto secundário.
                        // **Nunca esconder a Section** (DESIGN-SYSTEM.md seção 3):
                        // sumir com um cabeçalho faz o usuário achar que o app
                        // perdeu conteúdo, e a regra 11.1 exige as quatro.
                        Text(Copy.detalheSecaoSemSerie)
                            .font(.footnote)
                            .foregroundStyle(Color.textoSecundario)
                    } else {
                        ForEach(secao.series) { serie in
                            LinhaDeSerie(serie: serie)
                        }
                    }
                } header: {
                    CabecalhoDeSecao(tipo: secao.tipo)
                }
            }
        }
        .listaDoApp()
    }

    /// A barra inferior: a confirmação de cópia por cima do botão Favoritar
    /// (DESIGN-SYSTEM.md seção 3).
    @ViewBuilder
    private var barraInferior: some View {
        VStack(spacing: 0) {
            if mostrandoConfirmacaoDeCopia {
                ConfirmacaoDeCopia()
                    // A confirmação é informação, não decoração: entra sem
                    // animação quando Reduce Motion está ligado.
                    .transition(reduzirMovimento ? .identity : .opacity)
            }
            if aoFavoritar != nil {
                BarraDeAcaoPrimaria(acao: { pedindoTitulo = true }) {
                    Text(Copy.detalheFavoritar)
                }
            }
        }
    }

    /// "Copiar como texto" e "Gerar outro", no menu da barra (regra 14.3 e
    /// DESIGN-SYSTEM.md seção 3).
    ///
    /// As duas ações secundárias ficam aqui, e **não** como um terceiro botão
    /// grande empilhado (regra 14.3).
    @ToolbarContentBuilder
    private var menuDaBarra: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button(action: copiarComoTexto) {
                    Label {
                        Text(Copy.detalheCopiarComoTexto)
                    } icon: {
                        Image(systemName: Simbolos.copiar)
                    }
                }
                if let aoGerarOutro {
                    Button(action: aoGerarOutro) {
                        Label {
                            Text(Copy.detalheGerarOutro)
                        } icon: {
                            Image(systemName: Simbolos.abaTreino)
                        }
                    }
                }
            } label: {
                Image(systemName: Simbolos.menu)
            }
            .accessibilityLabel(Text(Copy.a11yMaisAcoes))
        }
    }

    /// Título da barra: o do favorito, ou "Treino de {data curta}" enquanto não
    /// houver (regra 11.14).
    private var tituloDaBarra: Text {
        if let titulo = treino.titulo, !titulo.isEmpty { return Text(verbatim: titulo) }
        return Text(Copy.detalheTituloProvisorio(treino.criadoEm))
    }

    // MARK: - Ações

    /// Copia o treino como texto (seção 14 e regra 14.2.9).
    ///
    /// **Um toque e acabou**: sem folha de compartilhamento e sem tela
    /// intermediária. Dispara háptico de sucesso e mostra a confirmação 15.19,
    /// que some sozinha depois de dois segundos.
    private func copiarComoTexto() {
        UIPasteboard.general.string = WorkoutTextExporter.texto(de: treino)
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(reduzirMovimento ? nil : .easeOut(duration: 0.2)) {
            mostrandoConfirmacaoDeCopia = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(reduzirMovimento ? nil : .easeOut(duration: 0.2)) {
                mostrandoConfirmacaoDeCopia = false
            }
        }
    }

    /// Confirma o favoritar, deixando a validação da regra 11.14 com o
    /// repositório — a tela não reimplementa a regra, só mostra o erro.
    private func confirmarFavoritar() {
        do {
            try aoFavoritar?(tituloDigitado)
            tituloDigitado = ""
        } catch let falha as WorkoutError {
            erroDoTitulo = falha.mensagemParaUsuario
        } catch {
            erroDoTitulo = String(describing: error)
        }
    }

    /// A única animação do app: o numeral conta de 0 até o total em 0,4 s com
    /// `easeOut` (DESIGN-SYSTEM.md seção 8).
    ///
    /// Com Reduce Motion ligado o valor final aparece direto, sem contagem.
    private func animarNumeral() {
        guard !reduzirMovimento else {
            distanciaExibida = treino.distanciaTotalM
            return
        }
        distanciaExibida = 0
        withAnimation(.easeOut(duration: 0.4)) {
            distanciaExibida = treino.distanciaTotalM
        }
    }
}

/// A faixa "Treino copiado." (copy 15.19, DESIGN-SYSTEM.md seção 3).
///
/// Fundo `SurfaceElevated`, canto 12 pt — o **único** raio de canto permitido em
/// contêiner desenhado à mão (guardrail 3) — e o símbolo em `StatusSuccess`, que
/// é o único uso desse token no app inteiro.
private struct ConfirmacaoDeCopia: View {
    var body: some View {
        Label {
            Text(Copy.detalheTreinoCopiado)
                .font(.footnote)
                .foregroundStyle(Color.textoPrimario)
        } icon: {
            Image(systemName: Simbolos.confirmacaoCopia)
                .foregroundStyle(Color.statusSucesso)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.superficieElevada, in: RoundedRectangle(cornerRadius: Medidas.canto))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

/// O bloco do numeral herói (DESIGN-SYSTEM.md seções 3 e 5).
///
/// **Contêiner desenhado à mão**, um dos dois permitidos: `VStack` alinhado à
/// esquerda, padding horizontal 20 pt e inferior 10 pt, sem borda.
private struct NumeralHeroi: View {

    let distanciaExibida: Int
    let treino: WorkoutPresentation

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: treino.teveDistanciaAjustada
                ? Medidas.heroiEspacamentoComNota : Medidas.heroiEspacamento
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: Formato.metros(distanciaExibida))
                    // `.largeTitle` bold, SF Pro Rounded, dígitos mono — o único
                    // lugar do app com Rounded.
                    .font(.heroiNumeral)
                    .foregroundStyle(Color.textoPrimario)
                    // Sem isto o número pula de largura a cada quadro da
                    // contagem, porque só os dígitos são monoespaçados.
                    .contentTransition(.numericText())
                Text(Copy.unidadeMetros)
                    .font(.heroiUnidade)
                    .foregroundStyle(Color.textoSecundario)
            }

            HStack(spacing: 6) {
                Text(Copy.heroiTotal)
                if treino.vezesExecutado > 0 {
                    Text(verbatim: "\u{00B7}")
                    Text(Copy.heroiFeitoVezes(treino.vezesExecutado))
                }
            }
            .font(.caption)
            .foregroundStyle(Color.textoSecundario)

            // Copy 15.18, só quando a adaptação à raia mexeu em alguma série
            // (regra 11.3 e risco R2b).
            if treino.teveDistanciaAjustada {
                Text(Copy.detalheDistanciasAjustadas(treino.tamanhoRaiaM))
                    .font(.footnote)
                    .foregroundStyle(Color.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Medidas.heroiPaddingHorizontal)
        .padding(.bottom, Medidas.heroiPaddingInferior)
        .background(Color.fundoPrimario)
        .accessibilityElement(children: .combine)
    }
}

/// O header de uma `Section` do treino (DESIGN-SYSTEM.md seções 3 e 5).
///
/// `HStack` com um `RoundedRectangle` de **14 × 3 pt**, canto 2 pt, na cor da
/// seção, e o texto em **Title Case** — nunca caixa alta (guardrail 6). O traço
/// é o único uso permitido das quatro cores de seção: nunca fundo, nunca faixa
/// larga, nunca cor de texto.
private struct CabecalhoDeSecao: View {

    let tipo: TipoSecao

    var body: some View {
        HStack(spacing: Medidas.tracoSecaoEspacamento) {
            RoundedRectangle(cornerRadius: Medidas.tracoSecaoCanto)
                .fill(tipo.cor)
                .frame(width: Medidas.tracoSecaoLargura, height: Medidas.tracoSecaoAltura)
                .accessibilityHidden(true)
            Text(tipo.tituloNaTela)
        }
    }
}

/// Uma linha de série (DESIGN-SYSTEM.md seção 3).
///
/// `HStack` com um `VStack` à esquerda — selo, nome, descrição — e um
/// `VStack(alignment: .trailing)` à direita — metragem e descanso. O alinhamento
/// dos números vem de `.monospacedDigit()`, **não** de `.frame(width:)`
/// (guardrail 8).
private struct LinhaDeSerie: View {

    let serie: WorkoutPresentation.SerieApresentada

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                if let selo = serie.modo.selo {
                    Label {
                        Text(selo.texto)
                    } icon: {
                        Image(systemName: selo.simbolo)
                    }
                    .font(.caption2)
                    .foregroundStyle(Color.textoSecundario)
                }

                // O nome vai **sem** o prefixo `NxM` do catálogo: a metragem já
                // está na coluna da direita, e o número embutido no nome é o do
                // catálogo, que numa piscina incomum contradiz o adaptado.
                Text(verbatim: ExerciseName.semPrefixoDeSerie(serie.nome))
                    .font(.body)
                    .foregroundStyle(Color.textoPrimario)

                Text(verbatim: serie.descricao)
                    .font(.footnote)
                    .foregroundStyle(Color.textoSecundario)
            }
            // Dynamic Type até AX5 sem truncar (DESIGN-SYSTEM.md seção 9).
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 3) {
                // A distância é a REAL, já adaptada à raia (regra 11.3): numa
                // piscina de 16 m sai `4×96`, e é isso que o nadador vai nadar.
                Text(verbatim: "\(serie.repeticoes)\u{00D7}\(serie.distanciaM) m")
                    .font(.metragemSerie)
                    .foregroundStyle(Color.textoSecundario)

                // Série de uma repetição só não tem descanso interno: não há
                // "entre as repetições" quando só existe uma (spec 7.2).
                if serie.descansoSeg > 0 {
                    Text(verbatim: "\(serie.descansoSeg)s")
                        .font(.descansoSerie)
                        .foregroundStyle(Color.textoSecundario)
                }

                if let equipamento = serie.simboloDoEquipamento {
                    Image(systemName: equipamento)
                        .font(.caption)
                        .foregroundStyle(Color.textoSecundario)
                        .accessibilityHidden(true)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
