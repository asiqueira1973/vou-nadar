import Foundation

/// Falhas na carga do catálogo embarcado (critério de aceite 8.1.6).
///
/// Qualquer um destes casos é falha **fatal controlada**: o catálogo vive no
/// bundle assinado, então um erro aqui só pode vir de build quebrado, nunca de
/// dado do usuário. O app não segue com catálogo vazio nem com catálogo
/// parcialmente válido — sortear exercício de um arquivo violado produziria
/// treino errado em silêncio, que é exatamente o que o princípio 0.6 proíbe.
enum CatalogError: Error, Equatable, CustomStringConvertible {

    /// O JSON não está no bundle. Em geral significa que o arquivo saiu da
    /// lista de recursos do target no `project.yml`.
    case missingResource(String)

    /// O JSON está no bundle mas não decodifica no DTO — campo faltando, tipo
    /// trocado, ou valor de enum que o Swift não conhece.
    case decodingFailed(resource: String, motivo: String)

    /// O JSON decodifica mas viola uma das regras de integridade do critério
    /// 8.1.6. A mensagem nomeia a regra e o `exercicio_id` culpado.
    case integrityViolation(String)

    var description: String {
        switch self {
        case .missingResource(let nome):
            "recurso ausente no bundle: \(nome)"
        case .decodingFailed(let recurso, let motivo):
            "falha ao decodificar \(recurso): \(motivo)"
        case .integrityViolation(let motivo):
            "catálogo viola a integridade: \(motivo)"
        }
    }
}
