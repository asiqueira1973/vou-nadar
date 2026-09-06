import Foundation

/// O estado leve que o iPhone empurra para o relógio (contrato 13.3).
///
/// Vai por `updateApplicationContext`, que tem limite de **262.144 bytes** e
/// guarda só o último valor — é exatamente o que se quer para configuração:
/// não interessa o histórico, interessa o estado atual.
///
/// **É tipo puro**: sem WatchConnectivity, sem SwiftData, sem plataforma. Quem
/// fala com o `WCSession` é o serviço de cada target; aqui só existe a forma do
/// dado, para os dois lados nunca discordarem sobre ela.
struct EstadoLeve: Sendable, Equatable {

    /// Comprimento da raia (regra 11.3). Sem ele o relógio não sabe adaptar
    /// distância nem contar volta.
    var tamanhoRaiaM: Int

    /// Enquanto falso, o relógio também não gera treino (regra 11.4).
    var raiaConfirmada: Bool

    var ritmoDescanso: RitmoDescanso
    var distanciaMinM: Int
    var distanciaMaxM: Int
    var incluirEducativos: Bool
    var incluirPernada: Bool

    /// `equipamento_id` marcados no iPhone.
    var equipamentos: Set<String>

    /// Quando as preferências do iPhone foram atualizadas.
    ///
    /// É o desempate da regra 11.12: em conflito, vence o `atualizado_em` mais
    /// recente. O relógio compara com o que tem em disco antes de sobrescrever.
    var prefsAtualizadoEm: Date

    /// Direito de compra (regra 11.17).
    ///
    /// O relógio verifica por `Transaction.currentEntitlements`; falhando por
    /// indisponibilidade, vale este último estado recebido. **Na dúvida,
    /// libera** — negar acesso a quem pagou é pior que liberar a quem não pagou.
    var comprado: Bool
}

/// Codificação do `applicationContext` (contrato 13.3).
///
/// As chaves são as oito da tabela de 13.3, literais, em snake_case como o resto
/// do schema (spec 7.0). **São contrato entre dois binários diferentes**: mudar
/// uma delas sem mudar o outro lado quebra a sincronização em silêncio, e é por
/// isso que elas vivem numa fonte compartilhada em vez de repetidas nos dois
/// serviços.
enum SyncPayload {

    /// Limite do `updateApplicationContext`, em bytes (regra 11.12).
    ///
    /// O estado leve tem oito campos escalares e uma lista de no máximo quatro
    /// equipamentos: fica em algumas centenas de bytes. O limite é folgadíssimo,
    /// e o teste `contextoCabeFolgadoNoLimite` garante que continue sendo.
    static let limiteDoContexto = 262_144

    enum Chave {
        static let tamanhoRaia = "tamanho_raia_m"
        static let raiaConfirmada = "raia_confirmada"
        static let ritmoDescanso = "ritmo_descanso"
        static let distanciaMin = "distancia_min_m"
        static let distanciaMax = "distancia_max_m"
        static let incluirEducativos = "incluir_educativos"
        static let incluirPernada = "incluir_pernada"
        static let equipamentos = "equipamentos"
        static let prefsAtualizadoEm = "prefs_atualizado_em"
        static let comprado = "comprado"
    }

    /// Monta o dicionário do `applicationContext`.
    ///
    /// Recebe: o estado leve.
    /// Devolve: um dicionário de tipos de property list — os únicos que o
    /// WatchConnectivity aceita. `Date` **não** é um deles em toda situação, e
    /// por isso `prefs_atualizado_em` viaja como `Double` de timestamp Unix,
    /// exatamente como a tabela 13.3 declara.
    static func dicionario(de estado: EstadoLeve) -> [String: Any] {
        [
            Chave.tamanhoRaia: estado.tamanhoRaiaM,
            Chave.raiaConfirmada: estado.raiaConfirmada,
            Chave.ritmoDescanso: estado.ritmoDescanso.rawValue,
            Chave.distanciaMin: estado.distanciaMinM,
            Chave.distanciaMax: estado.distanciaMaxM,
            Chave.incluirEducativos: estado.incluirEducativos,
            Chave.incluirPernada: estado.incluirPernada,
            // Ordenado para o dicionário ser estável entre execuções: contexto
            // idêntico não deve parecer diferente e disparar escrita à toa.
            Chave.equipamentos: estado.equipamentos.sorted(),
            Chave.prefsAtualizadoEm: estado.prefsAtualizadoEm.timeIntervalSince1970,
            Chave.comprado: estado.comprado,
        ]
    }

    /// Lê o dicionário recebido no relógio.
    ///
    /// Recebe: o `applicationContext` cru.
    /// Devolve: o estado leve, ou `nil` se o payload não tiver o mínimo para ser
    /// confiável.
    ///
    /// **Um payload incompleto é descartado inteiro, não completado com
    /// defaults.** Aplicar metade de um contexto deixaria o relógio com uma
    /// piscina de um lugar e um ritmo de outro — pior que ignorar e seguir com o
    /// que já está em disco (critério 8.6).
    static func estado(de dicionario: [String: Any]) -> EstadoLeve? {
        guard let tamanhoRaia = dicionario[Chave.tamanhoRaia] as? Int,
            let raiaConfirmada = dicionario[Chave.raiaConfirmada] as? Bool,
            let ritmoBruto = dicionario[Chave.ritmoDescanso] as? String,
            let ritmo = RitmoDescanso(rawValue: ritmoBruto),
            let distanciaMin = dicionario[Chave.distanciaMin] as? Int,
            let distanciaMax = dicionario[Chave.distanciaMax] as? Int,
            let educativos = dicionario[Chave.incluirEducativos] as? Bool,
            let pernada = dicionario[Chave.incluirPernada] as? Bool,
            let equipamentos = dicionario[Chave.equipamentos] as? [String],
            let atualizadoEm = dicionario[Chave.prefsAtualizadoEm] as? Double,
            let comprado = dicionario[Chave.comprado] as? Bool
        else { return nil }

        return EstadoLeve(
            tamanhoRaiaM: tamanhoRaia,
            raiaConfirmada: raiaConfirmada,
            ritmoDescanso: ritmo,
            distanciaMinM: distanciaMin,
            distanciaMaxM: distanciaMax,
            incluirEducativos: educativos,
            incluirPernada: pernada,
            equipamentos: Set(equipamentos),
            prefsAtualizadoEm: Date(timeIntervalSince1970: atualizadoEm),
            comprado: comprado)
    }

    /// Quantos bytes um dicionário ocupa quando serializado.
    ///
    /// Mede em property list binária, que é o formato do WatchConnectivity —
    /// medir em JSON daria outro número e a folga contra o limite seria mentira.
    static func tamanhoEmBytes(_ dicionario: [String: Any]) -> Int {
        (try? PropertyListSerialization.data(
            fromPropertyList: dicionario, format: .binary, options: 0))?.count ?? .max
    }
}
