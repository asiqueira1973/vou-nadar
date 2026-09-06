import SwiftData
import SwiftUI

/// W1 — Início do relógio (critério 8.7).
///
/// Lê: as sessões locais, para o volume da semana.
/// Escreve: nada.
///
/// Duas ações e um número. É a tela que o nadador vê no vestiário, com o dedo
/// seco e pressa — o inventário da seção 10 pede exatamente isso e nada mais.
///
/// **Navegação inteiramente pela coroa** (critério 8.7): a tela é uma `List`, e
/// `List` do watchOS rola pela coroa por padrão. Nenhum alvo depende de toque
/// preciso.
struct WatchHomeView: View {

    let store: WatchStore
    let catalogo: CatalogStore

    /// Metros nadados na semana corrente (regra 11.16).
    @State private var volumeDaSemanaM = 0

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text(WatchCopy.inicioEstaSemana)
                        .font(.watch(WatchTipografia.rotulo))
                        .foregroundStyle(Color.watchTextoSecundario)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(verbatim: WatchFormato.metros(volumeDaSemanaM))
                            .font(.watch(WatchTipografia.distanciaDestaque, .bold))
                            .foregroundStyle(Color.watchTextoPrimario)
                        Text(WatchCopy.unidadeMetros)
                            .font(.watch(WatchTipografia.rotulo))
                            .foregroundStyle(Color.watchTextoSecundario)
                    }
                }
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .combine)
            }

            Section {
                NavigationLink {
                    WatchGenerateView(store: store, catalogo: catalogo)
                } label: {
                    Text(WatchCopy.inicioGerarTreino)
                }

                NavigationLink {
                    WatchFavoritesView(store: store)
                } label: {
                    Text(WatchCopy.inicioFavoritos)
                }
            }
        }
        .navigationTitle(Text(WatchCopy.appNome))
        .fundoDoRelogio()
        .task { carregarVolume() }
    }

    /// Soma os metros das sessões desta semana (regra 11.16).
    ///
    /// A semana começa na **segunda-feira**, no fuso do aparelho no momento da
    /// consulta, e uma sessão que atravessa a meia-noite conta na semana do
    /// `iniciada_em`.
    ///
    /// Lê as sessões **locais** do relógio. O Histórico completo, que junta o
    /// que veio de outros apps pelo HealthKit, é do iPhone (épico 8.10) — o
    /// relógio mostra o que ele mesmo gravou.
    private func carregarVolume() {
        let inicio = Semana.inicioDaSemanaAtual()
        let descritor = FetchDescriptor<SessaoNatacao>(
            predicate: #Predicate { $0.iniciadaEm >= inicio })
        let sessoes = (try? store.context.fetch(descritor)) ?? []
        volumeDaSemanaM = sessoes.reduce(0) { $0 + $1.distanciaRealM }
    }
}
