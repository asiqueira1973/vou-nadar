import Foundation

/// Âncora usada só para localizar o bundle onde os JSON do catálogo foram
/// copiados.
///
/// Uma classe de Objective-C é a forma suportada de perguntar "de qual bundle
/// este código veio", o que faz o `CatalogStore` funcionar igual rodando no app
/// do iPhone, no app do relógio e dentro do bundle de teste — os três casos que
/// o critério 8.1.5 exige.
final class CatalogBundleAnchor: NSObject {}

/// Carrega, valida e indexa o catálogo embarcado (spec 7.2, 7.3 e 7.13).
///
/// Recebe: o `Bundle` onde estão `catalogo_exercicios.json` e
/// `tipos_equipamento.json`.
/// Devolve: um índice imutável em memória — a lista completa, a lista de ativos
/// e um dicionário por `exercicio_id`.
/// Erros: os três casos de `CatalogError`.
///
/// O catálogo **nunca entra no SwiftData** (spec 7.13): é recurso estático no
/// bundle assinado, read-only, substituído inteiro a cada release da App Store.
/// É a metade read-only do modelo de dados, separada de propósito da metade
/// mutável.
///
/// Não conhece SwiftData, SwiftUI, HealthKit nem WatchKit: é fonte dos dois
/// targets (spec 4.2) e o critério 8.1.7 reprova o build se algum desses
/// imports aparecer. É `Sendable` e imutável porque o gerador do contrato 13.1
/// o lê de fora da main actor.
///
/// A montagem dos pools de sorteio **não** está aqui: ela depende do tamanho da
/// raia, porque a regra 11.3 remove do sorteio os exercícios que passariam de
/// 25% de desvio na piscina configurada. Quem faz isso é o `AdaptedCatalog`,
/// construído por geração (épico 8.4).
final class CatalogStore: Sendable {

    // MARK: - Estado imutável

    /// `versao_catalogo` do arquivo embarcado. É o valor gravado em
    /// `preferencias.versao_catalogo_visto` no seed, para instalação nova não
    /// ver banner de novidade no primeiro dia (spec 7.7).
    let catalogVersion: Int

    /// Os 5 equipamentos de 7.3, na ordem de exibição declarada no arquivo.
    /// Inclui `nenhum`, que a interface não mostra (`apareceNaTela`).
    let equipmentTypes: [TipoEquipamento]

    /// Todos os exercícios do arquivo, ativos e inativos, na ordem do JSON.
    ///
    /// Os inativos ficam aqui para que um treino salvo continue legível
    /// (princípio 0.6); nenhum pool de sorteio os inclui.
    let allExercises: [ExercicioCatalogo]

    /// Só os exercícios com `ativo == true`. É a base de todo sorteio
    /// (critério 8.4).
    let activeExercises: [ExercicioCatalogo]

    /// Índice por `exercicio_id`, para a leitura de um treino salvo não varrer
    /// os 226 registros por série.
    private let byId: [String: ExercicioCatalogo]

    // MARK: - Carga

    /// Lê os dois arquivos do bundle, valida a integridade e monta os índices
    /// (critério de aceite 8.1.5 e 8.1.6).
    ///
    /// Recebe: o bundle de onde ler. O padrão é o bundle deste código, o que
    /// faz o mesmo inicializador servir aos dois apps e aos testes.
    /// Erros: os três casos de `CatalogError`.
    ///
    /// A validação roda ANTES de qualquer indexação: um catálogo violado não
    /// chega a virar índice.
    init(bundle: Bundle = Bundle(for: CatalogBundleAnchor.self)) throws {
        let catalogo = try Self.decode("catalogo_exercicios", as: CatalogoArquivo.self, from: bundle)
        let equipamentos = try Self.decode(
            "tipos_equipamento", as: EquipamentosArquivo.self, from: bundle)

        try Self.validate(catalogo: catalogo, equipamentos: equipamentos.equipamentos)

        self.catalogVersion = catalogo.versao_catalogo
        self.equipmentTypes = equipamentos.equipamentos.sorted { $0.ordem < $1.ordem }
        self.allExercises = catalogo.exercicios
        self.activeExercises = catalogo.exercicios.filter(\.ativo)
        self.byId = Dictionary(
            uniqueKeysWithValues: catalogo.exercicios.map { ($0.exercicio_id, $0) })
    }

    // MARK: - Consultas

    /// Devolve o exercício de um `exercicio_id`, ou `nil` se ele não existe
    /// mais no catálogo.
    ///
    /// Devolver `nil` é situação NORMAL, não erro: `serie_treino` guarda
    /// snapshot (princípio 0.6), então um favorito antigo pode referenciar um
    /// exercício que saiu numa release. Quem chama usa o snapshot da série, não
    /// isto — a referência é lógica e sem chave estrangeira (spec 7.6).
    func exercise(id: String) -> ExercicioCatalogo? {
        byId[id]
    }

    /// Devolve o equipamento de um `equipamento_id`, ou `nil`.
    ///
    /// Usado para desenhar o SF Symbol do equipamento na linha da série a
    /// partir do snapshot gravado em `serie_treino.equipamento_exigido`.
    func equipment(id: String) -> TipoEquipamento? {
        equipmentTypes.first { $0.equipamento_id == id }
    }

    /// Os equipamentos que a interface lista de fato, na ordem do arquivo —
    /// todos menos `nenhum` (spec 7.3).
    var selectableEquipment: [TipoEquipamento] {
        equipmentTypes.filter(\.apareceNaTela)
    }

    // MARK: - Carga e validação

    /// Lê e decodifica um JSON do bundle.
    ///
    /// Erros: `.missingResource` quando o arquivo saiu da lista de recursos do
    /// target, `.decodingFailed` quando o conteúdo não bate com o DTO.
    private static func decode<T: Decodable>(
        _ nome: String, as tipo: T.Type, from bundle: Bundle
    ) throws -> T {
        guard let url = bundle.url(forResource: nome, withExtension: "json") else {
            throw CatalogError.missingResource("\(nome).json")
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            throw CatalogError.decodingFailed(
                resource: "\(nome).json", motivo: String(describing: error))
        }
    }

    /// Verifica as regras de integridade do critério de aceite 8.1.6.
    ///
    /// Recebe: o arquivo decodificado e a lista de equipamentos.
    /// Erros: `.integrityViolation`, com a regra violada e o identificador
    /// culpado.
    ///
    /// A mesma lista é reescrita, regra a regra, em `CatalogIntegrityTests`. A
    /// duplicação é intencional: aqui ela impede o app de subir com catálogo
    /// quebrado, e lá ela nomeia qual das regras falhou, que é o que faz a
    /// mensagem do teste ser útil.
    ///
    /// A **contagem** de 226 exercícios não é verificada aqui de propósito: ela
    /// é verdade da `versao_catalogo` 1, não invariante do formato, e travar o
    /// app num número quebraria a primeira release que adicionar exercício. Quem
    /// afirma os 226 é o teste, que é onde essa afirmação pertence.
    private static func validate(
        catalogo: CatalogoArquivo, equipamentos: [TipoEquipamento]
    ) throws {
        let exercicios = catalogo.exercicios

        guard !exercicios.isEmpty else {
            throw CatalogError.integrityViolation("o catálogo está vazio")
        }
        guard !equipamentos.isEmpty else {
            throw CatalogError.integrityViolation("tipos_equipamento.json está vazio")
        }

        // `equipamento_id` único, e o conjunto contra o qual o catálogo é
        // validado logo abaixo.
        var equipamentosValidos = Set<String>()
        for equipamento in equipamentos {
            guard equipamentosValidos.insert(equipamento.equipamento_id).inserted else {
                throw CatalogError.integrityViolation(
                    "equipamento_id duplicado: \(equipamento.equipamento_id)")
            }
        }

        // `exercicio_id` único em todo o arquivo.
        var vistos = Set<String>()
        for exercicio in exercicios where !vistos.insert(exercicio.exercicio_id).inserted {
            throw CatalogError.integrityViolation(
                "exercicio_id duplicado: \(exercicio.exercicio_id)")
        }

        for e in exercicios {
            guard e.repeticoes > 0 else {
                throw CatalogError.integrityViolation("\(e.exercicio_id): repeticoes <= 0")
            }
            guard e.distancia_m > 0 else {
                throw CatalogError.integrityViolation("\(e.exercicio_id): distancia_m <= 0")
            }
            // O total materializado tem que bater com o produto (spec 7.2).
            guard e.metros_totais == e.repeticoes * e.distancia_m else {
                throw CatalogError.integrityViolation(
                    "\(e.exercicio_id): metros_totais != repeticoes × distancia_m")
            }
            // Todo `equipamento_exigido` existe em tipos_equipamento.json.
            guard equipamentosValidos.contains(e.equipamento_exigido) else {
                throw CatalogError.integrityViolation(
                    "\(e.exercicio_id): equipamento_exigido desconhecido "
                        + "(\(e.equipamento_exigido))")
            }
            guard !e.nome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                !e.descricao.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                throw CatalogError.integrityViolation(
                    "\(e.exercicio_id): nome ou descrição vazios")
            }
            guard e.adicionado_na_versao >= 1,
                e.adicionado_na_versao <= catalogo.versao_catalogo
            else {
                throw CatalogError.integrityViolation(
                    "\(e.exercicio_id): adicionado_na_versao fora de 1...\(catalogo.versao_catalogo)")
            }
        }
    }
}
