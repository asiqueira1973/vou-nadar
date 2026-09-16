import Foundation

/// O treino no formato que a tela lê (tela P2).
///
/// Existe porque o Detalhe mostra **duas coisas diferentes com o mesmo
/// desenho**: um treino recém-gerado, que ainda não está no banco (épico 8.4), e
/// um favorito lido do SwiftData (épico 8.5). Sem este modelo a tela seria
/// escrita duas vezes, e as duas versões divergiriam no primeiro ajuste.
///
/// **Não recalcula nada.** Todo número aqui é cópia do que a geração congelou —
/// descanso, distância adaptada, voltas (princípio 0.6). A tela é leitura pura.
struct WorkoutPresentation: Equatable, Hashable {

    /// Nulo enquanto o treino não foi favoritado; a tela exibe "Treino de {data
    /// curta}" nesse caso (regra 11.14).
    let titulo: String?

    /// Data de criação, para o título provisório.
    let criadoEm: Date

    /// A soma das distâncias **reais**, já adaptadas à raia (regra 11.3). É o
    /// numeral herói.
    let distanciaTotalM: Int

    /// A raia para a qual o treino foi montado, congelada na geração (spec 7.4).
    let tamanhoRaiaM: Int

    /// O ritmo com que os descansos foram calculados, congelado (princípio 0.6).
    let ritmo: RitmoDescanso

    /// Quantas vezes foi executado (regra 11.13). Zero em treino recém-gerado.
    let vezesExecutado: Int

    /// As quatro seções, sempre quatro, inclusive vazias (regra 11.1).
    let secoes: [SecaoApresentada]

    /// Verdadeiro quando alguma série teve a distância mudada pela adaptação à
    /// raia (regra 11.3). É a condição da nota da copy 15.18 aparecer sob o
    /// herói — sem ela o usuário acha que o app errou ao mostrar `4×96` em vez
    /// de `4×100` (risco R2b).
    var teveDistanciaAjustada: Bool {
        secoes.contains { $0.series.contains { $0.distanciaM != $0.distanciaCatalogoM } }
    }

    /// Todos os `exercicio_id`, na ordem das seções. É o multiconjunto que
    /// "Gerar outro" manda ao motor para ele não repetir o treino da tela.
    var todosOsExercicioIds: [String] {
        secoes.flatMap { $0.series.map(\.exercicioId) }
    }

    struct SecaoApresentada: Equatable, Hashable {
        let tipo: TipoSecao
        let series: [SerieApresentada]
        var estaVazia: Bool { series.isEmpty }
    }

    struct SerieApresentada: Equatable, Hashable, Identifiable {
        let id: String
        /// Referência lógica ao catálogo (spec 7.6). Não é exibida — serve para
        /// "Gerar outro" comparar o conjunto com o do treino na tela.
        let exercicioId: String
        let repeticoes: Int
        /// Distância **real** por repetição. É a que a tela mostra.
        let distanciaM: Int
        /// A do catálogo. Só serve para saber se houve ajuste; nunca é exibida.
        let distanciaCatalogoM: Int
        let nome: String
        let descricao: String
        let equipamentoExigido: String
        let modo: ModoExercicio
        let intensidade: Intensidade
        /// Descanso entre as repetições. Zero quando há só uma repetição.
        let descansoSeg: Int
        /// Travessias de cada repetição, congeladas na geração (regra 11.3). É
        /// o que `LapDisplay` traduz para chegadas ou piscinas.
        let voltasPorRepeticao: Int
        /// SF Symbol do equipamento, resolvido do `icone_sf` do catálogo
        /// (spec 7.3). Nulo quando a série não exige equipamento.
        let simboloDoEquipamento: String?
    }
}

extension WorkoutPresentation {

    /// Monta a apresentação de um treino recém-gerado, ainda fora do banco
    /// (épico 8.4).
    init(resultado: GenerationResult, catalogo: CatalogStore, criadoEm: Date = .now) {
        self.titulo = nil
        self.criadoEm = criadoEm
        self.distanciaTotalM = resultado.totalM
        self.tamanhoRaiaM = resultado.laneLengthM
        self.ritmo = resultado.restPace
        self.vezesExecutado = 0
        self.secoes = resultado.secoes.map { secao in
            SecaoApresentada(
                tipo: secao.tipo,
                series: secao.series.map { serie in
                    SerieApresentada(
                        id: "\(secao.tipo.rawValue)-\(serie.ordem)-\(serie.exercicioId)",
                        exercicioId: serie.exercicioId,
                        repeticoes: serie.repeticoes,
                        distanciaM: serie.distanciaM,
                        distanciaCatalogoM: serie.distanciaCatalogoM,
                        nome: serie.nomeSnapshot,
                        descricao: serie.descricaoSnapshot,
                        equipamentoExigido: serie.equipamentoExigido,
                        modo: serie.modo,
                        intensidade: serie.intensidade,
                        descansoSeg: serie.descansoSeg,
                        voltasPorRepeticao: serie.voltasPorRepeticao,
                        simboloDoEquipamento: Self.simbolo(
                            deEquipamento: serie.equipamentoExigido, catalogo: catalogo))
                })
        }
    }

    /// Monta a apresentação de um treino salvo (épico 8.5).
    ///
    /// Lê apenas os snapshots de `serie_treino`: o catálogo não é consultado, e
    /// é por isso que um favorito antigo continua legível mesmo que o exercício
    /// tenha saído numa release (princípio 0.6 e spec 7.6).
    init(treino: Treino, catalogo: CatalogStore) {
        self.titulo = treino.titulo
        self.criadoEm = treino.criadoEm
        self.distanciaTotalM = treino.distanciaTotalM
        self.tamanhoRaiaM = treino.tamanhoRaiaM
        self.ritmo = treino.ritmoDescansoUsado
        self.vezesExecutado = treino.vezesExecutado
        self.secoes = treino.secoesOrdenadas.map { secao in
            SecaoApresentada(
                tipo: secao.tipoSecao,
                series: secao.seriesOrdenadas.map { serie in
                    SerieApresentada(
                        id: serie.id.uuidString,
                        exercicioId: serie.exercicioId,
                        repeticoes: serie.repeticoes,
                        distanciaM: serie.distanciaM,
                        distanciaCatalogoM: serie.distanciaCatalogoM,
                        nome: serie.nomeSnapshot,
                        descricao: serie.descricaoSnapshot,
                        equipamentoExigido: serie.equipamentoExigido,
                        modo: serie.modo,
                        intensidade: serie.intensidade,
                        descansoSeg: serie.descansoSeg,
                        voltasPorRepeticao: serie.voltasPorRepeticao,
                        simboloDoEquipamento: Self.simbolo(
                            deEquipamento: serie.equipamentoExigido, catalogo: catalogo))
                })
        }
    }

    /// O SF Symbol de um equipamento, ou `nil` para `nenhum`.
    ///
    /// O nome vem do `icone_sf` do JSON, nunca de literal no código — é dado do
    /// catálogo (spec 7.3), e `SymbolsTests` valida que todos resolvem.
    private static func simbolo(deEquipamento id: String, catalogo: CatalogStore) -> String? {
        guard id != "nenhum" else { return nil }
        return catalogo.equipment(id: id)?.icone_sf
    }
}

extension ModoExercicio {

    /// O selo exibido na linha da série, ou `nil` para `nado`.
    ///
    /// `nado` não ganha selo: é o caso comum, e marcar o comum é ruído. Os
    /// outros três ganham, em `.caption2`, cor secundária, com SF Symbol antes —
    /// **sem pílula colorida** (DESIGN-SYSTEM.md, tipografia).
    var selo: (texto: LocalizedStringResource, simbolo: String)? {
        switch self {
        case .nado: nil
        case .bracada: (Copy.seloBracada, Simbolos.modoBracada)
        case .pernada: (Copy.seloPernada, Simbolos.modoPernada)
        case .educativo: (Copy.seloTecnica, Simbolos.modoTecnica)
        }
    }
}
