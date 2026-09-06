import Foundation
import SwiftData

/// Um equipamento que o nadador marcou como "está na mochila" (spec 7.8).
///
/// **Zero linhas é estado válido e comum**: nadador sem equipamento nenhum.
/// Nesse caso a geração usa só exercícios com `equipamento_exigido = nenhum`
/// (critério 8.4), que são 168 dos 226.
///
/// Exclusão é **hard delete** (spec 7.10): isto é estado de configuração, não
/// histórico. Desmarcar um equipamento apaga a linha, e nada aponta para ela.
@Model
final class EquipamentoSelecionado {

    @Attribute(originalName: "id")
    var id: UUID

    /// Referência **lógica** ao `tipos_equipamento.json`, sem FK (spec 7.8).
    /// Único: marcar duas vezes o mesmo equipamento não é estado possível.
    @Attribute(.unique, originalName: "equipamento_id")
    var equipamentoId: String

    @Attribute(originalName: "selecionado_em")
    var selecionadoEm: Date

    init(
        id: UUID = UUID(),
        equipamentoId: String,
        selecionadoEm: Date = .now
    ) {
        self.id = id
        self.equipamentoId = equipamentoId
        self.selecionadoEm = selecionadoEm
    }
}
