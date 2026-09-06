import Foundation

/// Um treino favorito no formato de transferência (contrato 13.3).
///
/// Carrega **tudo o que o relógio precisa para executar sem o iPhone**: as
/// distâncias já adaptadas à raia, os descansos e as voltas por repetição. Nada
/// aqui é recalculado do outro lado — o relógio recebe o snapshot e o guarda
/// como está (princípio 0.6).
///
/// **É tipo puro**, sem WatchConnectivity e sem SwiftData: os dois targets
/// compilam esta mesma fonte, o que é o que garante que o emissor e o receptor
/// não discordem sobre a forma do dado.
struct WorkoutTransfer: Sendable, Equatable {

    let id: UUID
    let titulo: String
    let distanciaTotalM: Int
    /// Congelada na geração (spec 7.4). O relógio usa esta, não a das
    /// preferências dele.
    let tamanhoRaiaM: Int
    let ritmoDescansoUsado: RitmoDescanso
    let atualizadoEm: Date
    let secoes: [SecaoTransferivel]

    struct SecaoTransferivel: Sendable, Equatable {
        let tipoSecao: TipoSecao
        let ordem: Int
        let descansoPosSecaoSeg: Int
        let series: [SerieTransferivel]
    }

    struct SerieTransferivel: Sendable, Equatable {
        let exercicioId: String
        let repeticoes: Int
        /// Distância real por repetição, já adaptada (regra 11.3).
        let distanciaM: Int
        let metrosTotais: Int
        /// O número que vira a contagem regressiva no pulso (regra 11.5).
        let descansoSeg: Int
        let descansoPosSerieSeg: Int
        /// O contador que encerra a repetição (regras 11.3 e 11.7).
        let voltasPorRepeticao: Int
        let nomeSnapshot: String
        let modo: ModoExercicio
        let ordem: Int
    }
}

extension WorkoutTransfer {

    enum Chave {
        static let id = "id"
        static let titulo = "titulo"
        static let distanciaTotal = "distancia_total_m"
        static let tamanhoRaia = "tamanho_raia_m"
        static let ritmoDescansoUsado = "ritmo_descanso_usado"
        static let atualizadoEm = "atualizado_em"
        static let secoes = "secoes"
        static let tipoSecao = "tipo_secao"
        static let ordem = "ordem"
        static let descansoPosSecao = "descanso_pos_secao_seg"
        static let series = "series"
        static let exercicioId = "exercicio_id"
        static let repeticoes = "repeticoes"
        static let distancia = "distancia_m"
        static let metrosTotais = "metros_totais"
        static let descanso = "descanso_seg"
        static let descansoPosSerie = "descanso_pos_serie_seg"
        static let voltas = "voltas_por_repeticao"
        static let nome = "nome_snapshot"
        static let modo = "modo"
    }

    /// Serializa para um dicionário de property list (contrato 13.3).
    ///
    /// Só tipos que o WatchConnectivity aceita: `String`, `Int`, `Bool`,
    /// `Double` e coleções deles. `UUID` vira texto e `Date` vira timestamp.
    ///
    /// **A descrição do exercício fica de fora de propósito.** Ela é o campo
    /// mais pesado do catálogo e o relógio não a mostra em tela nenhuma; incluí-la
    /// dobraria o tamanho da transferência sem ganho, e o limite de 65.536 bytes
    /// da regra 11.12 é o recurso mais escasso desta rotina.
    var dicionario: [String: Any] {
        [
            Chave.id: id.uuidString,
            Chave.titulo: titulo,
            Chave.distanciaTotal: distanciaTotalM,
            Chave.tamanhoRaia: tamanhoRaiaM,
            Chave.ritmoDescansoUsado: ritmoDescansoUsado.rawValue,
            Chave.atualizadoEm: atualizadoEm.timeIntervalSince1970,
            Chave.secoes: secoes.map { secao in
                [
                    Chave.tipoSecao: secao.tipoSecao.rawValue,
                    Chave.ordem: secao.ordem,
                    Chave.descansoPosSecao: secao.descansoPosSecaoSeg,
                    Chave.series: secao.series.map { serie in
                        [
                            Chave.exercicioId: serie.exercicioId,
                            Chave.repeticoes: serie.repeticoes,
                            Chave.distancia: serie.distanciaM,
                            Chave.metrosTotais: serie.metrosTotais,
                            Chave.descanso: serie.descansoSeg,
                            Chave.descansoPosSerie: serie.descansoPosSerieSeg,
                            Chave.voltas: serie.voltasPorRepeticao,
                            Chave.nome: serie.nomeSnapshot,
                            Chave.modo: serie.modo.rawValue,
                            Chave.ordem: serie.ordem,
                        ] as [String: Any]
                    },
                ] as [String: Any]
            },
        ]
    }

    /// Reconstrói a partir do dicionário recebido.
    ///
    /// Devolve `nil` num payload incompleto: melhor ignorar um treino do que
    /// guardar um treino pela metade e o nadador descobrir isso na água.
    init?(dicionario d: [String: Any]) {
        guard let idTexto = d[Chave.id] as? String, let id = UUID(uuidString: idTexto),
            let titulo = d[Chave.titulo] as? String,
            let distanciaTotal = d[Chave.distanciaTotal] as? Int,
            let tamanhoRaia = d[Chave.tamanhoRaia] as? Int,
            let ritmoBruto = d[Chave.ritmoDescansoUsado] as? String,
            let ritmo = RitmoDescanso(rawValue: ritmoBruto),
            let atualizado = d[Chave.atualizadoEm] as? Double,
            let secoesBrutas = d[Chave.secoes] as? [[String: Any]]
        else { return nil }

        var secoes: [SecaoTransferivel] = []
        for s in secoesBrutas {
            guard let tipoBruto = s[Chave.tipoSecao] as? String,
                let tipo = TipoSecao(rawValue: tipoBruto),
                let ordem = s[Chave.ordem] as? Int,
                let descansoPosSecao = s[Chave.descansoPosSecao] as? Int,
                let seriesBrutas = s[Chave.series] as? [[String: Any]]
            else { return nil }

            var series: [SerieTransferivel] = []
            for e in seriesBrutas {
                guard let exercicioId = e[Chave.exercicioId] as? String,
                    let repeticoes = e[Chave.repeticoes] as? Int,
                    let distancia = e[Chave.distancia] as? Int,
                    let metros = e[Chave.metrosTotais] as? Int,
                    let descanso = e[Chave.descanso] as? Int,
                    let descansoPosSerie = e[Chave.descansoPosSerie] as? Int,
                    let voltas = e[Chave.voltas] as? Int,
                    let nome = e[Chave.nome] as? String,
                    let modoBruto = e[Chave.modo] as? String,
                    let modo = ModoExercicio(rawValue: modoBruto),
                    let ordemSerie = e[Chave.ordem] as? Int
                else { return nil }

                series.append(
                    SerieTransferivel(
                        exercicioId: exercicioId, repeticoes: repeticoes, distanciaM: distancia,
                        metrosTotais: metros, descansoSeg: descanso,
                        descansoPosSerieSeg: descansoPosSerie, voltasPorRepeticao: voltas,
                        nomeSnapshot: nome, modo: modo, ordem: ordemSerie))
            }
            secoes.append(
                SecaoTransferivel(
                    tipoSecao: tipo, ordem: ordem, descansoPosSecaoSeg: descansoPosSecao,
                    series: series))
        }

        self.init(
            id: id, titulo: titulo, distanciaTotalM: distanciaTotal,
            tamanhoRaiaM: tamanhoRaia, ritmoDescansoUsado: ritmo,
            atualizadoEm: Date(timeIntervalSince1970: atualizado), secoes: secoes)
    }
}

/// Divisão dos favoritos em lotes de transferência (regra 11.12).
///
/// **É função pura.** O `transferUserInfo` aceita **65.536 bytes** por
/// transferência, e a regra manda dividir acima de **50.000 bytes
/// serializados** — a folga entre os dois números é a margem para o envelope
/// (chaves `tipo`, `lote`, `total_lotes`) e para a variação do serializador.
///
/// **O receptor SUBSTITUI o conjunto ao receber o último lote**, e não faz
/// merge. Substituição é idempotente: receber o mesmo lote duas vezes dá o mesmo
/// resultado. Merge exigiria política de conflito, que é complexidade que este
/// produto não precisa carregar (princípio 0.7).
enum FavoritesSync {

    /// Teto do `transferUserInfo`, em bytes.
    static let limiteDeTransferencia = 65_536

    /// A partir daqui a regra 11.12 manda dividir.
    static let limiarDeLote = 50_000

    /// Valor fixo da chave `tipo` (contrato 13.3).
    static let tipoFavoritos = "favoritos"

    enum Chave {
        static let tipo = "tipo"
        static let lote = "lote"
        static let totalDeLotes = "total_lotes"
        static let treinos = "treinos"
    }

    /// Monta os lotes a enviar (regra 11.12).
    ///
    /// Recebe: os favoritos a sincronizar.
    /// Devolve: um ou mais dicionários prontos para `transferUserInfo`, numerados
    /// de 1 a N. **Sempre devolve ao menos um lote**, inclusive com a lista
    /// vazia — é assim que "desfavoritei tudo" chega ao relógio: um lote vazio
    /// que substitui o conjunto por nada (critério 8.6).
    ///
    /// A divisão é por **tamanho medido**, não por contagem de treinos: um
    /// favorito com 12 séries pesa muito mais que um com 3, e cortar de 50 em 50
    /// estouraria o limite no dia em que alguém salvasse treinos longos.
    static func lotes(de treinos: [WorkoutTransfer]) -> [[String: Any]] {
        let serializados = treinos.map(\.dicionario)

        // Cabe tudo num lote só? É o caso comum.
        let unico = envelope(lote: 1, total: 1, treinos: serializados)
        if SyncPayload.tamanhoEmBytes(unico) <= limiarDeLote {
            return [unico]
        }

        // Não cabe: agrupa por tamanho acumulado.
        var grupos: [[[String: Any]]] = []
        var atual: [[String: Any]] = []
        for treino in serializados {
            let candidato = atual + [treino]
            // O envelope de teste usa 1/1; a numeração real entra no fim, e ela
            // muda o tamanho em poucos bytes, bem dentro da folga de 15.536.
            if !atual.isEmpty,
                SyncPayload.tamanhoEmBytes(envelope(lote: 1, total: 1, treinos: candidato))
                    > limiarDeLote
            {
                grupos.append(atual)
                atual = [treino]
            } else {
                atual = candidato
            }
        }
        if !atual.isEmpty { grupos.append(atual) }

        return grupos.enumerated().map { indice, grupo in
            envelope(lote: indice + 1, total: grupos.count, treinos: grupo)
        }
    }

    /// O envelope de um lote (contrato 13.3).
    static func envelope(lote: Int, total: Int, treinos: [[String: Any]]) -> [String: Any] {
        [
            Chave.tipo: tipoFavoritos,
            Chave.lote: lote,
            Chave.totalDeLotes: total,
            Chave.treinos: treinos,
        ]
    }

    /// Lê um lote recebido no relógio.
    ///
    /// Devolve: o número do lote, o total e os treinos que ele carrega, ou `nil`
    /// se o payload não for de favoritos.
    static func lerLote(_ d: [String: Any]) -> (lote: Int, total: Int, treinos: [WorkoutTransfer])? {
        guard d[Chave.tipo] as? String == tipoFavoritos,
            let lote = d[Chave.lote] as? Int,
            let total = d[Chave.totalDeLotes] as? Int,
            let brutos = d[Chave.treinos] as? [[String: Any]]
        else { return nil }
        return (lote, total, brutos.compactMap(WorkoutTransfer.init(dicionario:)))
    }
}
