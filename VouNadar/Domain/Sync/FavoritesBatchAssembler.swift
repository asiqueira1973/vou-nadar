import Foundation

/// Remonta os lotes de favoritos recebidos (regra 11.12).
///
/// **É tipo puro**, sem WatchConnectivity: mora aqui, e não dentro do serviço do
/// relógio, porque é a parte que pode dar errado em silêncio e precisa de teste.
/// O serviço vira uma casca fina em volta disto.
///
/// ## As duas armadilhas que ele resolve
///
/// 1. **A fila do `transferUserInfo` não garante ordem.** O lote 3 pode chegar
///    antes do 1. Por isso a conclusão é "tenho todos os números de 1 a N", e
///    não "chegou o de maior número".
/// 2. **Uma transferência nova pode começar no meio da anterior.** Se o usuário
///    favorita de novo enquanto a leva anterior ainda está chegando, misturar as
///    duas produziria uma lista que nunca existiu. Um `total_lotes` diferente
///    descarta o que estava pela metade.
///
/// O conjunto só é entregue **completo**: aplicar um lote parcial deixaria o
/// relógio com um terço da lista e sem saber disso.
struct FavoritesBatchAssembler {

    /// Lotes recebidos e ainda não entregues, por número.
    private var pendentes: [Int: [WorkoutTransfer]] = [:]

    /// Quantos lotes a transferência corrente tem.
    private var totalEsperado: Int?

    init() {}

    /// Quantos lotes já chegaram da transferência corrente. Para depuração.
    var lotesRecebidos: Int { pendentes.count }

    /// Absorve um lote.
    ///
    /// Recebe: o dicionário cru de `didReceiveUserInfo`.
    /// Devolve: a lista **completa** de favoritos quando o último lote fecha o
    /// conjunto, ou `nil` enquanto faltar lote — e também `nil` para payload que
    /// não é de favoritos, que é simplesmente ignorado.
    ///
    /// Quem chama **substitui** o conjunto inteiro com o resultado. Nunca faz
    /// merge: substituição é idempotente, e receber o mesmo lote duas vezes dá o
    /// mesmo resultado.
    mutating func receber(_ dicionario: [String: Any]) -> [WorkoutTransfer]? {
        guard let decodificado = FavoritesSync.lerLote(dicionario) else { return nil }
        return receber(decodificado)
    }

    /// Absorve um lote **já decodificado**.
    ///
    /// Existe porque `[String: Any]` não é `Sendable`: o serviço do relógio
    /// decodifica na fila em que o `WCSessionDelegate` entrega e só então salta
    /// para a main actor, carregando um valor que o compilador aceita atravessar
    /// a fronteira. Decodificar depois do salto exigiria mandar o dicionário
    /// junto, que é justamente o que o Swift 6 proíbe.
    mutating func receber(
        _ decodificado: (lote: Int, total: Int, treinos: [WorkoutTransfer])
    ) -> [WorkoutTransfer]? {
        let (lote, total, treinos) = decodificado
        guard total >= 1, lote >= 1, lote <= total else { return nil }

        // Transferência nova invalida a anterior pela metade.
        if totalEsperado != total {
            pendentes = [:]
            totalEsperado = total
        }
        pendentes[lote] = treinos

        guard pendentes.count == total else { return nil }

        let completo = (1...total).compactMap { pendentes[$0] }.flatMap(\.self)
        pendentes = [:]
        totalEsperado = nil
        return completo
    }
}
