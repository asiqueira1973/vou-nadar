import Foundation
import SwiftData

/// Um treino gerado pelo algoritmo (spec 7.4).
///
/// Máquina de estados em 12.1: `gerado` → `favorito` → `arquivado`. Não existe
/// estado "editado": edição de treino está fora do escopo do v1 (spec 3.2), e
/// arquivado é terminal.
///
/// A exclusão é **soft delete** por `arquivado_em` (spec 7.10), porque há
/// sessões apontando para o treino e apagá-lo apagaria histórico de volume
/// (regra 11.15).
///
/// Convenção de idioma (spec 7.0): nome persistido em português snake_case,
/// preservado por `@Attribute(originalName:)`; propriedade Swift na mesma
/// palavra em lowerCamelCase.
///
/// **Quatro campos são congelados na geração e nunca recalculados na leitura**
/// — `tamanho_raia_m`, `ritmo_descanso_usado`, e por baixo deles os descansos e
/// as voltas de cada série. É o princípio 0.6: um treino guardado hoje abre
/// igual daqui a dois anos, mesmo que o catálogo ou a tabela de descanso mudem.
@Model
final class Treino {

    @Attribute(.unique, originalName: "id")
    var id: UUID

    /// Nulo enquanto não favoritado; exibido como "Treino de {data curta}".
    /// Ao favoritar vira obrigatório: 1 a 60 caracteres, não só espaços
    /// (regra 11.14).
    @Attribute(originalName: "titulo")
    var titulo: String?

    /// Onde o treino foi gerado. Governa a regra 11.18: o relógio nunca edita
    /// nem apaga treino com `gerado_iphone`, e treino `gerado_watch` existe só
    /// no relógio no v1.
    @Attribute(originalName: "origem")
    var origem: OrigemTreino = OrigemTreino.gerado_iphone

    /// Soma de `metros_totais` de todas as séries, sobre a distância **real**
    /// já adaptada à raia (regra 11.3), nunca sobre a do catálogo.
    @Attribute(originalName: "distancia_total_m")
    var distanciaTotalM: Int

    /// Faixa que o usuário pediu na geração. Guardada para o histórico fazer
    /// sentido depois, quando a faixa da Home já tiver mudado.
    @Attribute(originalName: "distancia_min_solicitada_m")
    var distanciaMinSolicitadaM: Int

    @Attribute(originalName: "distancia_max_solicitada_m")
    var distanciaMaxSolicitadaM: Int

    /// **Congelado na geração.** O treino foi montado para uma piscina
    /// específica: a regra 11.3 adaptou cada distância ao número inteiro de
    /// voltas dessa raia. Mudar de piscina nos Ajustes **não** reescreve treino
    /// salvo (spec 7.4 e critério 8.3).
    @Attribute(originalName: "tamanho_raia_m")
    var tamanhoRaiaM: Int

    /// **Congelado na geração**, junto com os descansos das séries. É o
    /// multiplicador global que estava valendo quando o treino nasceu
    /// (princípio 0.6 e regra 11.5).
    @Attribute(originalName: "ritmo_descanso_usado")
    var ritmoDescansoUsado: RitmoDescanso = RitmoDescanso.normal

    /// Estado do interruptor de educativos no momento da geração.
    @Attribute(originalName: "com_educativos")
    var comEducativos: Bool = false

    /// Estado do interruptor de pernada no momento da geração.
    @Attribute(originalName: "com_pernada")
    var comPernada: Bool = false

    /// Define o que vai para o relógio pela sincronização (regra 11.12).
    @Attribute(originalName: "favorito")
    var favorito: Bool = false

    /// Contador **denormalizado** de execuções.
    ///
    /// Poderia ser `sessoes.count`. O campo existe porque a lista de Favoritos
    /// exibe o contador em toda linha, e contar relação por linha no SwiftData
    /// é lento o bastante para ser percebido (spec 7.4). O preço é que ele
    /// PRECISA ser atualizado na mesma transação de toda inserção e remoção de
    /// sessão (regra 11.13), sob pena de divergir.
    @Attribute(originalName: "vezes_executado")
    var vezesExecutado: Int = 0

    /// Nulo enquanto nunca executado (regra 11.13).
    @Attribute(originalName: "ultima_execucao_em")
    var ultimaExecucaoEm: Date?

    @Attribute(originalName: "criado_em")
    var criadoEm: Date

    /// Chave de ordenação da lista de Favoritos, decrescente (critério 8.5).
    @Attribute(originalName: "atualizado_em")
    var atualizadoEm: Date

    /// **Soft delete** (spec 7.10). Nulo = ativo. Preenchido, o treino some das
    /// listas, mas as sessões continuam no Histórico e no volume (regra 11.15).
    @Attribute(originalName: "arquivado_em")
    var arquivadoEm: Date?

    /// As quatro seções, sempre quatro, inclusive quando alguma fica vazia em
    /// treino curto (regra 11.1). Cascade: não têm significado fora do treino
    /// (spec 7.10).
    @Relationship(deleteRule: .cascade, inverse: \SecaoTreino.treino)
    var secoes: [SecaoTreino] = []

    /// As execuções deste treino, de zero a n (spec 7.4).
    ///
    /// Na prática o cascade nunca dispara: `treino` usa soft delete e não é
    /// apagado de verdade. A regra fica declarada porque é o que o modelo
    /// afirma, e porque "Apagar todos os dados" nos Ajustes é uma exclusão real.
    @Relationship(deleteRule: .cascade, inverse: \SessaoNatacao.treino)
    var sessoes: [SessaoNatacao] = []

    init(
        id: UUID = UUID(),
        titulo: String? = nil,
        origem: OrigemTreino,
        distanciaTotalM: Int,
        distanciaMinSolicitadaM: Int,
        distanciaMaxSolicitadaM: Int,
        tamanhoRaiaM: Int,
        ritmoDescansoUsado: RitmoDescanso,
        comEducativos: Bool,
        comPernada: Bool,
        favorito: Bool = false,
        vezesExecutado: Int = 0,
        ultimaExecucaoEm: Date? = nil,
        criadoEm: Date = .now,
        atualizadoEm: Date = .now,
        arquivadoEm: Date? = nil
    ) {
        self.id = id
        self.titulo = titulo
        self.origem = origem
        self.distanciaTotalM = distanciaTotalM
        self.distanciaMinSolicitadaM = distanciaMinSolicitadaM
        self.distanciaMaxSolicitadaM = distanciaMaxSolicitadaM
        self.tamanhoRaiaM = tamanhoRaiaM
        self.ritmoDescansoUsado = ritmoDescansoUsado
        self.comEducativos = comEducativos
        self.comPernada = comPernada
        self.favorito = favorito
        self.vezesExecutado = vezesExecutado
        self.ultimaExecucaoEm = ultimaExecucaoEm
        self.criadoEm = criadoEm
        self.atualizadoEm = atualizadoEm
        self.arquivadoEm = arquivadoEm
    }
}

extension Treino {

    /// As quatro seções na ordem de exibição da regra 11.1, independentemente
    /// da ordem em que o SwiftData devolveu a relação.
    ///
    /// A relação do SwiftData **não tem ordem garantida**. Toda leitura de
    /// seção passa por aqui; quem ler `secoes` cru pode mostrar a soltura antes
    /// do aquecimento.
    var secoesOrdenadas: [SecaoTreino] {
        secoes.sorted { $0.ordem < $1.ordem }
    }

    /// Verdadeiro quando alguma série teve a distância alterada pela adaptação
    /// à raia (regra 11.3).
    ///
    /// É o que decide se a nota da copy 15.18 aparece no Detalhe: "As
    /// distâncias foram ajustadas para fechar voltas inteiras na sua piscina de
    /// {n} m." Sem ela o usuário acha que o app errou ao mostrar `4×96` em vez
    /// de `4×100` (risco R2b).
    var teveDistanciaAjustada: Bool {
        secoes.contains { secao in
            secao.series.contains { $0.distanciaM != $0.distanciaCatalogoM }
        }
    }
}
