import Foundation

/// Um tipo de equipamento que o nadador pode ter na mochila (spec 7.3).
///
/// Recebe: as chaves do array `equipamentos` de `tipos_equipamento.json`.
/// Devolve: um valor imutável usado em dois lugares — para desenhar a lista de
/// seleção da Home (tela P1) e para validar `equipamento_exigido` do catálogo
/// (critério 8.1.6).
///
/// Convenção de idioma (spec 7.0): DTO do schema, campos em português.
struct TipoEquipamento: Decodable, Sendable, Identifiable, Hashable {

    /// Chave primária. Valores: `nenhum`, `pull_buoy`, `palmares`,
    /// `nadadeiras`, `prancha`.
    let equipamento_id: String

    /// Nome exibido: `Nenhum`, `Pull buoy`, `Palmares`, `Nadadeiras`,
    /// `Prancha`.
    let nome: String

    /// SF Symbol da linha de seleção. Vem do arquivo, não do código — o
    /// guardrail 10 do design system exige SF Symbol e proíbe desenho próprio,
    /// e este campo é a única fonte desses nomes.
    let icone_sf: String

    /// Ordem de exibição. `nenhum` tem ordem 0 e **não aparece na tela**: é a
    /// ausência de equipamento, não uma opção que o usuário marca (spec 7.3).
    let ordem: Int

    var id: String { equipamento_id }

    /// Verdadeiro para os equipamentos que a interface lista de fato, isto é,
    /// todos menos `nenhum` (spec 7.3).
    ///
    /// Fica aqui, e não na View, para que a Home não precise repetir a regra.
    var apareceNaTela: Bool { equipamento_id != "nenhum" }
}

/// Envelope do arquivo `tipos_equipamento.json` (spec 7.3): objeto com uma
/// única chave de topo, `equipamentos`, e não um array solto.
struct EquipamentosArquivo: Decodable, Sendable {
    let equipamentos: [TipoEquipamento]
}
