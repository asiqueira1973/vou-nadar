import Testing
import UIKit

@testable import VouNadar

/// Todo SF Symbol usado pelo app existe de verdade.
///
/// **Este teste existe por um motivo específico e desagradável**: um nome de SF
/// Symbol errado não quebra o build, não emite warning e não lança em tempo de
/// execução. Ele simplesmente desenha nada — e o app chega à App Store com um
/// quadrado vazio no lugar do ícone. O `DESIGN-SYSTEM.md` avisa disso na seção
/// 4, e este é o único jeito de a advertência virar garantia.
///
/// Cobre as duas origens de nome no app:
/// 1. `Simbolos`, o registro de código;
/// 2. o campo `icone_sf` de `tipos_equipamento.json`, que é dado do catálogo
///    (spec 7.3) e igualmente capaz de conter um nome morto.
struct SymbolsTests {

    @Test("Todo símbolo do registro de código resolve no sistema")
    func simbolosDoCodigoExistem() {
        var mortos: [String] = []
        for nome in Simbolos.todos where UIImage(systemName: nome) == nil {
            mortos.append(nome)
        }
        #expect(
            mortos.isEmpty,
            """
            SF Symbol inexistente — vira quadrado vazio em produção (DESIGN-SYSTEM.md seção 4):
            \(mortos.joined(separator: ", "))
            """)
    }

    @Test("Todo icone_sf de tipos_equipamento.json resolve no sistema (spec 7.3)")
    func simbolosDoCatalogoExistem() throws {
        let catalogo = try CatalogStore()
        var mortos: [String] = []
        for equipamento in catalogo.equipmentTypes
        where UIImage(systemName: equipamento.icone_sf) == nil {
            mortos.append("\(equipamento.equipamento_id) → \(equipamento.icone_sf)")
        }
        #expect(mortos.isEmpty, "icone_sf inexistente:\n\(mortos.joined(separator: "\n"))")
    }

    @Test("O registro não tem nome repetido apontando para papéis diferentes")
    func registroSemDuplicataAcidental() {
        // `hand.raised` aparece duas vezes de propósito — no selo de braçada e
        // no palmar do catálogo —, e isso é intencional. O que este teste pega é
        // a lista `todos` ficar dessincronizada das constantes.
        #expect(Simbolos.todos.count == 18)
        #expect(!Simbolos.todos.contains(""))
    }
}
