import StoreKit
import SwiftUI

/// P7 — Paywall (épico 8.11).
///
/// Lê: o StoreKit. Escreve: nada no banco — o direito de compra vive na Apple
/// Account, não aqui (spec 6).
///
/// Apresentada em `.sheet` com detent grande (DESIGN-SYSTEM.md seção 3).
///
/// **O preço nunca é escrito à mão.** Ele vem de `product.displayPrice`, já
/// formatado na moeda e no idioma da conta do usuário. Escrever "R$ 49,90" no
/// código daria o número errado para qualquer pessoa fora do Brasil e mentiria
/// no dia de uma promoção.
struct PaywallView: View {

    @State var compras: PurchaseService

    @Environment(\.dismiss) private var dispensar

    /// Mensagem depois de restaurar, positiva ou negativa.
    @State private var aviso: LocalizedStringResource?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(Copy.paywallTitulo)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.textoPrimario)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(Copy.paywallCorpo)
                        .font(.body)
                        .foregroundStyle(Color.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)

                    if let aviso {
                        Text(aviso)
                            .font(.footnote)
                            .foregroundStyle(Color.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Medidas.heroiPaddingHorizontal)
                .padding(.top, 8)
            }
            .background(Color.fundoPrimario)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dispensar() } label: {
                        Image(systemName: Simbolos.fechar)
                    }
                    .accessibilityLabel(Text(Copy.a11yFechar))
                }
            }
            .safeAreaInset(edge: .bottom) { rodape }
            .task { await compras.carregar() }
        }
    }

    /// O botão de compra e o "Restaurar compra" abaixo dele.
    ///
    /// Restaurar é `.plain`, não um segundo botão prominente: é a saída de quem
    /// **já pagou**, e competir com a compra visualmente confundiria os dois.
    @ViewBuilder
    private var rodape: some View {
        VStack(spacing: 10) {
            if compras.processando {
                ProgressView()
            } else if let produto = compras.produto {
                BarraDeAcaoPrimaria(acao: { Task { await comprar() } }) {
                    Text(Copy.paywallComprarPor(produto.displayPrice))
                }
            }

            Button {
                Task { await restaurar() }
            } label: {
                Text(Copy.paywallRestaurar)
                    .font(.footnote)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .disabled(compras.processando)
            .padding(.bottom, Medidas.barraInferiorBase)
        }
        .background(.bar)
    }

    private func comprar() async {
        if await compras.comprar() { dispensar() }
    }

    private func restaurar() async {
        // Restaurar sem compra não é erro do usuário: pode ser a Apple Account
        // errada. A mensagem diz o que aconteceu, sem culpar ninguém.
        aviso = await compras.restaurar() ? Copy.paywallComprado : Copy.paywallFalhaAoRestaurar
        if compras.comprado { dispensar() }
    }
}
