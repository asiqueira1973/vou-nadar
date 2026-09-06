import Foundation
import Testing

/// Pureza das fontes compartilhadas pelos dois targets (critério de aceite
/// 8.1.7).
///
/// `Domain/`, `Data/Catalog/`, `Data/Enums/` e `Data/Models/` são compilados
/// **nos dois apps** — iPhone e Apple Watch — sem Swift Package no meio
/// (spec 4.2 e princípio 0.7). O que garante que continuem compiláveis dos dois
/// lados é não deixarem entrar framework de plataforma.
///
/// Este teste é a única coisa entre essa promessa e um `import SwiftUI` distraído
/// numa terça-feira. Ele lê os arquivos **em disco**, não o binário: um import
/// proibido reprova aqui antes de reprovar no build do relógio.
///
/// A raiz do repositório sai de `#filePath`, e não de variável de ambiente, para
/// o teste não depender de configuração de esquema.
struct SharedSourcePurityTests {

    /// Frameworks que não podem aparecer nas fontes compartilhadas.
    ///
    /// `SwiftUI`, `UIKit` e `WatchKit` são interface; `HealthKit` só existe no
    /// target do relógio (spec 4.1). `WidgetKit` entra na lista porque a
    /// complication é um terceiro target e nada compartilhado pode depender
    /// dela.
    static let frameworksProibidos = [
        "SwiftUI", "UIKit", "WatchKit", "HealthKit", "WidgetKit", "AppKit", "SwiftData",
        // A serialização da sincronização vive em Domain/Sync/ e é lida pelos
        // dois lados; quem fala com o WCSession é o Connectivity/ de cada target.
        "WatchConnectivity",
    ]

    /// As quatro pastas declaradas como fonte dos dois targets no `project.yml`
    /// (spec 4.2).
    ///
    /// `Data/Models/` e `Data/Schema/` guardam as entidades e o
    /// `VersionedSchema` e por isso são a exceção declarada: elas **podem**
    /// importar SwiftData, e só SwiftData. As outras três não podem importar
    /// nada além de Foundation.
    static let pastasCompartilhadas = [
        "VouNadar/Domain",
        "VouNadar/Data/Catalog",
        "VouNadar/Data/Enums",
        "VouNadar/Data/Models",
        "VouNadar/Data/Schema",
        "VouNadar/Data/Repositories",
    ]

    /// As pastas onde SwiftData é permitido, e só ele.
    static let pastasComSwiftData: Set<String> = [
        "VouNadar/Data/Models", "VouNadar/Data/Schema", "VouNadar/Data/Repositories",
    ]

    /// Raiz do repositório, derivada do caminho deste arquivo em tempo de
    /// compilação: `<raiz>/VouNadarTests/ArchitectureTests/este.swift`.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // ArchitectureTests/
            .deletingLastPathComponent()  // VouNadarTests/
            .deletingLastPathComponent()  // <raiz>
    }

    /// Lista os arquivos `.swift` de uma pasta, recursivamente.
    private static func arquivosSwift(em pasta: String) throws -> [URL] {
        let raiz = repoRoot.appending(path: pasta)
        guard
            let enumerador = FileManager.default.enumerator(
                at: raiz, includingPropertiesForKeys: nil)
        else { return [] }
        return enumerador.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// Extrai os módulos importados por um arquivo.
    ///
    /// Recebe: o conteúdo do arquivo.
    /// Devolve: os nomes dos módulos em cada linha `import X` — inclusive as
    /// formas `@testable import X` e `@_exported import X`, que também trazem o
    /// framework para dentro.
    private static func modulosImportados(em fonte: String) -> [String] {
        fonte.split(separator: "\n").compactMap { linha in
            let limpa = linha.trimmingCharacters(in: .whitespaces)
            guard let intervalo = limpa.range(of: #"(^|\s)import\s+"#, options: .regularExpression)
            else { return nil }
            let resto = limpa[intervalo.upperBound...]
            // Pega só o primeiro componente: `import Foundation.NSURL` conta
            // como Foundation.
            return resto.split(whereSeparator: { $0 == "." || $0 == " " }).first.map(String.init)
        }
    }

    @Test("As pastas compartilhadas existem e têm código (8.1.7)")
    func pastasExistemComCodigo() throws {
        for pasta in Self.pastasCompartilhadas {
            let arquivos = try Self.arquivosSwift(em: pasta)
            #expect(!arquivos.isEmpty, "\(pasta) não tem nenhum arquivo .swift")
        }
    }

    @Test("Nenhuma fonte compartilhada importa framework de plataforma (8.1.7)")
    func nenhumImportProibido() throws {
        var violacoes: [String] = []

        for pasta in Self.pastasCompartilhadas {
            // Exceção declarada em 4.2: as entidades do SwiftData vivem em
            // Data/Models/ e o VersionedSchema em Data/Schema/, e as duas
            // precisam do SwiftData. Nenhum outro framework passa, nem lá.
            let permitidos: Set<String> =
                Self.pastasComSwiftData.contains(pasta) ? ["SwiftData"] : []

            for arquivo in try Self.arquivosSwift(em: pasta) {
                let fonte = try String(contentsOf: arquivo, encoding: .utf8)
                for modulo in Self.modulosImportados(em: fonte)
                where Self.frameworksProibidos.contains(modulo) && !permitidos.contains(modulo) {
                    let caminho = arquivo.path.replacingOccurrences(
                        of: Self.repoRoot.path + "/", with: "")
                    violacoes.append("\(caminho) importa \(modulo)")
                }
            }
        }

        #expect(
            violacoes.isEmpty,
            """
            Fonte compartilhada importando framework de plataforma (critério 8.1.7).
            Estes arquivos são compilados nos DOIS targets (spec 4.2):
            \(violacoes.joined(separator: "\n"))
            """)
    }

    @Test("Nenhuma fonte compartilhada declara @MainActor no topo de um tipo (13.1)")
    func nenhumMainActorNoDominio() throws {
        // O gerador (contrato 13.1) e a calculadora de descanso (13.2) têm que
        // ser funções puras SEM MainActor, para as 500 gerações do teste de
        // propriedade rodarem fora da UI. O `project.yml` já fixa
        // SWIFT_DEFAULT_ACTOR_ISOLATION=nonisolated; isto pega a anotação
        // explícita, que venceria o padrão.
        var violacoes: [String] = []

        for pasta in ["VouNadar/Domain", "VouNadar/Data/Catalog", "VouNadar/Data/Enums"] {
            for arquivo in try Self.arquivosSwift(em: pasta) {
                let fonte = try String(contentsOf: arquivo, encoding: .utf8)
                if fonte.contains("@MainActor") {
                    let caminho = arquivo.path.replacingOccurrences(
                        of: Self.repoRoot.path + "/", with: "")
                    violacoes.append(caminho)
                }
            }
        }

        #expect(
            violacoes.isEmpty,
            "@MainActor em fonte de domínio (contrato 13.1):\n\(violacoes.joined(separator: "\n"))")
    }
}


/// O relógio nunca manda dado para o iPhone (princípio 0.7, critério 8.6).
///
/// **Este teste protege uma decisão de arquitetura, não uma linha de código.**
/// A promessa de sentido único não é verificável olhando uma função: ela é a
/// ausência de chamadas num arquivo inteiro. Um `sendMessage` acrescentado numa
/// tarde para "só avisar que recebeu" compila, funciona, e desfaz a decisão sem
/// ninguém perceber — até o dia em que houver conflito de dado e não existir
/// política para resolvê-lo.
///
/// O que justifica o sentido único: o dado mais importante — o que foi realmente
/// nadado — **já atravessa sozinho pelo HealthKit** (decisão 4.3). Sobra
/// sincronizar treino gerado no relógio, e a regra 11.18 decidiu que isso fica
/// no relógio no v1.
struct WatchNeverSendsTests {

    /// As APIs que enviam dado pelo WatchConnectivity.
    static let apisDeEnvio = [
        "sendMessage",
        "sendMessageData",
        "transferUserInfo",
        "transferFile",
        "transferCurrentComplicationUserInfo",
        "updateApplicationContext",
    ]

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func arquivosSwift(em pasta: String) throws -> [URL] {
        let raiz = repoRoot.appending(path: pasta)
        guard let e = FileManager.default.enumerator(at: raiz, includingPropertiesForKeys: nil)
        else { return [] }
        return e.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    @Test("Nenhuma fonte do target watchOS chama API de envio do WatchConnectivity")
    func relogioNaoEnvia() throws {
        var violacoes: [String] = []

        for arquivo in try Self.arquivosSwift(em: "VouNadarWatch") {
            let fonte = try String(contentsOf: arquivo, encoding: .utf8)
            // Ignora linhas de comentário: os arquivos EXPLICAM que não enviam,
            // e citar o nome da API na explicação não pode reprovar o teste.
            let codigo = fonte.split(separator: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")

            for api in Self.apisDeEnvio where codigo.contains(api) {
                let caminho = arquivo.path.replacingOccurrences(
                    of: Self.repoRoot.path + "/", with: "")
                violacoes.append("\(caminho) chama \(api)")
            }
        }

        #expect(
            violacoes.isEmpty,
            """
            O relógio está mandando dado para o iPhone (princípio 0.7, critério 8.6):
            \(violacoes.joined(separator: "\n"))
            """)
    }

    @Test("O iPhone usa os dois canais que o contrato 13.3 declara, e só eles")
    func iphoneUsaOsCanaisCertos() throws {
        let fontes = try Self.arquivosSwift(em: "VouNadar/Connectivity")
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")

        // Estado leve por applicationContext, favoritos por transferUserInfo.
        #expect(fontes.contains("updateApplicationContext"))
        #expect(fontes.contains("transferUserInfo"))

        // `sendMessage` exige o relógio acordado e alcançável, e falha quando
        // não está — o oposto do que a regra 11.12 quer. Não é usado.
        #expect(!fontes.contains("sendMessage"))
    }
}
