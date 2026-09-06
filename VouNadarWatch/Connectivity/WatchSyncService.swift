import Foundation
import WatchConnectivity

/// Para onde vai o que o relógio recebe do iPhone (épico 8.6).
///
/// Injetado para o serviço não conhecer SwiftData e continuar substituível.
@MainActor
protocol SyncDestination: AnyObject {

    /// Aplica o estado leve, respeitando o desempate por `atualizado_em`
    /// (regra 11.12).
    func aplicar(_ estado: EstadoLeve)

    /// **Substitui** o conjunto de favoritos. Nunca faz merge.
    func substituirFavoritos(_ treinos: [WorkoutTransfer])
}

/// Recepção da sincronização no relógio (regra 11.12, épico 8.6).
///
/// ## O relógio nunca responde
///
/// **Nenhum dado sai daqui para o iPhone** (princípio 0.7). Esta classe só
/// recebe. Não há `sendMessage`, não há reply handler com conteúdo e não há
/// confirmação de recebimento — o `transferUserInfo` já garante entrega, e
/// confirmar exigiria um canal de volta que o v1 decidiu não ter.
///
/// ## Duas armadilhas de tempo, e como cada uma é tratada
///
/// **1. Ativar tarde perde entrega.** O `WCSession` processa a fila assim que
/// ativa, e o que chega antes de o delegate existir é consumido sem chamar
/// ninguém. Medido no simulador: o `handleIncomingUserInfo` do sistema aconteceu
/// **10 ms antes** de a ativação completar, e o conteúdo foi marcado como
/// entregue sem passar por aqui. Por isso `ativar()` é chamado no `init` do
/// `App`, e não numa `.task` de View — que só roda depois do primeiro render.
///
/// **2. O store ainda não existe quando a sessão ativa.** O `ModelContext` vem
/// do ambiente do SwiftUI e nasce depois. Em vez de adiar a ativação até ele
/// existir — que é justamente a armadilha 1 —, o serviço **guarda o que chegar**
/// e drena assim que o destino se conecta.
///
/// ## Com o iPhone longe, nada disso importa
///
/// O app do relógio funciona inteiro sem esta classe: gerar, executar, encerrar
/// e gravar dependem só do catálogo embarcado e do store local (princípio 0.5).
/// A sincronização é **conforto**, e é por isso que toda falha aqui é silenciosa
/// — sem alerta, sem tela de erro, e o que estava em disco continua valendo
/// (critério 8.6).
@MainActor
final class WatchSyncService: NSObject {

    /// A instância viva do serviço.
    ///
    /// **É singleton porque o `WCSession` guarda o delegate por referência
    /// FRACA.** Um serviço preso ao `@State` de uma View morre quando a View sai
    /// de cena, e a partir daí o relógio para de receber — sem erro, sem log e
    /// sem sintoma, até alguém favoritar no iPhone e nada chegar.
    static let compartilhado = WatchSyncService()

    /// Para onde o dado vai. Nulo até o store do relógio existir.
    private weak var destino: (any SyncDestination)?

    /// O que chegou antes de o destino existir (armadilha 2).
    private var estadoPendente: EstadoLeve?
    private var favoritosPendentes: [WorkoutTransfer]?

    /// A remontagem dos lotes vive numa fonte compartilhada e testada
    /// (`FavoritesBatchAssembler`); aqui ela é só usada.
    private var montador = FavoritesBatchAssembler()

    private override init() {
        super.init()
    }

    /// Põe o delegate e ativa a sessão. **Chamado o mais cedo possível.**
    ///
    /// Sem `WCSession` disponível o app segue normalmente com o que tem em
    /// disco — é exatamente o que o critério 8.6 exige.
    func ativar() {
        guard WCSession.isSupported() else { return }
        let sessao = WCSession.default
        sessao.delegate = self
        sessao.activate()
    }

    /// Liga o destino e entrega o que ficou guardado.
    ///
    /// Chamado quando o store do relógio existe. O `applicationContext` é lido
    /// aqui também: ele guarda **o último valor** e pode estar esperando desde
    /// antes desta execução.
    func conectar(destino: any SyncDestination) {
        self.destino = destino

        if WCSession.isSupported() {
            aplicarContexto(WCSession.default.receivedApplicationContext)
        }
        if let estadoPendente {
            destino.aplicar(estadoPendente)
            self.estadoPendente = nil
        }
        if let favoritosPendentes {
            destino.substituirFavoritos(favoritosPendentes)
            self.favoritosPendentes = nil
        }
    }

    /// Aplica um `applicationContext` recebido.
    ///
    /// Payload incompleto é descartado inteiro pelo `SyncPayload`: seguir com o
    /// que está em disco é melhor que aplicar metade de uma configuração.
    func aplicarContexto(_ dicionario: [String: Any]) {
        guard !dicionario.isEmpty, let estado = SyncPayload.estado(de: dicionario) else { return }
        entregarEstado(estado)
    }

    /// Entrega o estado, ou guarda se o destino ainda não existe.
    func entregarEstado(_ estado: EstadoLeve) {
        guard let destino else {
            estadoPendente = estado
            return
        }
        destino.aplicar(estado)
    }

    /// Junta um lote e, quando o conjunto fecha, substitui os favoritos
    /// (regra 11.12).
    func receberLote(_ dicionario: [String: Any]) {
        guard let decodificado = FavoritesSync.lerLote(dicionario) else { return }
        receberLote(decodificado)
    }

    /// Versão que recebe o lote já decodificado, usada pelo callback do
    /// `WCSessionDelegate` — ver o comentário sobre `Sendable` lá embaixo.
    func receberLote(_ decodificado: (lote: Int, total: Int, treinos: [WorkoutTransfer])) {
        guard let completo = montador.receber(decodificado) else { return }
        guard let destino else {
            favoritosPendentes = completo
            return
        }
        destino.substituirFavoritos(completo)
    }
}

// MARK: - WCSessionDelegate

extension WatchSyncService: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    /// Os callbacks chegam numa fila de segundo plano, **não na main actor** —
    /// por isso o salto explícito.
    ///
    /// **A decodificação acontece ANTES do salto**, e não é escolha estética:
    /// `[String: Any]` não é `Sendable`, então o Swift 6 não deixa o dicionário
    /// atravessar a fronteira de isolamento. Decodificar aqui transforma o
    /// payload num valor tipado que o compilador aceita mandar adiante — e, de
    /// quebra, tira o trabalho de parsing da main actor.
    nonisolated func session(
        _ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let estado = SyncPayload.estado(de: applicationContext) else { return }
        Task { @MainActor in
            WatchSyncService.compartilhado.entregarEstado(estado)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let decodificado = FavoritesSync.lerLote(userInfo) else { return }
        Task { @MainActor in
            WatchSyncService.compartilhado.receberLote(decodificado)
        }
    }
}
