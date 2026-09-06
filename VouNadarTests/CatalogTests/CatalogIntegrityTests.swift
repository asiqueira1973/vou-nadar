import Foundation
import Testing

@testable import VouNadar

/// Integridade do catálogo embarcado (critério de aceite 8.1.6).
///
/// Estas verificações existem em dois lugares de propósito: em
/// `CatalogStore.validate` elas impedem o app de subir com catálogo quebrado, e
/// aqui elas nomeiam **qual** regra falhou, que é o que faz a mensagem do teste
/// ser útil.
///
/// A contagem de 226 é afirmada aqui e não no `CatalogStore`: ela é verdade da
/// `versao_catalogo` 1, não invariante do formato. Travar o app num número
/// quebraria a primeira release que adicionar exercício; travar o *teste* nele
/// é justamente o que obriga alguém a olhar quando o arquivo mudar.
struct CatalogIntegrityTests {

    /// Carrega o catálogo do bundle do app hospedeiro.
    ///
    /// Falhar aqui significa que os JSON saíram da lista de recursos do target
    /// no `project.yml` (critério 8.1.5).
    private func carregar() throws -> CatalogStore {
        try CatalogStore()
    }

    @Test("O catálogo carrega sem erro nos dois JSON (8.1.5)")
    func carregaSemErro() throws {
        let catalogo = try carregar()
        #expect(catalogo.catalogVersion == 1)
    }

    @Test("São exatamente 226 exercícios na versao_catalogo 1 (8.1.6)")
    func contagemDeExercicios() throws {
        let catalogo = try carregar()
        #expect(catalogo.allExercises.count == 226)
    }

    @Test("São exatamente 5 equipamentos, e `nenhum` não aparece na tela (7.3)")
    func contagemDeEquipamentos() throws {
        let catalogo = try carregar()
        #expect(catalogo.equipmentTypes.count == 5)
        // `nenhum` é a ausência de equipamento, não uma opção que o usuário
        // marca: fica no arquivo com ordem 0 e fora da lista de seleção.
        #expect(catalogo.selectableEquipment.count == 4)
        #expect(catalogo.equipment(id: "nenhum")?.apareceNaTela == false)
    }

    @Test("metros_totais == repeticoes × distancia_m em todos os 226 (8.1.6)")
    func metrosTotaisConferem() throws {
        let catalogo = try carregar()
        for e in catalogo.allExercises {
            #expect(
                e.metros_totais == e.repeticoes * e.distancia_m,
                "\(e.exercicio_id): \(e.metros_totais) != \(e.repeticoes) × \(e.distancia_m)")
        }
    }

    @Test("Todo exercicio_id é único (8.1.6)")
    func identificadoresUnicos() throws {
        let catalogo = try carregar()
        let ids = catalogo.allExercises.map(\.exercicio_id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Todo equipamento_exigido existe em tipos_equipamento.json (8.1.6)")
    func equipamentoExigidoExiste() throws {
        let catalogo = try carregar()
        let validos = Set(catalogo.equipmentTypes.map(\.equipamento_id))
        for e in catalogo.allExercises {
            #expect(
                validos.contains(e.equipamento_exigido),
                "\(e.exercicio_id): equipamento desconhecido \(e.equipamento_exigido)")
        }
    }

    @Test("Repetições e distância são sempre positivas (8.1.6)")
    func valoresPositivos() throws {
        let catalogo = try carregar()
        for e in catalogo.allExercises {
            #expect(e.repeticoes > 0, "\(e.exercicio_id): repeticoes <= 0")
            #expect(e.distancia_m > 0, "\(e.exercicio_id): distancia_m <= 0")
        }
    }

    @Test("Nome e descrição nunca são vazios (7.2)")
    func textosPreenchidos() throws {
        let catalogo = try carregar()
        for e in catalogo.allExercises {
            #expect(!e.nome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(!e.descricao.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @Test("Todo exercício da versão 1 é do nado livre (7.2)")
    func todosLivre() throws {
        let catalogo = try carregar()
        // Os outros quatro casos do enum existem para a v2 (roadmap 28.4) não
        // exigir migração; nenhum registro os usa hoje.
        #expect(catalogo.allExercises.allSatisfy { $0.nado == .livre })
    }

    @Test("A distribuição de intensidade bate com a tabela da seção 7.2")
    func distribuicaoDeIntensidade() throws {
        let catalogo = try carregar()
        var contagem: [Intensidade: Int] = [:]
        for e in catalogo.allExercises { contagem[e.intensidade, default: 0] += 1 }

        #expect(contagem[.aquecimento] == 58)
        #expect(contagem[.aerobico] == 57)
        #expect(contagem[.variavel] == 39)
        #expect(contagem[.resistencia] == 34)
        #expect(contagem[.moderado] == 23)
        #expect(contagem[.soltura] == 15)
    }

    @Test("A distribuição de modo bate com a tabela da seção 7.2")
    func distribuicaoDeModo() throws {
        let catalogo = try carregar()
        var contagem: [ModoExercicio: Int] = [:]
        for e in catalogo.allExercises { contagem[e.modo, default: 0] += 1 }

        #expect(contagem[.nado] == 148)
        #expect(contagem[.educativo] == 32)
        #expect(contagem[.bracada] == 26)
        #expect(contagem[.pernada] == 20)
    }

    @Test("A distribuição de equipamento bate com a tabela da seção 7.2")
    func distribuicaoDeEquipamento() throws {
        let catalogo = try carregar()
        var contagem: [String: Int] = [:]
        for e in catalogo.allExercises { contagem[e.equipamento_exigido, default: 0] += 1 }

        #expect(contagem["nenhum"] == 168)
        #expect(contagem["pull_buoy"] == 24)
        #expect(contagem["prancha"] == 15)
        #expect(contagem["palmares"] == 10)
        #expect(contagem["nadadeiras"] == 9)
    }

    @Test("166 dos 226 têm mais de uma repetição — são os que ganham descanso interno (7.2)")
    func exerciciosComRepeticao() throws {
        let catalogo = try carregar()
        #expect(catalogo.allExercises.count { $0.repeticoes > 1 } == 166)
    }

    @Test("O índice por exercicio_id devolve o registro certo, e nil para id inexistente (7.6)")
    func indicePorIdentificador() throws {
        let catalogo = try carregar()
        let primeiro = try #require(catalogo.allExercises.first)
        #expect(catalogo.exercise(id: primeiro.exercicio_id)?.nome == primeiro.nome)
        // Devolver nil é situação NORMAL, não erro: um favorito antigo pode
        // referenciar exercício que saiu numa release (spec 7.6).
        #expect(catalogo.exercise(id: "NAO_EXISTE_XYZ") == nil)
    }
}
