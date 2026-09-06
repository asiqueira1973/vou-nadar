import Foundation
import StoreKit

/// A compra única do app (épico 8.11, regra 11.17).
///
/// Recebe: nada além do StoreKit.
/// Devolve: o produto, o direito verificado, e as ações de comprar e restaurar.
///
/// ## Zero backend, e isto é a única exceção declarada
///
/// O princípio 0.4 diz "nenhuma funcionalidade de treino depende de rede", com
/// **uma exceção única e declarada: comprar e restaurar falam com a App Store**.
/// Este arquivo é essa exceção inteira. Não há servidor, não há recibo enviado
/// para lugar nenhum, e a verificação é local, por
/// `Transaction.currentEntitlements` — que vale para a Apple Account do usuário
/// em todos os aparelhos dela (spec 6).
///
/// ## "Na dúvida, libera" não é frouxidão
///
/// A regra 11.17 é explícita, e a assimetria é intencional: quem pagou e é
/// barrado na borda da piscina, molhado, perde a confiança no app de uma vez.
/// Quem não pagou e executa um treino a mais custa o preço de um treino.
@MainActor
@Observable
final class PurchaseService {

    /// O produto, quando a App Store respondeu.
    private(set) var produto: Product?

    /// Como o direito foi apurado (regra 11.17).
    private(set) var origemDoDireito: OrigemDoDireito = .indeterminado

    /// Uma compra ou restauração em curso, para a tela mostrar progresso.
    private(set) var processando = false

    /// O direito a aplicar. **Na dúvida, libera.**
    var comprado: Bool { origemDoDireito.comprado }

    /// Escuta as transações que chegam de fora do app — compra feita noutro
    /// aparelho, reembolso, compartilhamento familiar.
    ///
    /// Sem isto, quem comprasse no iPhone da esposa e abrisse o próprio app
    /// continuaria vendo o paywall até reiniciar.
    private var escuta: Task<Void, Never>?

    init() {
        escuta = Task { [weak self] in
            for await resultado in Transaction.updates {
                guard case .verified(let transacao) = resultado else { continue }
                await transacao.finish()
                await self?.verificarDireito()
            }
        }
    }

    /// Encerra a escuta.
    ///
    /// Chamado explicitamente, e não num `deinit`: no Swift 6 um `deinit`
    /// não-isolado não pode tocar em propriedade isolada na main actor. O
    /// serviço vive enquanto o app vive, então isto raramente é chamado — mas
    /// existir evita uma tarefa órfã em teste.
    func parar() {
        escuta?.cancel()
        escuta = nil
    }

    /// Carrega o produto e verifica o direito.
    func carregar() async {
        await verificarDireito()
        produto = try? await Product.products(for: [PurchaseGate.identificadorDoProduto]).first
    }

    /// Verifica o direito por `Transaction.currentEntitlements` (regra 11.17).
    ///
    /// **Só marca `.verificado` quando o StoreKit de fato respondeu.** Se ele
    /// não responder, o estado permanece indeterminado — e indeterminado libera.
    func verificarDireito() async {
        var encontrou = false
        for await resultado in Transaction.currentEntitlements {
            guard case .verified(let transacao) = resultado,
                transacao.productID == PurchaseGate.identificadorDoProduto,
                transacao.revocationDate == nil
            else { continue }
            encontrou = true
        }
        origemDoDireito = .verificado(comprado: encontrou)
    }

    /// Compra o produto.
    ///
    /// Devolve: verdadeiro quando a compra foi concluída e verificada.
    ///
    /// Cancelar **não é erro** e não gera mensagem: desistir de comprar é uma
    /// resposta legítima, e tratá-la como falha seria repreender o usuário por
    /// uma decisão dele.
    @discardableResult
    func comprar() async -> Bool {
        guard let produto else { return false }
        processando = true
        defer { processando = false }

        do {
            switch try await produto.purchase() {
            case .success(let verificacao):
                guard case .verified(let transacao) = verificacao else { return false }
                await transacao.finish()
                await verificarDireito()
                return comprado
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    /// Restaura a compra (critério 8.11).
    ///
    /// **Existe no paywall e nos Ajustes**, como a App Store exige (spec 6).
    /// Trocar de aparelho, reinstalar ou entrar com outra Apple Account são
    /// situações normais — e sem este botão o usuário que pagou fica sem saída.
    @discardableResult
    func restaurar() async -> Bool {
        processando = true
        defer { processando = false }
        try? await AppStore.sync()
        await verificarDireito()
        return comprado
    }
}
