import SwiftUI

/// W4 — Pré-visualização do treino (critério 8.7).
///
/// Lê: o treino e a piscina configurada.
/// Escreve: nada aqui; a execução é do épico 8.8.
///
/// ## A linha da piscina é mitigação de risco, não decoração
///
/// `Raia de {n} m` (copy 15.6) aparece **destacada e tocável** porque o risco R1
/// é o pior do produto: nadar em 50 m com o app configurado em 25 m faz toda a
/// distância sair errada, o descanso disparar na hora errada e o HealthKit
/// receber dado falso. **Não há detecção automática possível** — a única defesa é
/// o nadador ver o número antes de entrar na água e poder corrigi-lo ali mesmo.
///
/// O número mostrado é o do **treino**, congelado na geração (spec 7.4), não o
/// das preferências: é para essa piscina que as distâncias foram adaptadas.
struct WatchPreviewView: View {

    // A compra é verificada aqui, e não na tela de execução: descobrir o
    // bloqueio depois da contagem de 3 segundos, com o Water Lock já ligado,
    // seria o pior momento possível.

    let store: WatchStore
    /// Nulo quando a tela vem dos Favoritos: trocar a piscina ali não regenera
    /// nada, só corrige a configuração para as próximas gerações.
    let catalogo: CatalogStore?
    let treino: Treino

    @State private var trocandoPiscina = false
    @State private var executando = false
    @State private var bloqueadoPelaCompra = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(verbatim: WatchFormato.metros(treino.distanciaTotalM))
                        .font(.watch(WatchTipografia.distanciaDestaque, .bold))
                        .foregroundStyle(Color.watchTextoPrimario)
                    Text(WatchCopy.unidadeMetros)
                        .font(.watch(WatchTipografia.rotulo))
                        .foregroundStyle(Color.watchTextoSecundario)
                }

                // A forma do treino numa linha só: o nadador confere antes de
                // entrar na água.
                Text(verbatim: WatchFormato.resumoDeSeries(treino))
                    .font(.watch(WatchTipografia.rotulo, .regular))
                    .foregroundStyle(Color.watchTextoSecundario)
                    .fixedSize(horizontal: false, vertical: true)

                // Mitigação do risco R1.
                Button {
                    trocandoPiscina = true
                } label: {
                    HStack {
                        Text(WatchCopy.raiaDe(treino.tamanhoRaiaM))
                            .font(.watch(WatchTipografia.rotulo))
                            .foregroundStyle(Color.watchNadando)
                        Spacer(minLength: 4)
                        Text(WatchCopy.previaTrocar)
                            .font(.watch(WatchTipografia.rotulo, .regular))
                            .foregroundStyle(Color.watchTextoSecundario)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    Task { await tentarIniciar() }
                } label: {
                    Text(WatchCopy.previaIniciar)
                        .frame(maxWidth: .infinity)
                }
                .tint(Color.watchNadando)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(Text(verbatim: treino.titulo ?? String(localized: WatchCopy.appNome)))
        .fundoDoRelogio()
        .navigationDestination(isPresented: $trocandoPiscina) {
            WatchPoolSizeView(store: store) { trocandoPiscina = false }
        }
        // A execução ocupa a tela inteira e não tem barra de navegação: o Water
        // Lock está ligado e o botão voltar seria inalcançável (princípio 0.1).
        .alert(WatchCopy.compraTitulo, isPresented: $bloqueadoPelaCompra) {
            Button(role: .cancel) {} label: { Text(WatchCopy.acaoVoltar) }
        } message: {
            Text(WatchCopy.compraCorpo)
        }
        .fullScreenCover(isPresented: $executando) {
            WatchSessionView(
                controlador: WorkoutSessionController(treino: treino, store: store)
            ) {
                executando = false
            }
        }
    }

    /// Verifica o direito antes de iniciar (regra 11.17 e critério 8.11).
    ///
    /// **Gerar é sempre livre**; o que a compra destrava é a execução guiada.
    ///
    /// A verificação acontece **aqui**, e não na tela de execução: descobrir o
    /// bloqueio depois da contagem de 3 segundos, com o Water Lock já ligado e o
    /// nadador na borda, seria o pior momento possível.
    private func tentarIniciar() async {
        let direito = await store.apurarDireito()
        guard
            PurchaseGate.podeExecutar(
                comprado: direito.comprado, execucoesFeitas: store.execucoesFeitas())
        else {
            bloqueadoPelaCompra = true
            return
        }
        executando = true
    }
}
