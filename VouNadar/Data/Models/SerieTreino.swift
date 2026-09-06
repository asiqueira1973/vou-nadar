import Foundation
import SwiftData

/// Uma série dentro de uma seção — o `4×100 crawl com 30s` da tela (spec 7.6).
///
/// **Guarda snapshot dos dados do exercício, não referência** (princípio 0.6).
/// `exercicio_id` é referência **lógica, sem chave estrangeira**: pode apontar
/// para um exercício removido numa release futura e nada quebra, porque tudo
/// que a interface precisa está copiado aqui.
///
/// Três campos deste modelo são o núcleo do produto e são **congelados na
/// geração**, nunca recalculados na leitura:
///
/// - `descanso_seg` — a contagem regressiva que aparece no pulso (regra 11.5)
/// - `distancia_m` — já adaptada à raia, é o que o nadador de fato nada
///   (regra 11.3)
/// - `voltas_por_repeticao` — o contador que faz o relógio saber que a
///   repetição acabou (regra 11.7)
///
/// Recalcular qualquer um deles na leitura violaria o princípio 0.6: o favorito
/// mudaria sozinho depois de uma atualização do app ou de uma troca de piscina.
@Model
final class SerieTreino {

    @Attribute(originalName: "id")
    var id: UUID

    /// Referência **lógica** ao catálogo, sem FK (spec 7.6). Serve para
    /// rastrear qual exercício originou a série; a exibição usa os snapshots.
    @Attribute(originalName: "exercicio_id")
    var exercicioId: String

    /// Snapshot do número de repetições do exercício.
    @Attribute(originalName: "repeticoes")
    var repeticoes: Int

    /// **Distância real por repetição, já adaptada à raia** (regra 11.3):
    /// `voltas_por_repeticao × tamanho_raia_m`.
    ///
    /// É o que a interface exibe em todo lugar — tela, relógio e texto copiado.
    /// Numa piscina de 16 m um `4×100` do catálogo aparece como `4×96`, porque
    /// é isso que o nadador vai nadar (regra 14.2.6 e risco R2b).
    @Attribute(originalName: "distancia_m")
    var distanciaM: Int

    /// Snapshot do que o catálogo pedia, **antes** da adaptação.
    ///
    /// Existe só para rastreabilidade e depuração. **A interface nunca mostra
    /// este número** — mostrar a distância do catálogo e nadar outra é
    /// exatamente o erro que a regra 11.3 evita.
    @Attribute(originalName: "distancia_catalogo_m")
    var distanciaCatalogoM: Int

    /// `repeticoes × distancia_m` — sobre a distância **real**, nunca a do
    /// catálogo (regra 11.3).
    @Attribute(originalName: "metros_totais")
    var metrosTotais: Int

    /// **Snapshot do descanso ENTRE as repetições**, em segundos, calculado
    /// pela regra 11.5 na geração.
    ///
    /// É o número que vira a contagem regressiva no relógio (épico 8.8) e o
    /// ` — 30s` no fim da linha do texto copiado (regra 14.2.5). Está entre 10
    /// e 90 segundos, por construção da tabela.
    @Attribute(originalName: "descanso_seg")
    var descansoSeg: Int

    /// Descanso entre esta série e a próxima da **mesma seção**, em segundos
    /// (regra 11.6): 30 s × multiplicador do ritmo, arredondado para múltiplo
    /// de 5.
    ///
    /// **Zero na última série da seção** — ali vale o `descanso_pos_secao_seg`
    /// da seção. Os dois nunca se somam.
    @Attribute(originalName: "descanso_pos_serie_seg")
    var descansoPosSerieSeg: Int

    /// `max(1, arredonda(distancia_catalogo_m / tamanho_raia_m))`, calculado na
    /// geração e **congelado** (regras 11.3 e 11.7).
    ///
    /// É o contador que o relógio usa para saber que a repetição acabou: a
    /// repetição termina quando esta quantidade de voltas é contabilizada desde
    /// o início dela. Nunca é recalculado em tempo de execução — se fosse, um
    /// treino salvo mudaria de comportamento ao trocar de piscina.
    @Attribute(originalName: "voltas_por_repeticao")
    var voltasPorRepeticao: Int

    /// Snapshot do nome exibido (princípio 0.6).
    @Attribute(originalName: "nome_snapshot")
    var nomeSnapshot: String

    /// Snapshot da descrição de instrução (princípio 0.6).
    @Attribute(originalName: "descricao_snapshot")
    var descricaoSnapshot: String

    /// Snapshot do equipamento. Desenha o SF Symbol na linha da série.
    @Attribute(originalName: "equipamento_exigido")
    var equipamentoExigido: String = "nenhum"

    /// Snapshot do modo. Desenha o selo "braçada", "pernada" ou "técnica" —
    /// em `.caption2`, cor secundária, com SF Symbol antes e **sem pílula
    /// colorida** (design system, tipografia).
    @Attribute(originalName: "modo")
    var modo: ModoExercicio = ModoExercicio.nado

    /// Snapshot da intensidade. Foi um dos três fatores do descanso desta série
    /// (regra 11.5) e fica guardado para rastreabilidade.
    @Attribute(originalName: "intensidade")
    var intensidade: Intensidade = Intensidade.aerobico

    /// Ordem contígua a partir de 1 dentro da seção (spec 7.11). **Invariante
    /// que o repositório preserva**, não constraint do banco.
    @Attribute(originalName: "ordem")
    var ordem: Int

    @Relationship(originalName: "secao_treino_id")
    var secao: SecaoTreino?

    init(
        id: UUID = UUID(),
        exercicioId: String,
        repeticoes: Int,
        distanciaM: Int,
        distanciaCatalogoM: Int,
        metrosTotais: Int,
        descansoSeg: Int,
        descansoPosSerieSeg: Int,
        voltasPorRepeticao: Int,
        nomeSnapshot: String,
        descricaoSnapshot: String,
        equipamentoExigido: String,
        modo: ModoExercicio,
        intensidade: Intensidade,
        ordem: Int
    ) {
        self.id = id
        self.exercicioId = exercicioId
        self.repeticoes = repeticoes
        self.distanciaM = distanciaM
        self.distanciaCatalogoM = distanciaCatalogoM
        self.metrosTotais = metrosTotais
        self.descansoSeg = descansoSeg
        self.descansoPosSerieSeg = descansoPosSerieSeg
        self.voltasPorRepeticao = voltasPorRepeticao
        self.nomeSnapshot = nomeSnapshot
        self.descricaoSnapshot = descricaoSnapshot
        self.equipamentoExigido = equipamentoExigido
        self.modo = modo
        self.intensidade = intensidade
        self.ordem = ordem
    }
}

extension SerieTreino {

    /// Total de voltas que esta série inteira exige: `repeticoes ×
    /// voltas_por_repeticao` (regra 11.7).
    var voltasTotais: Int {
        repeticoes * voltasPorRepeticao
    }

    /// Verdadeiro quando a adaptação à raia mudou a distância desta série
    /// (regra 11.3). Alimenta a nota da copy 15.18 no Detalhe.
    var foiAjustadaParaARaia: Bool {
        distanciaM != distanciaCatalogoM
    }
}
