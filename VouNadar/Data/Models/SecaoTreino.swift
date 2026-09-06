import Foundation
import SwiftData

/// Uma das quatro seções de um treino (spec 7.5).
///
/// Todo treino tem exatamente quatro — `aquecimento`, `progressao`,
/// `principal`, `soltura`, nessa ordem — **inclusive quando alguma fica vazia**
/// em treino curto (regra 11.1). Seção vazia não é escondida na interface: ela
/// aparece com uma linha explicando que não há série, porque sumir com um
/// cabeçalho faz o usuário achar que o app perdeu conteúdo.
///
/// Exclusão em cascade a partir do treino: a seção não tem significado fora
/// dele (spec 7.10).
@Model
final class SecaoTreino {

    @Attribute(originalName: "id")
    var id: UUID

    @Attribute(originalName: "tipo_secao")
    var tipoSecao: TipoSecao = TipoSecao.aquecimento

    /// De 1 a 4, única por treino, um registro por `tipo_secao`.
    ///
    /// **É invariante que o repositório preserva**, não constraint do banco: o
    /// SwiftData não expressa unicidade composta (spec 7.11).
    @Attribute(originalName: "ordem")
    var ordem: Int

    /// Meta que o algoritmo tinha para esta seção na geração. Guardada só para
    /// depuração — a interface nunca mostra, e ela **não** é recalculada quando
    /// o treino é lido (princípio 0.6).
    @Attribute(originalName: "distancia_alvo_m")
    var distanciaAlvoM: Int

    /// Descanso entre esta seção e a próxima, em segundos (regra 11.6).
    ///
    /// **Zero na última seção** — ali o treino acabou. Vale para a última série
    /// da seção, onde o `descanso_pos_serie_seg` é zero justamente para dar
    /// lugar a este.
    ///
    /// É snapshot: calculado na geração como 45 s × multiplicador do ritmo,
    /// arredondado para múltiplo de 5, e nunca recalculado depois.
    @Attribute(originalName: "descanso_pos_secao_seg")
    var descansoPosSecaoSeg: Int

    @Relationship(originalName: "treino_id")
    var treino: Treino?

    /// De zero a n séries, em ordem contígua a partir de 1 (spec 7.11).
    /// Cascade: série não existe fora da seção (spec 7.10).
    @Relationship(deleteRule: .cascade, inverse: \SerieTreino.secao)
    var series: [SerieTreino] = []

    init(
        id: UUID = UUID(),
        tipoSecao: TipoSecao,
        distanciaAlvoM: Int,
        descansoPosSecaoSeg: Int
    ) {
        self.id = id
        self.tipoSecao = tipoSecao
        // A ordem é derivada do tipo, nunca passada solta: é o que garante a
        // invariante "uma seção por tipo, de 1 a 4" (spec 7.11).
        self.ordem = tipoSecao.ordem
        self.distanciaAlvoM = distanciaAlvoM
        self.descansoPosSecaoSeg = descansoPosSecaoSeg
    }
}

extension SecaoTreino {

    /// As séries na ordem contígua da geração, independentemente da ordem em
    /// que o SwiftData devolveu a relação (spec 7.11).
    ///
    /// A relação do SwiftData **não tem ordem garantida**. Toda leitura de
    /// série passa por aqui — inclusive a execução no relógio, onde ler fora de
    /// ordem faria o nadador executar o treino trocado.
    var seriesOrdenadas: [SerieTreino] {
        series.sorted { $0.ordem < $1.ordem }
    }

    /// Soma dos metros realmente nadados nesta seção, sobre a distância já
    /// adaptada à raia (regra 11.3).
    var metrosTotais: Int {
        series.reduce(0) { $0 + $1.metrosTotais }
    }

    /// Seção sem nenhuma série. É estado válido e esperado em treino curto
    /// (regra 11.1), não erro.
    var estaVazia: Bool { series.isEmpty }
}
