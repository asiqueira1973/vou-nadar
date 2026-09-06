import SwiftUI

/// W2 — Gerar treino no relógio (critério 8.7).
///
/// Lê: `preferencias`, `equipamento_selecionado` e o catálogo embarcado.
/// Escreve: `preferencias`, `equipamento_selecionado` e o treino gerado.
///
/// **Gera com o iPhone desligado, identicamente** (princípio 0.5): o motor é o
/// mesmo `WorkoutGenerator`, o catálogo é o mesmo JSON embarcado, e a tabela de
/// descanso é a mesma. Não há chamada de rede e não há consulta ao iPhone.
///
/// A faixa é ajustada **pela coroa digital** (critério 8.7): na água ninguém
/// acerta um puxador de slider, e no vestiário com a mão molhada também não.
struct WatchGenerateView: View {

    let store: WatchStore
    let catalogo: CatalogStore

    /// A faixa em passos de 100 m, controlada pela coroa.
    ///
    /// A coroa entrega `Double`; o valor é convertido para múltiplo de 100 na
    /// leitura, porque a geração sorteia o alvo entre os múltiplos de 100 da
    /// faixa pedida.
    @State private var faixaBruta: Double = 1500
    @State private var minM = 1500
    @State private var maxM = 2500
    @State private var equipamentos: Set<String> = []
    @State private var incluirEducativos = false
    @State private var incluirPernada = false
    @State private var tamanhoRaiaM = 25
    @State private var raiaConfirmada = false

    /// O treino recém-gerado, que empurra a pré-visualização.
    @State private var treinoGerado: Treino?

    /// A piscina obrigatória, quando ainda não foi confirmada (regra 11.4).
    @State private var pedindoPiscina = false

    @FocusState private var coroaFocada: Bool

    var body: some View {
        List {
            Section {
                // A faixa: um número grande, ajustado pela coroa. Não é slider —
                // slider no pulso molhado não funciona.
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(verbatim: WatchFormato.faixa(minM: minM, maxM: maxM))
                            .font(.watch(WatchTipografia.distanciaDestaque, .bold))
                            .foregroundStyle(Color.watchTextoPrimario)
                            // `1.500–2.500` não cabe em 34 pt na caixa de 46 mm
                            // e quebrava em duas linhas, empurrando o "m" para
                            // o meio. Encolher é melhor que quebrar: o número
                            // continua sendo o elemento dominante da tela.
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(WatchCopy.unidadeMetros)
                            .font(.watch(WatchTipografia.rotulo))
                            .foregroundStyle(Color.watchTextoSecundario)
                    }
                    Text(WatchCopy.gerarAjudaDaCoroa)
                        .font(.watch(WatchTipografia.rotulo, .regular))
                        .foregroundStyle(Color.watchTextoSecundario)
                }
                .listRowBackground(Color.clear)
                .focusable()
                .focused($coroaFocada)
                .digitalCrownRotation(
                    $faixaBruta,
                    from: Double(FaixaDeDistancia.limites.lowerBound),
                    through: Double(FaixaDeDistancia.limites.upperBound),
                    by: Double(FaixaDeDistancia.passo),
                    sensitivity: .low,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true)
                .onChange(of: faixaBruta) { _, novo in ajustarFaixa(para: novo) }
                .accessibilityElement()
                .accessibilityLabel(Text(WatchCopy.gerarTitulo))
                .accessibilityValue(
                    Text(verbatim: WatchFormato.faixa(minM: minM, maxM: maxM)))
            }

            Section {
                // Os quatro equipamentos (critério 8.7). Linha de lista com
                // marcador, nunca cápsula colorida.
                ForEach(catalogo.selectableEquipment) { equipamento in
                    Toggle(isOn: ligacao(para: equipamento.equipamento_id)) {
                        Text(verbatim: equipamento.nome)
                            .font(.watch(WatchTipografia.rotulo, .regular))
                    }
                }
            } header: {
                Text(WatchCopy.equipamentoTitulo)
            }

            Section {
                Button {
                    gerar()
                } label: {
                    Text(WatchCopy.inicioGerarTreino)
                        .frame(maxWidth: .infinity)
                }
                .tint(Color.watchNadando)
            }
        }
        .navigationTitle(Text(WatchCopy.gerarTitulo))
        .fundoDoRelogio()
        .navigationDestination(item: $treinoGerado) { treino in
            WatchPreviewView(store: store, catalogo: catalogo, treino: treino)
        }
        // Sem `raia_confirmada`, gerar leva à tela de piscina antes
        // (regra 11.4 e critério 8.7).
        .navigationDestination(isPresented: $pedindoPiscina) {
            WatchPoolSizeView(store: store) {
                pedindoPiscina = false
                carregar()
            }
        }
        .task {
            carregar()
            coroaFocada = true
        }
    }

    // MARK: - Estado

    private func carregar() {
        guard let prefs = try? store.preferencias.preferenciasAtuais() else { return }
        minM = prefs.distanciaMinM
        maxM = prefs.distanciaMaxM
        faixaBruta = Double(prefs.distanciaMinM)
        incluirEducativos = prefs.incluirEducativos
        incluirPernada = prefs.incluirPernada
        tamanhoRaiaM = prefs.tamanhoRaiaM
        raiaConfirmada = prefs.raiaConfirmada
        equipamentos = (try? store.preferencias.equipamentosSelecionados()) ?? []
    }

    /// A coroa ajusta o **piso** da faixa, e o teto acompanha mantendo a largura.
    ///
    /// Uma coroa só não controla dois valores. Mover o piso e arrastar o teto
    /// junto preserva a intenção — "quero um treino em torno de tanto" — sem
    /// exigir um segundo controle numa tela onde não cabe.
    private func ajustarFaixa(para valor: Double) {
        let largura = max(0, maxM - minM)
        let novoMin = Int(valor)
        minM = novoMin
        maxM = min(FaixaDeDistancia.limites.upperBound, novoMin + largura)
        try? store.preferencias.atualizarFaixa(minM: minM, maxM: maxM)
    }

    private func ligacao(para id: String) -> Binding<Bool> {
        Binding(
            get: { equipamentos.contains(id) },
            set: { marcado in
                try? store.preferencias.definirEquipamento(id, selecionado: marcado)
                equipamentos = (try? store.preferencias.equipamentosSelecionados()) ?? equipamentos
            })
    }

    // MARK: - Geração

    /// Gera e grava o treino no store do relógio (critério 8.7).
    ///
    /// **Aqui o treino é gravado na hora**, ao contrário do iPhone, onde a
    /// gravação espera o favoritar. O motivo é o contexto: no pulso não há
    /// "Gerar outro" numa tela de detalhe com calma — o nadador gera e entra na
    /// água, e um treino que existe só em memória se perde se o app for
    /// descartado pelo sistema no caminho até a borda.
    ///
    /// Sai como `gerado_watch`: fica só no relógio no v1 (regra 11.18).
    private func gerar() {
        guard raiaConfirmada else {
            pedindoPiscina = true
            return
        }

        // Regra 11.3: o catálogo é adaptado à piscina antes do sorteio.
        let adaptado = AdaptedCatalog(
            catalogo: catalogo.allExercises, tamanhoRaiaM: tamanhoRaiaM)
        let ritmo = (try? store.preferencias.preferenciasAtuais().ritmoDescanso) ?? .normal

        var rng = SystemRandomNumberGenerator()
        let resultado = WorkoutGenerator(catalogo: adaptado).gerar(
            GenerationRequest(
                minMeters: minM, maxMeters: maxM,
                selectedEquipment: equipamentos,
                includeDrills: incluirEducativos, includeKick: incluirPernada,
                laneLengthM: tamanhoRaiaM, restPace: ritmo),
            using: &rng)

        treinoGerado = try? store.treinos.salvar(
            resultado, origem: .gerado_watch, faixaPedida: minM...maxM)
    }
}
