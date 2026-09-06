import SwiftData
import SwiftUI

/// Ponto de entrada do app do Apple Watch (spec 4.2).
///
/// Carrega o **mesmo** catálogo embarcado do iPhone e abre um **store SwiftData
/// próprio** (critério 8.7, spec 4.1). É isso que honra o princípio 0.5: gerar,
/// executar, encerrar e gravar funcionam com o iPhone desligado, longe e sem
/// internet. A sincronização é conforto, nunca requisito.
@main
struct VouNadarWatchApp: App {

    private let catalogo: Result<CatalogStore, Error>
    private let container: Result<ModelContainer, Error>

    init() {
        catalogo = Result { try CatalogStore() }
        container = Result { try ModelContainer.vouNadar() }

        // A sessão é ativada AQUI, no ponto mais cedo que existe.
        //
        // Ativar numa `.task` de View perde entrega: o `WCSession` processa a
        // fila assim que ativa, e o que chega antes de o delegate existir é
        // consumido sem chamar ninguém. Medido no simulador, o sistema entregou
        // o conteúdo 10 ms antes de a ativação completar.
        //
        // O destino ainda não existe neste instante — o `ModelContext` vem do
        // ambiente. O serviço guarda o que chegar e drena no `conectar`.
        MainActor.assumeIsolated { WatchSyncService.compartilhado.ativar() }
    }

    var body: some Scene {
        WindowGroup {
            switch (catalogo, container) {
            case (.success(let catalogo), .success(let container)):
                WatchRootView(catalogo: catalogo)
                    .modelContainer(container)
            case (.failure(let erro), _), (_, .failure(let erro)):
                WatchCatalogFailureView(erro: erro)
            }
        }
    }
}

/// A raiz de navegação do relógio.
///
/// `NavigationStack` único: o relógio não tem abas, e a navegação inteira é pela
/// coroa e pelo voltar do sistema (critério 8.7).
struct WatchRootView: View {

    let catalogo: CatalogStore

    @Environment(\.modelContext) private var context

    /// O store local e o receptor da sincronização (épico 8.6).
    ///
    /// Vive na raiz porque tem que durar o app inteiro: criado dentro de uma
    /// tela, o serviço morreria ao navegar e o relógio pararia de receber.
    @State private var store: WatchStore?

    /// A pilha de navegação, exposta para a complication conseguir desempilhar.
    @State private var caminho = NavigationPath()

    var body: some View {
        NavigationStack(path: $caminho) {
            if let store {
                WatchHomeView(store: store, catalogo: catalogo)
            } else {
                ProgressView()
            }
        }
        // Tocar na complication abre o app **na tela Início** (critério 8.12).
        //
        // Sem isto o app reabriria onde o usuário tinha parado — no meio dos
        // Favoritos, ou numa pré-visualização — e quem tocou num número de
        // volume semanal não estava pedindo aquilo.
        .onOpenURL { url in
            guard url.scheme == Self.esquema else { return }
            caminho = NavigationPath()
        }
        .task {
            guard store == nil else { return }
            let novo = WatchStore(context: context, versaoDoCatalogo: catalogo.catalogVersion)
            // Garante a linha de preferências antes de qualquer tela lê-la.
            _ = try? novo.preferencias.seedPreferencesIfNeeded()
            store = novo

            WatchSyncService.compartilhado.conectar(destino: novo)
        }
    }
}

extension WatchRootView {

    /// O esquema de URL que a complication usa (critério 8.12).
    ///
    /// Precisa bater com o `widgetURL` do outro target — são dois binários
    /// diferentes e o compilador não liga um ao outro.
    static let esquema = "vounadar"
}

/// Falha fatal da carga do catálogo no relógio (critério 8.1.5).
struct WatchCatalogFailureView: View {

    let erro: Error

    var body: some View {
        Text(verbatim: String(describing: erro))
            .font(.watch(WatchTipografia.rotulo, .regular))
            .foregroundStyle(Color.watchTextoSecundario)
            .fundoDoRelogio()
    }
}
