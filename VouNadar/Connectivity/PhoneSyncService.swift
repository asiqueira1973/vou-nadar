import Foundation
import SwiftData
import WatchConnectivity

/// Sincronização iPhone → Watch (regra 11.12, épico 8.6).
///
/// Recebe: o estado leve e os favoritos.
/// Devolve: nada — é fogo e esquece, por construção.
///
/// ## O sentido é único, e isso é decisão de arquitetura
///
/// **Nenhum dado trafega do relógio para o iPhone** (princípio 0.7 e regra
/// 11.18). Esta classe só implementa os callbacks de `WCSessionDelegate` que o
/// protocolo obriga, e nenhum deles lê conteúdo vindo do outro lado.
///
/// O que justifica isso: o dado mais importante — o que foi realmente nadado —
/// **já atravessa sozinho pelo HealthKit**, que sincroniza entre Watch e iPhone
/// sem uma linha de código nossa (decisão 4.3). Sobraria sincronizar treino
/// gerado no relógio, e a regra 11.18 decidiu que isso fica no relógio no v1.
///
/// ## Os dois canais, e por que são dois
///
/// - `updateApplicationContext` para o estado leve: guarda **só o último
///   valor** e sobrescreve o anterior. É o que se quer para configuração —
///   não interessa o histórico da piscina, interessa a piscina de agora.
/// - `transferUserInfo` para os favoritos: é **fila**, entrega mesmo com o
///   relógio fora de alcance, e o sistema retoma quando os dois se reaproximam.
///   É o que atende ao critério "favoritar longe do relógio e reaproximar
///   entrega sem ação do usuário".
@MainActor
final class PhoneSyncService: NSObject {

    static let shared = PhoneSyncService()

    /// Última carga enviada, para não reescrever contexto idêntico.
    ///
    /// `updateApplicationContext` acorda o app do relógio; repetir o mesmo
    /// dicionário gastaria bateria do relógio sem mudar nada.
    private var ultimoContextoEnviado: [String: Any]?

    /// Chamado quando a sessão termina de ativar.
    ///
    /// **Existe para corrigir uma corrida real**: `activate()` é assíncrono, e
    /// quem chamar `enviarEstado` logo depois encontra `activationState ==
    /// .notActivated` e não envia nada. Sem este gancho, a primeira
    /// sincronização de cada execução só acontecia por acaso — quando alguma
    /// gravação posterior disparava o coordenador de novo. Numa abertura em que
    /// nada é gravado, o relógio nunca recebia.
    var aoAtivar: (() -> Void)?

    private override init() {
        super.init()
    }

    /// Ativa a sessão, se o aparelho suportar.
    ///
    /// **Não falhar aqui é requisito**: um iPhone sem relógio pareado é caso
    /// normal e frequente (fluxo 9.5). O app funciona inteiro sem isso.
    func iniciar() {
        guard WCSession.isSupported() else { return }
        let sessao = WCSession.default
        sessao.delegate = self
        sessao.activate()
    }

    /// Empurra o estado leve (contrato 13.3).
    ///
    /// Silencioso quando não há relógio pareado ou a sessão não está ativa — o
    /// `transferUserInfo` dos favoritos até enfileira nesse caso, mas o
    /// contexto não, e forçar não traria ganho: o contexto seguinte carrega o
    /// estado atual de qualquer jeito.
    func enviarEstado(_ estado: EstadoLeve) {
        guard let sessao = sessaoPronta else { return }

        let contexto = SyncPayload.dicionario(de: estado)
        guard !contextoEhIgualAoUltimo(contexto) else { return }

        do {
            try sessao.updateApplicationContext(contexto)
            ultimoContextoEnviado = contexto
        } catch {
            // Falha de contexto não é erro de usuário e não gera alerta: o
            // relógio segue com o que tem em disco (critério 8.6), e o próximo
            // envio corrige.
            ultimoContextoEnviado = nil
        }
    }

    /// Enfileira os favoritos, em um ou mais lotes (regra 11.12).
    ///
    /// **Sempre envia, mesmo com a lista vazia**: é assim que "desfavoritei o
    /// último treino" chega ao relógio. O receptor substitui o conjunto ao
    /// receber o último lote, e substituição é idempotente.
    func enviarFavoritos(_ treinos: [WorkoutTransfer]) {
        guard let sessao = sessaoPronta else { return }

        for lote in FavoritesSync.lotes(de: treinos) {
            // `transferUserInfo` é fila: entrega quando o relógio voltar ao
            // alcance, sem ação do usuário.
            sessao.transferUserInfo(lote)
        }
    }

    /// A sessão, quando há de fato um relógio do outro lado.
    ///
    /// **`activationState` não basta**, e `isPaired` também não. São três
    /// condições, e cada uma falha de um jeito diferente:
    ///
    /// - sessão não ativada: a chamada nem sai;
    /// - **sem relógio pareado**: a chamada sai e falha depois, com
    ///   `WCErrorCodeDeviceNotPaired`;
    /// - **relógio pareado mas sem o app instalado**: falha com
    ///   `WCErrorCodeWatchAppNotInstalled` — o caso de quem tem Apple Watch mas
    ///   ainda não instalou o Vou Nadar nele.
    ///
    /// Sem as três guardas o app tenta enviar a cada gravação do banco, para
    /// ninguém, e enche o log de erro sobre uma situação que é **normal**
    /// (fluxo 9.5): o app inteiro funciona sem relógio, e nada aqui pode virar
    /// erro visível.
    private var sessaoPronta: WCSession? {
        guard WCSession.isSupported() else { return nil }
        let sessao = WCSession.default
        guard sessao.activationState == .activated,
            sessao.isPaired,
            sessao.isWatchAppInstalled
        else { return nil }
        return sessao
    }

    /// Dois contextos são o mesmo?
    ///
    /// Compara pela serialização, porque `[String: Any]` não é `Equatable` e
    /// comparar chave a chave repetiria o conhecimento do contrato 13.3 num
    /// terceiro lugar.
    private func contextoEhIgualAoUltimo(_ contexto: [String: Any]) -> Bool {
        guard let ultimo = ultimoContextoEnviado else { return false }
        return SyncPayload.tamanhoEmBytes(ultimo) == SyncPayload.tamanhoEmBytes(contexto)
            && NSDictionary(dictionary: ultimo).isEqual(to: contexto)
    }
}

// MARK: - WCSessionDelegate

extension PhoneSyncService: WCSessionDelegate {

    /// A sessão terminou de ativar: só agora dá para enviar.
    ///
    /// **Nada é lido do relógio aqui** — o parâmetro `session` serve apenas para
    /// saber que a ativação acabou. O sentido continua único (princípio 0.7).
    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            PhoneSyncService.shared.aoAtivar?()
        }
    }

    /// O usuário trocou de relógio. A sessão precisa ser reativada, e o próximo
    /// envio recarrega o novo aparelho do zero.
    ///
    /// Vazio de propósito: não há nada a ler do outro lado (princípio 0.7).
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Reativar é o que permite parear um relógio novo sem reiniciar o app.
        WCSession.default.activate()
    }
}

/// Junta o que o app tem em disco e empurra para o relógio (épico 8.6).
///
/// Existe para as telas não precisarem saber que sincronização existe: elas
/// gravam pelos repositórios, e este coordenador escuta o `ModelContext` salvar
/// e reenvia o estado.
///
/// **É um ponto de escuta só, e de propósito.** A alternativa — chamar a
/// sincronização em cada uma das seis ações que gravam — é a que esquece a
/// sétima quando ela for escrita.
@MainActor
final class SyncCoordinator {

    private let context: ModelContext
    private let versaoDoCatalogo: Int

    /// A inscrição no `ModelContext.didSave`.
    ///
    /// É `Task` e não `NSObjectProtocol` de propósito: no Swift 6 um `deinit`
    /// não-isolado não pode tocar em propriedade de tipo não-`Sendable`, e o
    /// token do `NotificationCenter` é um deles. A sequência assíncrona de
    /// notificações resolve isso — cancelar a tarefa encerra a inscrição, e
    /// `Task` é `Sendable`.
    private var inscricao: Task<Void, Never>?

    init(context: ModelContext, versaoDoCatalogo: Int) {
        self.context = context
        self.versaoDoCatalogo = versaoDoCatalogo
    }

    /// Começa a ouvir as gravações e faz um envio inicial.
    func iniciar() {
        // O envio inicial acontece quando a sessão ATIVA, não agora: `activate()`
        // é assíncrono, e enviar antes disso é enviar para o vazio.
        PhoneSyncService.shared.aoAtivar = { [weak self] in self?.sincronizar() }
        PhoneSyncService.shared.iniciar()

        inscricao?.cancel()
        inscricao = Task { [weak self] in
            // Toda gravação do store passa por aqui — é o ponto de escuta único
            // que evita ter de lembrar de sincronizar em cada ação que grava.
            for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave) {
                guard !Task.isCancelled else { return }
                self?.sincronizar()
            }
        }
    }

    /// Encerra a inscrição.
    ///
    /// Chamado explicitamente em vez de num `deinit`: o coordenador vive
    /// enquanto o app vive, e um `deinit` isolado traria mais cerimônia de
    /// concorrência do que valor.
    func parar() {
        inscricao?.cancel()
        inscricao = nil
    }

    /// Lê o estado atual e empurra os dois canais (contrato 13.3).
    ///
    /// O direito de compra viaja junto (contrato 13.3): é o **último estado
    /// conhecido** que a regra 11.17 manda usar quando o `Transaction` do
    /// relógio não responde.
    func sincronizar(comprado: Bool = true) {
        let prefsRepo = PreferencesRepository(
            context: context, versaoCatalogoEmbarcada: versaoDoCatalogo)
        guard let prefs = try? prefsRepo.preferenciasAtuais() else { return }
        let equipamentos = (try? prefsRepo.equipamentosSelecionados()) ?? []

        PhoneSyncService.shared.enviarEstado(
            EstadoLeve(
                tamanhoRaiaM: prefs.tamanhoRaiaM,
                raiaConfirmada: prefs.raiaConfirmada,
                ritmoDescanso: prefs.ritmoDescanso,
                distanciaMinM: prefs.distanciaMinM,
                distanciaMaxM: prefs.distanciaMaxM,
                incluirEducativos: prefs.incluirEducativos,
                incluirPernada: prefs.incluirPernada,
                equipamentos: equipamentos,
                prefsAtualizadoEm: prefs.atualizadoEm,
                comprado: comprado))

        let favoritos = (try? WorkoutRepository(context: context).favoritos()) ?? []
        PhoneSyncService.shared.enviarFavoritos(favoritos.map(WorkoutTransfer.init(treino:)))
    }
}

extension WorkoutTransfer {

    /// Converte um treino do banco para o formato de transferência.
    ///
    /// Copia os snapshots como estão: descanso, distância adaptada e voltas
    /// foram congelados na geração e não são recalculados aqui (princípio 0.6).
    init(treino: Treino) {
        self.init(
            id: treino.id,
            titulo: treino.titulo ?? "",
            distanciaTotalM: treino.distanciaTotalM,
            tamanhoRaiaM: treino.tamanhoRaiaM,
            ritmoDescansoUsado: treino.ritmoDescansoUsado,
            atualizadoEm: treino.atualizadoEm,
            secoes: treino.secoesOrdenadas.map { secao in
                SecaoTransferivel(
                    tipoSecao: secao.tipoSecao,
                    ordem: secao.ordem,
                    descansoPosSecaoSeg: secao.descansoPosSecaoSeg,
                    series: secao.seriesOrdenadas.map { serie in
                        SerieTransferivel(
                            exercicioId: serie.exercicioId,
                            repeticoes: serie.repeticoes,
                            distanciaM: serie.distanciaM,
                            metrosTotais: serie.metrosTotais,
                            descansoSeg: serie.descansoSeg,
                            descansoPosSerieSeg: serie.descansoPosSerieSeg,
                            voltasPorRepeticao: serie.voltasPorRepeticao,
                            nomeSnapshot: serie.nomeSnapshot,
                            modo: serie.modo,
                            ordem: serie.ordem)
                    })
            })
    }
}
