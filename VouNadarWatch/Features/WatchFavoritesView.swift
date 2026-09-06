import SwiftData
import SwiftUI

/// W3 — Favoritos no relógio (critério 8.7).
///
/// Lê: os treinos executáveis do store local.
/// Escreve: nada.
///
/// Lista **os favoritos vindos do iPhone e os gerados aqui** (regra 11.18): para
/// o nadador na borda a origem é irrelevante, e separá-los em duas listas seria
/// pedir uma decisão que ele não tem por que tomar.
///
/// **Nada aqui depende do iPhone.** Com o relógio nunca pareado a lista aparece
/// vazia com a copy 15.4, e nada quebra (fluxo 9.5).
struct WatchFavoritesView: View {

    let store: WatchStore

    @Query(
        filter: #Predicate<Treino> { $0.arquivadoEm == nil },
        sort: \Treino.atualizadoEm, order: .reverse)
    private var treinos: [Treino]

    var body: some View {
        Group {
            if treinos.isEmpty {
                // Copy 15.4, literal. As duas linhas viram título e corpo.
                ContentUnavailableView {
                    Text(WatchCopy.favoritosVazioTitulo)
                } description: {
                    Text(WatchCopy.favoritosVazioCorpo)
                }
            } else {
                List(treinos) { treino in
                    NavigationLink {
                        WatchPreviewView(store: store, catalogo: nil, treino: treino)
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: treino.titulo ?? "")
                                .font(.watch(WatchTipografia.rotulo))
                                .foregroundStyle(Color.watchTextoPrimario)
                            Text(verbatim: "\(WatchFormato.metros(treino.distanciaTotalM)) m")
                                .font(.watch(WatchTipografia.rotulo, .regular))
                                .foregroundStyle(Color.watchTextoSecundario)
                        }
                    }
                }
            }
        }
        .navigationTitle(Text(WatchCopy.favoritosTitulo))
        .fundoDoRelogio()
    }
}
