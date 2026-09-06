import Foundation
import StoreKit
import StoreKitTest
import Testing

@testable import VouNadar

/// O portão da compra (épico 8.11, regra 11.17).
///
/// A parte mais delicada é o **"na dúvida, libera"**. É uma regra que qualquer
/// refatoração descuidada inverte — trocar um `??` de lado basta —, e o sintoma
/// só aparece quando alguém que pagou é barrado na borda da piscina, molhado,
/// sem conseguir começar o treino. Estes testes existem para isso não acontecer
/// em silêncio.
struct PurchaseGateTests {

    // MARK: - As três execuções livres (assunção 24.5)

    @Test("As três primeiras execuções são livres; a quarta é barrada")
    func tresLivres() {
        for feitas in 0..<3 {
            #expect(PurchaseGate.podeExecutar(comprado: false, execucoesFeitas: feitas))
        }
        #expect(!PurchaseGate.podeExecutar(comprado: false, execucoesFeitas: 3))
        #expect(!PurchaseGate.podeExecutar(comprado: false, execucoesFeitas: 10))
    }

    @Test("Comprado libera sempre, independentemente da contagem")
    func compradoLiberaSempre() {
        #expect(PurchaseGate.podeExecutar(comprado: true, execucoesFeitas: 0))
        #expect(PurchaseGate.podeExecutar(comprado: true, execucoesFeitas: 500))
    }

    @Test("A contagem de execuções restantes acompanha o uso")
    func restantes() {
        #expect(PurchaseGate.execucoesLivresRestantes(comprado: false, execucoesFeitas: 0) == 3)
        #expect(PurchaseGate.execucoesLivresRestantes(comprado: false, execucoesFeitas: 2) == 1)
        #expect(PurchaseGate.execucoesLivresRestantes(comprado: false, execucoesFeitas: 3) == 0)
        // Não fica negativo.
        #expect(PurchaseGate.execucoesLivresRestantes(comprado: false, execucoesFeitas: 9) == 0)
        // Quem comprou não tem "restantes" a mostrar.
        #expect(PurchaseGate.execucoesLivresRestantes(comprado: true, execucoesFeitas: 0) == 0)
    }

    // MARK: - "Na dúvida, libera" (regra 11.17)

    @Test("Direito indeterminado LIBERA — é a regra 11.17 literal")
    func indeterminadoLibera() {
        // "Negar acesso a quem pagou é pior que liberar a quem não pagou."
        #expect(OrigemDoDireito.indeterminado.comprado)
    }

    @Test("O StoreKit tem a palavra final quando responde")
    func verificadoVence() {
        #expect(OrigemDoDireito.verificado(comprado: true).comprado)
        #expect(!OrigemDoDireito.verificado(comprado: false).comprado)
    }

    @Test("Sem StoreKit, vale o último estado vindo do iPhone (contrato 13.3)")
    func ultimoEstadoConhecido() {
        #expect(OrigemDoDireito.ultimoEstadoConhecido(comprado: true).comprado)
        #expect(!OrigemDoDireito.ultimoEstadoConhecido(comprado: false).comprado)
    }

    @Test("Quem comprou nunca é barrado, mesmo com o StoreKit mudo")
    func quemComprouNuncaEhBarrado() {
        // O cenário que a regra 11.17 protege: relógio na borda da piscina, sem
        // iPhone por perto, StoreKit sem resposta, quinta execução.
        let direito = OrigemDoDireito.indeterminado
        #expect(
            PurchaseGate.podeExecutar(comprado: direito.comprado, execucoesFeitas: 5),
            "o nadador que pagou não pode ser barrado por falta de resposta do StoreKit")
    }

    // MARK: - O produto

    @Test("O identificador do produto é o registrado no App Store Connect")
    func identificadorDoProduto() {
        #expect(PurchaseGate.identificadorDoProduto == "com.dablab.vounadar.completo")
    }

    @Test("O arquivo .storekit local declara o mesmo produto, não-consumível, a 49,90")
    func arquivoStoreKitBate() throws {
        // O `.storekit` é o que permite exercitar compra, restauração e falha
        // sem o sandbox da App Store (critério 8.11). Se ele divergir do código,
        // os testes de compra passam contra um produto que não existe.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "VouNadar/Resources/VouNadar.storekit")
        let dados = try Data(contentsOf: url)
        let json = try #require(
            try JSONSerialization.jsonObject(with: dados) as? [String: Any])
        let produtos = try #require(json["products"] as? [[String: Any]])
        let produto = try #require(produtos.first)

        #expect(produtos.count == 1, "um produto só: a compra é única")
        #expect(produto["productID"] as? String == PurchaseGate.identificadorDoProduto)
        #expect(produto["type"] as? String == "NonConsumable")
        #expect(produto["displayPrice"] as? String == "49.90")
        #expect(produto["familyShareable"] as? Bool == false)
    }
}

/// A compra contra o `.storekit` local (critério 8.11).
///
/// Exercita os três caminhos que o critério nomeia — **compra, restauração e
/// falha** — sem sandbox e sem rede.
///
/// ## Por que um teste só, e não quatro
///
/// O `SKTestSession` **não é um objeto de teste, é estado do processo**: ele
/// manipula transações, direitos e diálogos do StoreKit inteiro. Criar uma
/// sessão por teste faz o `resetToDefaultState()` de um apagar a compra que o
/// outro acabou de fazer — e a falha aparece no teste errado, o que é pior que
/// não testar.
///
/// Um único teste percorrendo o ciclo de vida cobre os mesmos três caminhos, com
/// uma sessão só e sem corrida.
@MainActor
struct PurchaseServiceTests {

    /// Espera o direito chegar ao valor esperado, com limite.
    ///
    /// **`Transaction.currentEntitlements` não reflete a compra na mesma linha
    /// em que ela acontece**: o StoreKit propaga por `Transaction.updates`, e
    /// entre o `buyProduct` e o direito ficar visível passa um instante.
    /// Afirmar imediatamente testaria a velocidade do StoreKit, não o código.
    ///
    /// O limite existe para o teste falhar em vez de travar quando o
    /// comportamento mudar de verdade.
    private func esperarDireito(
        _ servico: PurchaseService, seja esperado: Bool, tentativas: Int = 60
    ) async {
        for _ in 0..<tentativas {
            await servico.verificarDireito()
            if servico.comprado == esperado { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    @Test("Ciclo de vida da compra: carrega, compra, restaura e perde no reembolso")
    func cicloDeVida() async throws {
        let sessao = try SKTestSession(configurationFileNamed: "VouNadar")
        sessao.resetToDefaultState()
        sessao.clearTransactions()
        sessao.disableDialogs = true
        defer { sessao.clearTransactions() }

        let servico = PurchaseService()
        defer { servico.parar() }

        // 1. O produto carrega do arquivo local, com o tipo declarado.
        await servico.carregar()
        let produto = try #require(servico.produto, "o produto do .storekit não carregou")
        #expect(produto.id == PurchaseGate.identificadorDoProduto)
        #expect(produto.type == .nonConsumable)

        // 2. Sem compra, o direito é VERIFICADO como não comprado — e não
        //    indeterminado. A diferença importa: indeterminado liberaria.
        #expect(servico.origemDoDireito == .verificado(comprado: false))
        #expect(!servico.comprado)
        #expect(!PurchaseGate.podeExecutar(comprado: servico.comprado, execucoesFeitas: 3))

        // 3. Compra.
        let transacao = try await sessao.buyProduct(
            identifier: PurchaseGate.identificadorDoProduto)
        await esperarDireito(servico, seja: true)
        #expect(servico.comprado, "a compra não chegou ao direito")
        #expect(servico.origemDoDireito == .verificado(comprado: true))
        // E agora o portão libera, independentemente da contagem.
        #expect(PurchaseGate.podeExecutar(comprado: servico.comprado, execucoesFeitas: 99))

        // 4. Restauração: um serviço novo, como numa reinstalação.
        let novaInstalacao = PurchaseService()
        defer { novaInstalacao.parar() }
        #expect(await novaInstalacao.restaurar(), "restaurar não recuperou a compra")
        #expect(novaInstalacao.comprado)

        // 5. Falha: reembolso tira o direito. É caso real, não hipótese.
        try sessao.refundTransaction(identifier: UInt(transacao.id))
        await esperarDireito(servico, seja: false)
        #expect(!servico.comprado, "compra reembolsada não pode continuar valendo")
    }
}
