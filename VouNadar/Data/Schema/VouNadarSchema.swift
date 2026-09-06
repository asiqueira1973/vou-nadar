import Foundation
import SwiftData

/// A versão 1 do schema persistido (spec 7.12).
///
/// O schema nasce versionado **mesmo sem nenhuma migração ainda**. É baratíssimo
/// declarar agora e caro fazer depois de ter usuário instalado: sem
/// `VersionedSchema` desde o dia um, a primeira mudança de modelo obriga a
/// escolher entre apagar o banco de quem já usa ou escrever uma migração
/// retroativa sem ponto de partida declarado.
///
/// Não confundir com `versao_catalogo`, que é a versão do JSON embarcado
/// (spec 7.2) e não tem relação com o schema do banco.
///
/// ## Divergência declarada em relação à seção 7.0 do spec
///
/// A seção 7.0 diz que o banco fica em português **`snake_case`, "preservado por
/// `@Attribute(originalName:)`"**. Isso não acontece, e o mecanismo citado não
/// faz isso: `originalName` declara o nome **anterior** de uma propriedade, para
/// o SwiftData mapear numa migração. Num store novo ele não define o nome
/// persistido — o SwiftData usa o nome da propriedade Swift.
///
/// Verificado no banco gravado: as colunas saem `ZDISTANCIATOTALM`,
/// `ZDESCANSOPOSSERIESEG`, `ZVOLTASPORREPETICAO`, e não `Z..._..._...`.
///
/// **O que continua valendo é o essencial**: o banco está em português, porque
/// as propriedades foram nomeadas em português. O que não se sustenta é o
/// `snake_case`.
///
/// Decisão do Alexandre em 06/09/2026: **aceitar**. As anotações
/// `@Attribute(originalName:)` ficam onde estão — elas documentam a intenção e
/// passam a ter efeito real no dia da primeira renomeação de propriedade, que é
/// exatamente para o que servem.
enum VouNadarSchemaV1: VersionedSchema {

    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    /// As seis entidades persistidas da seção 7.
    ///
    /// O **catálogo não está aqui** de propósito: `exercicio_catalogo` e
    /// `tipo_equipamento` vivem como JSON no bundle assinado, são read-only e
    /// nunca entram no SwiftData (spec 7.13).
    static var models: [any PersistentModel.Type] {
        [
            Treino.self,
            SecaoTreino.self,
            SerieTreino.self,
            Preferencias.self,
            EquipamentoSelecionado.self,
            SessaoNatacao.self,
        ]
    }
}

/// Plano de migração do banco (spec 7.12).
///
/// Declarado desde o v1 com uma versão só e nenhuma etapa. Quando a v2 mudar o
/// modelo — o `tipo_tempo` do intervalo de saída (roadmap 28.1), por exemplo —
/// a etapa entra aqui e o `ModelContainer` já sabe consumi-la, sem reescrever a
/// inicialização dos dois apps.
enum VouNadarMigrationPlan: SchemaMigrationPlan {

    static var schemas: [any VersionedSchema.Type] {
        [VouNadarSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

extension ModelContainer {

    /// Cria o container do app, com um store local por aparelho (spec 4.1).
    ///
    /// Recebe: se o store deve ficar só em memória — usado pelos testes.
    /// Devolve: o `ModelContainer` da versão corrente do schema.
    /// Erros: os do próprio SwiftData ao abrir o store.
    ///
    /// **Sem CloudKit no v1** (decisão 4.3): a sincronização por iCloud está no
    /// roadmap 28.6. Isso mantém a promessa de "sem conta, sem internet" e não
    /// exige iCloud ligado, ao custo de os dois aparelhos terem stores
    /// independentes — que é exatamente o que a regra 11.12 resolve pelo
    /// WatchConnectivity, e só no sentido iPhone → Watch.
    static func vouNadar(emMemoria: Bool = false) throws -> ModelContainer {
        let configuracao = ModelConfiguration(
            schema: Schema(versionedSchema: VouNadarSchemaV1.self),
            isStoredInMemoryOnly: emMemoria)
        return try ModelContainer(
            for: Schema(versionedSchema: VouNadarSchemaV1.self),
            migrationPlan: VouNadarMigrationPlan.self,
            configurations: configuracao)
    }
}
