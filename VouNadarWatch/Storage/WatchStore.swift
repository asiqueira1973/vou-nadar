import Foundation
import StoreKit
import SwiftData

/// O armazenamento local do relógio (critério 8.7).
///
/// Recebe: o `ModelContext` do store do relógio.
/// Escreve: preferências e treinos.
///
/// **É um store próprio, independente do iPhone** (spec 4.1): sem CloudKit, sem
/// banco compartilhado. É o que faz gerar, executar, encerrar e gravar
/// funcionarem com o iPhone desligado (princípio 0.5). A sincronização só
/// empurra dado para cá; ela nunca é pré-requisito de nada.
///
/// Também é o `SyncDestination`: é aqui que o que chega do iPhone aterrissa.
@MainActor
final class WatchStore {

    let context: ModelContext
    private let versaoDoCatalogo: Int

    init(context: ModelContext, versaoDoCatalogo: Int) {
        self.context = context
        self.versaoDoCatalogo = versaoDoCatalogo
    }

    var preferencias: PreferencesRepository {
        PreferencesRepository(context: context, versaoCatalogoEmbarcada: versaoDoCatalogo)
    }

    var treinos: WorkoutRepository {
        WorkoutRepository(context: context)
    }

    /// O último estado de compra recebido do iPhone (contrato 13.3).
    ///
    /// É o segundo degrau da regra 11.17: quando o `Transaction` do relógio não
    /// responde, vale este. Guardado em memória porque ele chega a cada
    /// `applicationContext` e não precisa sobreviver a um reinício — se
    /// sobrevivesse, um estado velho poderia contradizer o StoreKit.
    private(set) var compradoSegundoOIphone: Bool?

    /// Apura o direito de executar (regra 11.17).
    ///
    /// A ordem dos três degraus é a da regra, e o terceiro é o que importa:
    /// 1. `Transaction.currentEntitlements` respondeu → vale ele;
    /// 2. não respondeu, mas o iPhone informou → vale o último estado conhecido;
    /// 3. nem um nem outro → **libera**.
    ///
    /// *"Negar acesso a quem pagou é pior que liberar a quem não pagou."*
    func apurarDireito() async -> OrigemDoDireito {
        var respondeu = false
        var encontrou = false
        for await resultado in Transaction.currentEntitlements {
            respondeu = true
            guard case .verified(let transacao) = resultado,
                transacao.productID == PurchaseGate.identificadorDoProduto,
                transacao.revocationDate == nil
            else { continue }
            encontrou = true
        }
        if respondeu { return .verificado(comprado: encontrou) }
        if let compradoSegundoOIphone {
            return .ultimoEstadoConhecido(comprado: compradoSegundoOIphone)
        }
        return .indeterminado
    }

    /// Quantas execuções guiadas já aconteceram neste relógio.
    ///
    /// São as sessões gravadas — e sessão descartada por curta **não chega ao
    /// banco** (decisão do épico 8.9), então um toque acidental de 10 metros não
    /// consome uma das três execuções livres.
    func execucoesFeitas() -> Int {
        (try? context.fetchCount(FetchDescriptor<SessaoNatacao>())) ?? 0
    }

    /// Os treinos disponíveis para executar, do mais recente para o mais antigo.
    ///
    /// Junta os **favoritos vindos do iPhone** e os **gerados aqui**
    /// (regra 11.18): os dois são executáveis no pulso, e para o nadador na
    /// borda a origem é irrelevante.
    func treinosExecutaveis() throws -> [Treino] {
        try context.fetch(
            FetchDescriptor<Treino>(
                predicate: #Predicate { $0.arquivadoEm == nil },
                sortBy: [SortDescriptor(\.atualizadoEm, order: .reverse)]))
    }
}

// MARK: - Recepção da sincronização (regra 11.12)

extension WatchStore: SyncDestination {

    /// Aplica o estado leve vindo do iPhone (regra 11.12).
    ///
    /// **Vence o `atualizado_em` mais recente.** Se o relógio mexeu na piscina
    /// depois do último envio do iPhone — o que a tela W5 permite, e a
    /// mitigação do risco R1 incentiva —, o que veio de fora é **descartado**.
    /// Sem esse desempate, trocar a piscina no relógio antes de entrar na água
    /// seria desfeito pelo primeiro contexto que chegasse, e o nadador nadaria
    /// a distância errada sem saber por quê.
    func aplicar(_ estado: EstadoLeve) {
        guard let prefs = try? preferencias.preferenciasAtuais() else { return }
        guard estado.prefsAtualizadoEm > prefs.atualizadoEm else { return }

        prefs.tamanhoRaiaM = estado.tamanhoRaiaM
        prefs.raiaConfirmada = estado.raiaConfirmada
        prefs.ritmoDescanso = estado.ritmoDescanso
        prefs.distanciaMinM = estado.distanciaMinM
        prefs.distanciaMaxM = estado.distanciaMaxM
        prefs.incluirEducativos = estado.incluirEducativos
        prefs.incluirPernada = estado.incluirPernada
        prefs.atualizadoEm = estado.prefsAtualizadoEm
        compradoSegundoOIphone = estado.comprado

        // O equipamento é conjunto: substitui inteiro, não faz merge.
        if let atuais = try? context.fetch(FetchDescriptor<EquipamentoSelecionado>()) {
            for linha in atuais { context.delete(linha) }
        }
        for id in estado.equipamentos.sorted() {
            context.insert(EquipamentoSelecionado(equipamentoId: id))
        }

        try? context.save()
    }

    /// **Substitui** o conjunto de favoritos vindos do iPhone (regra 11.12).
    ///
    /// Substituição, nunca merge: é idempotente, e merge exigiria política de
    /// conflito que o v1 decidiu não ter.
    ///
    /// **Os treinos gerados no relógio NÃO são tocados** (regra 11.18): eles
    /// existem só aqui, o iPhone não sabe deles, e apagá-los numa sincronização
    /// seria destruir dado que ninguém tem cópia.
    func substituirFavoritos(_ recebidos: [WorkoutTransfer]) {
        // O filtro por origem é feito em memória, e não no `#Predicate`: o
        // SwiftData não aceita comparar caso de enum dentro do predicado
        // (`key path cannot refer to enum case`). O custo é irrelevante — o
        // relógio guarda dezenas de treinos, não milhares.
        let todos = (try? context.fetch(FetchDescriptor<Treino>())) ?? []
        for treino in todos where treino.origem == .gerado_iphone {
            context.delete(treino)
        }

        for recebido in recebidos {
            context.insert(Treino(recebido: recebido))
        }
        try? context.save()
    }
}

extension Treino {

    /// Reconstrói um treino a partir do que chegou do iPhone (contrato 13.3).
    ///
    /// **Nada é recalculado.** Descanso, distância adaptada e voltas vêm
    /// prontos e são copiados como estão — é o princípio 0.6 atravessando a
    /// fronteira entre dois aparelhos: o treino que o nadador favoritou no
    /// iPhone é exatamente o que o relógio vai executar.
    convenience init(recebido: WorkoutTransfer) {
        self.init(
            id: recebido.id,
            titulo: recebido.titulo,
            origem: .gerado_iphone,
            distanciaTotalM: recebido.distanciaTotalM,
            // A faixa pedida não viaja: ela só serve ao histórico do iPhone, e
            // gastar bytes do limite de 65.536 com ela seria desperdício.
            distanciaMinSolicitadaM: recebido.distanciaTotalM,
            distanciaMaxSolicitadaM: recebido.distanciaTotalM,
            tamanhoRaiaM: recebido.tamanhoRaiaM,
            ritmoDescansoUsado: recebido.ritmoDescansoUsado,
            comEducativos: recebido.secoes.contains {
                $0.series.contains { $0.modo == .educativo }
            },
            comPernada: recebido.secoes.contains { $0.series.contains { $0.modo == .pernada } },
            favorito: true,
            atualizadoEm: recebido.atualizadoEm)

        secoes = recebido.secoes.map { secaoRecebida in
            let secao = SecaoTreino(
                tipoSecao: secaoRecebida.tipoSecao,
                // O alvo da seção também não viaja: é dado de depuração da
                // geração, e o relógio não o usa para nada.
                distanciaAlvoM: 0,
                descansoPosSecaoSeg: secaoRecebida.descansoPosSecaoSeg)
            secao.series = secaoRecebida.series.map { serie in
                SerieTreino(
                    exercicioId: serie.exercicioId,
                    repeticoes: serie.repeticoes,
                    distanciaM: serie.distanciaM,
                    // A distância do catálogo não viaja; sem ela, a igualdade
                    // com a adaptada significa "não sei", e o relógio não mostra
                    // nota de ajuste nenhuma — quem mostra é o iPhone.
                    distanciaCatalogoM: serie.distanciaM,
                    metrosTotais: serie.metrosTotais,
                    descansoSeg: serie.descansoSeg,
                    descansoPosSerieSeg: serie.descansoPosSerieSeg,
                    voltasPorRepeticao: serie.voltasPorRepeticao,
                    nomeSnapshot: serie.nomeSnapshot,
                    descricaoSnapshot: "",
                    equipamentoExigido: "nenhum",
                    modo: serie.modo,
                    intensidade: .aerobico,
                    ordem: serie.ordem)
            }
            return secao
        }
    }
}
