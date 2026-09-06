import SwiftData
import SwiftUI

/// P3 — Favoritos (critério 8.5).
///
/// Lê: `treino` onde `favorito == true` e `arquivado_em == nil`.
/// Escreve: renomear e arquivar (soft delete).
///
/// A lista ordena por `atualizado_em` **decrescente**, e o estado vazio explica
/// o que fazer em vez de ser uma lista vazia sem texto.
///
/// **Apagar aqui é soft delete** (regra 11.15): o treino some desta lista, mas
/// as sessões dele continuam no Histórico e no volume da semana. Apagar de
/// verdade apagaria histórico de saúde do usuário junto, e esse dado não é do
/// app (spec 7.10 e seção 20).
struct FavoritesView: View {

    let catalogo: CatalogStore

    @Environment(\.modelContext) private var context

    /// Os favoritos ativos, ordenados pelo mais recente.
    ///
    /// O filtro de `arquivado_em == nil` está aqui, na consulta, e não numa
    /// filtragem depois: um treino arquivado nunca deve chegar à tela.
    @Query(
        filter: #Predicate<Treino> { $0.favorito && $0.arquivadoEm == nil },
        sort: \Treino.atualizadoEm, order: .reverse)
    private var favoritos: [Treino]

    /// O treino em renomeação, e o texto digitado (regra 11.14).
    @State private var renomeando: Treino?
    @State private var tituloDigitado = ""
    @State private var erro: String?

    var body: some View {
        Group {
            if favoritos.isEmpty {
                // Copy 15.16. Sem botão: gerar é na aba Treino, e um botão aqui
                // duplicaria a ação principal do app noutro lugar.
                ContentUnavailableView {
                    Text(Copy.favoritosVazioTitulo)
                } description: {
                    Text(Copy.favoritosVazioCorpo)
                }
            } else {
                lista
            }
        }
        .navigationTitle(Text(Copy.abaFavoritos))
        .navigationBarTitleDisplayMode(.large)
        .alert(Text(Copy.favoritosRenomear), isPresented: .init(
            get: { renomeando != nil }, set: { if !$0 { renomeando = nil } })
        ) {
            TextField(text: $tituloDigitado) { Text(Copy.detalheFavoritarCampo) }
            Button(role: .cancel) { renomeando = nil } label: { Text(Copy.acaoCancelar) }
            Button { confirmarRenomear() } label: { Text(Copy.acaoSalvar) }
        } message: {
            Text(Copy.detalheFavoritarAjuda)
        }
        .alert(
            Text(Copy.favoritosRenomear),
            isPresented: .init(get: { erro != nil }, set: { if !$0 { erro = nil } }),
            presenting: erro
        ) { _ in
            Button(role: .cancel) { erro = nil } label: { Text(Copy.acaoEntendi) }
        } message: { mensagem in
            Text(mensagem)
        }
    }

    private var lista: some View {
        List {
            ForEach(favoritos) { treino in
                NavigationLink {
                    // Já é favorito, então não há ação de favoritar: a barra
                    // inferior some sozinha quando `aoFavoritar` é nulo.
                    WorkoutDetailView(
                        treino: WorkoutPresentation(treino: treino, catalogo: catalogo))
                } label: {
                    LinhaDeFavorito(treino: treino)
                }
                // `.swipeActions` do sistema, não redesenhado (guardrail 11).
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        arquivar(treino)
                    } label: {
                        Label {
                            Text(Copy.favoritosApagar)
                        } icon: {
                            Image(systemName: Simbolos.apagar)
                        }
                    }
                    Button {
                        tituloDigitado = treino.titulo ?? ""
                        renomeando = treino
                    } label: {
                        Label {
                            Text(Copy.favoritosRenomear)
                        } icon: {
                            Image(systemName: Simbolos.renomear)
                        }
                    }
                }
            }
        }
        .listaDoApp()
    }

    // MARK: - Ações

    private var repositorio: WorkoutRepository { WorkoutRepository(context: context) }

    /// Soft delete (regra 11.15): o treino some da lista, as sessões ficam.
    private func arquivar(_ treino: Treino) {
        try? repositorio.arquivar(treino)
    }

    /// Renomeia, com a validação da regra 11.14 no repositório.
    private func confirmarRenomear() {
        guard let treino = renomeando else { return }
        do {
            try repositorio.renomear(treino, para: tituloDigitado)
            renomeando = nil
        } catch let falha as WorkoutError {
            renomeando = nil
            erro = falha.mensagemParaUsuario
        } catch {
            renomeando = nil
            erro = String(describing: error)
        }
    }
}

/// Uma linha da lista de favoritos (tela P3).
///
/// Título, distância e o contador de execuções — os três dados que o inventário
/// de telas da seção 10 define para P3.
private struct LinhaDeFavorito: View {

    let treino: Treino

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: treino.titulo ?? "")
                .font(.body)
                .foregroundStyle(Color.textoPrimario)

            HStack(spacing: 6) {
                Text(verbatim: "\(Formato.metros(treino.distanciaTotalM)) m")
                    .font(.metragemSerie)
                // O contador vem do campo denormalizado, não de `sessoes.count`:
                // contar relação por linha no SwiftData é lento o bastante para
                // ser percebido (spec 7.4 e regra 11.13).
                if treino.vezesExecutado > 0 {
                    Text(verbatim: "\u{00B7}")
                    Text(Copy.heroiFeitoVezes(treino.vezesExecutado))
                        .font(.footnote)
                }
            }
            .foregroundStyle(Color.textoSecundario)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
