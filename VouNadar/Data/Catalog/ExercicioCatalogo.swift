import Foundation

/// Um exercício do catálogo embarcado (spec 7.2).
///
/// Recebe: as chaves do array `exercicios` de `catalogo_exercicios.json`.
/// Devolve: um valor imutável, read-only durante toda a vida do app — o
/// catálogo vive no bundle assinado e é substituído inteiro a cada release
/// (spec 7.13), nunca editado pelo usuário.
///
/// O arquivo foi copiado do Swim Builder **sem uma alteração de byte** e passa
/// a ter vida própria aqui: não há package compartilhado, submódulo nem
/// sincronização, e os dois catálogos vão divergir com o tempo (spec 4.4).
///
/// Convenção de idioma (spec 7.0): este é o DTO do schema, então tanto o nome
/// dos campos quanto os valores de enum ficam em português. Não há `CodingKeys`
/// porque os nomes das propriedades já são exatamente as chaves do JSON.
///
/// É `Sendable` porque o `CatalogStore` é lido de fora da main actor: o gerador
/// do contrato 13.1 é função pura e não roda na UI.
///
/// **Não há campo de descanso aqui.** O descanso é calculado pela regra 11.5 no
/// momento da geração e gravado como snapshot em `serie_treino.descanso_seg`
/// (spec 7.2 e decisão 4.3). O catálogo também não conhece o tamanho da
/// piscina: as distâncias dele são adaptadas à raia na geração (regra 11.3).
struct ExercicioCatalogo: Decodable, Sendable, Identifiable, Hashable {

    /// Chave primária. Prefixos: `WU_` aquecimento, `CD_` soltura, `FS_`
    /// nado/braçada, `KI_` pernada, `ED_` educativo (spec 7.2).
    ///
    /// É referência **lógica**: `serie_treino.exercicio_id` aponta para cá sem
    /// chave estrangeira, e pode apontar para um exercício removido numa
    /// release futura sem nada quebrar (spec 7.6).
    let exercicio_id: String

    /// Nome exibido, em português, até 45 caracteres.
    let nome: String

    /// Uma ou duas frases de instrução. Nunca vazio.
    let descricao: String

    /// Quantas vezes o bloco é repetido. Sempre maior que zero. 166 dos 226
    /// têm valor maior que 1 — são os que ganham descanso interno (spec 7.2).
    let repeticoes: Int

    /// Metros por repetição **no catálogo**, antes da adaptação à raia.
    /// Valores presentes: 25 a 1500.
    ///
    /// Este NÃO é o número que a interface mostra. A regra 11.3 adapta a
    /// distância ao número inteiro de voltas mais próximo da piscina
    /// configurada, e é a distância adaptada que aparece na tela, no relógio e
    /// no texto copiado.
    let distancia_m: Int

    /// `repeticoes × distancia_m`. Materializado no JSON de propósito, para o
    /// arquivo ser auditável a olho nu (spec 7.2). A igualdade é verificada na
    /// carga e no teste de integridade (critério 8.1.6).
    let metros_totais: Int

    let intensidade: Intensidade
    let tipo_controle: TipoControle

    /// `nenhum` ou UM `equipamento_id` válido — o modelo suporta um só.
    /// Distribuição: `nenhum` 168, `pull_buoy` 24, `prancha` 15, `palmares` 10,
    /// `nadadeiras` 9 (spec 7.2).
    let equipamento_exigido: String

    /// Governa os interruptores de educativo e pernada da Home (critério 8.4)
    /// e o multiplicador de modo da tabela de descanso (regra 11.5).
    let modo: ModoExercicio

    /// Todos os registros da versão 1 são `livre`; o campo existe para a v2
    /// (roadmap 28.4) não exigir migração de enum.
    let nado: Nado

    /// Exercício desativado permanece no arquivo — para treinos salvos
    /// continuarem legíveis (princípio 0.6) — mas nunca é sorteado
    /// (critério 8.4).
    let ativo: Bool

    /// `versao_catalogo` em que o exercício entrou.
    let adicionado_na_versao: Int

    /// `Identifiable` para uso em listas, sem duplicar o campo.
    var id: String { exercicio_id }
}

/// Envelope do arquivo `catalogo_exercicios.json` (spec 7.2).
///
/// O arquivo é um objeto com quatro chaves de topo, não um array solto.
/// `origem` é texto documental que o app ignora deliberadamente — está lá para
/// quem abre o arquivo, não para o código.
struct CatalogoArquivo: Decodable, Sendable {
    let versao_catalogo: Int
    let gerado_em: String
    let origem: String
    let exercicios: [ExercicioCatalogo]
}
