import SwiftData
import SwiftUI

/// A raiz de navegação do iPhone (DESIGN-SYSTEM.md seção 3).
///
/// `TabView` nativa com três abas — Treino, Favoritos, Histórico —, cada uma
/// com seu `NavigationStack`. **Ajustes não é aba**: é uma engrenagem na barra
/// de navegação da Home. Sem menu lateral e sem botão flutuante próprio.
///
/// O glyph da aba ativa fica no `.tint` do app, e **a cápsula atrás dele é do
/// sistema** — não é redesenhada em cor de marca (guardrail 4).
///
/// Ajustes é uma engrenagem na barra de navegação da Home, **não uma aba**.
struct RootView: View {

    let catalogo: CatalogStore

    @Environment(\.modelContext) private var context

    /// Escuta as gravações e empurra o estado para o relógio (épico 8.6).
    ///
    /// Vive aqui, na raiz, porque tem que durar o app inteiro: criado dentro de
    /// uma tela, ele morreria ao trocar de aba e a sincronização pararia sem
    /// aviso.
    @State private var coordenadorDeSincronizacao: SyncCoordinator?

    /// O direito de compra (épico 8.11). Vive na raiz porque a Home, os Ajustes
    /// e o paywall precisam do mesmo estado.
    @State private var compras = PurchaseService()

    var body: some View {
        TabView {
            Tab {
                NavigationStack {
                    HomeView(repositorio: repositorio, catalogo: catalogo, compras: compras)
                }
            } label: {
                Label {
                    Text(Copy.abaTreino)
                } icon: {
                    Image(systemName: Simbolos.abaTreino)
                }
            }

            Tab {
                NavigationStack {
                    FavoritesView(catalogo: catalogo)
                }
            } label: {
                Label {
                    Text(Copy.abaFavoritos)
                } icon: {
                    Image(systemName: Simbolos.abaFavoritos)
                }
            }

            Tab {
                NavigationStack {
                    HistoryView()
                }
            } label: {
                Label {
                    Text(Copy.abaHistorico)
                } icon: {
                    Image(systemName: Simbolos.abaHistorico)
                }
            }
        }
        .task {
            await compras.carregar()
            guard coordenadorDeSincronizacao == nil else { return }
            let coordenador = SyncCoordinator(
                context: context, versaoDoCatalogo: catalogo.catalogVersion)
            coordenador.iniciar()
            coordenadorDeSincronizacao = coordenador
        }
    }

    /// O repositório de preferências deste aparelho.
    ///
    /// A versão do catálogo embarcado vai junto porque o seed a grava, para
    /// instalação nova não ver banner de novidade no primeiro dia (spec 7.7).
    private var repositorio: PreferencesRepository {
        PreferencesRepository(context: context, versaoCatalogoEmbarcada: catalogo.catalogVersion)
    }
}
