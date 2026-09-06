import Foundation

/// O direito de executar treino guiado (épico 8.11, regra 11.17).
///
/// **É função pura**, sem StoreKit: recebe o que se sabe e devolve se pode. É o
/// que permite testar a regra 11.17 — inclusive o caso mais delicado dela, o
/// "na dúvida, libera" — sem sandbox de compra e sem rede.
///
/// ## Onde o paywall fica, e por quê
///
/// **Gerar treino é sempre livre** (critério 8.11). O que a compra destrava é a
/// **execução guiada** — e isso não é detalhe de precificação, é onde o valor
/// está: o produto inteiro existe para o momento em que o nadador levanta o
/// pulso na borda e vê quanto falta de descanso (persona da seção 2). Cobrar
/// pela geração seria cobrar pelo folheto em vez do treino.
///
/// ## O que conta como execução
///
/// Uma `sessao_natacao` gravada. Sessão descartada por ser curta demais **não
/// conta** (regra 11.11) — e não conta porque nem chega ao banco: um toque
/// acidental de 10 metros não pode consumir uma das três execuções livres.
enum PurchaseGate {

    /// Quantas execuções guiadas são livres antes do paywall (assunção 24.5).
    ///
    /// A quarta leva ao paywall. Três é o número que dá para o nadador
    /// experimentar o produto de verdade — uma sessão para entender, uma para
    /// confiar, uma para querer — sem virar amostra grátis eterna.
    static let execucoesLivres = 3

    /// O identificador do produto no App Store Connect.
    static let identificadorDoProduto = "com.dablab.vounadar.completo"

    /// Pode executar um treino guiado?
    ///
    /// Recebe: se a compra está verificada, e quantas execuções já foram feitas.
    /// Devolve: se a execução pode começar.
    ///
    /// **Comprado libera sempre**, independentemente da contagem.
    static func podeExecutar(comprado: Bool, execucoesFeitas: Int) -> Bool {
        comprado || execucoesFeitas < execucoesLivres
    }

    /// Quantas execuções livres restam. Zero quando acabaram.
    ///
    /// Serve à interface para avisar antes de acabar, em vez de o nadador
    /// descobrir na borda da piscina que não pode começar.
    static func execucoesLivresRestantes(comprado: Bool, execucoesFeitas: Int) -> Int {
        guard !comprado else { return 0 }
        return max(0, execucoesLivres - execucoesFeitas)
    }
}

/// Como o direito de compra foi apurado (regra 11.17).
///
/// O caso interessante é o terceiro. A regra 11.17 diz, com todas as letras:
/// *"Falhando por indisponibilidade, vale o último estado recebido via
/// `applicationContext`. **Na dúvida, libera** — negar acesso a quem pagou é
/// pior que liberar a quem não pagou."*
///
/// Essa assimetria é decisão de produto, não descuido: quem pagou e é barrado na
/// borda da piscina, molhado, sem conseguir começar o treino, perde a confiança
/// no app de uma vez. Quem não pagou e executa um treino a mais custa o preço de
/// um treino.
enum OrigemDoDireito: Sendable, Equatable {

    /// `Transaction.currentEntitlements` respondeu.
    case verificado(comprado: Bool)

    /// O StoreKit não respondeu, mas o iPhone já tinha informado o estado pelo
    /// `applicationContext` (contrato 13.3). Só o relógio chega aqui.
    case ultimoEstadoConhecido(comprado: Bool)

    /// Nem uma coisa nem outra. **Libera** (regra 11.17).
    case indeterminado

    /// O direito a aplicar.
    var comprado: Bool {
        switch self {
        case .verificado(let comprado): comprado
        case .ultimoEstadoConhecido(let comprado): comprado
        // "Na dúvida, libera."
        case .indeterminado: true
        }
    }
}
