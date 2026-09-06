import SwiftData
import SwiftUI

/// Ponto de entrada do app do iPhone (spec 4.2).
///
/// Recebe: nada.
/// Devolve: a cena única do app, em retrato (spec 4.1).
///
/// O catálogo é carregado uma vez aqui e passado adiante, porque falhar a carga
/// é falha fatal controlada (critério 8.1.5): sortear exercício de um arquivo
/// violado produziria treino errado em silêncio, e o princípio 0.6 proíbe isso.
@main
struct VouNadarApp: App {

    /// Resultado da carga do catálogo embarcado. Carregado uma vez na
    /// inicialização e imutável daí em diante (spec 7.13).
    private let catalog: Result<CatalogStore, Error>

    /// O store SwiftData deste aparelho (spec 4.1: um store por aparelho, sem
    /// CloudKit no v1).
    private let container: Result<ModelContainer, Error>

    init() {
        catalog = Result { try CatalogStore() }
        container = Result { try ModelContainer.vouNadar() }
    }

    var body: some Scene {
        WindowGroup {
            switch (catalog, container) {
            case (.success(let store), .success(let container)):
                RootView(catalogo: store)
                    .modelContainer(container)
            case (.failure(let erro), _), (_, .failure(let erro)):
                CatalogFailureView(erro: erro)
            }
        }
    }
}

/// Tela de falha fatal da carga do catálogo (critério 8.1.5).
///
/// Só é alcançável por build quebrado — o catálogo vive no bundle assinado e
/// nunca depende de rede nem de dado do usuário (princípio 0.4).
struct CatalogFailureView: View {

    let erro: Error

    var body: some View {
        ContentUnavailableView(
            "Não foi possível abrir o catálogo",
            systemImage: Simbolos.avisoRepertorioCurto,
            description: Text(String(describing: erro)))
    }
}
