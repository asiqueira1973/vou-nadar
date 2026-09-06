import Foundation

// Enums do catálogo embarcado (spec 7.2).
//
// Convenção de idioma (spec 7.0 e 18): estes valores fazem parte do SCHEMA
// PERSISTIDO — são as strings que estão dentro de `catalogo_exercicios.json` e
// que vão para dentro do SwiftData no snapshot de cada série (7.6). Por isso os
// casos e os `rawValue` são em português, em snake_case. O código que os
// consome é em inglês.
//
// Este arquivo é fonte dos DOIS targets (spec 4.2) e por isso não importa
// SwiftUI, HealthKit, UIKit nem WatchKit — o teste de pureza do critério 8.1.7
// verifica isso.

/// Esforço pedido no exercício (spec 7.2, enum `intensidade`).
///
/// Distribuição na `versao_catalogo` 1: `aquecimento` 58, `aerobico` 57,
/// `variavel` 39, `resistencia` 34, `moderado` 23, `soltura` 15.
///
/// É um dos três fatores da tabela de descanso (regra 11.5): `aquecimento` e
/// `soltura` multiplicam por 0,75×, `resistencia` por 1,25×, o resto por 1,0×.
enum Intensidade: String, Codable, CaseIterable, Sendable {
    case aquecimento
    case soltura
    case moderado
    case aerobico
    case resistencia
    case variavel
}

/// Como o ritmo é controlado dentro do bloco (spec 7.2, enum `tipo_controle`).
///
/// Os três tipos de progressão são coisas diferentes, e o treinador distingue:
/// - `progressivo` (*descend*): a progressão é ENTRE as repetições — cada tiro
///   é mais rápido que o anterior, e cada tiro é nadado em ritmo constante.
/// - `crescente` (*build*): a progressão é DENTRO de cada repetição — começa
///   leve e acelera até o fim, e todas as repetições fazem o mesmo.
/// - `split_negativo` (*negative split*): progressão em dois degraus dentro da
///   repetição — a segunda metade é mais rápida que a primeira.
///
/// Distribuição na versão 1: `constante` 174, `continuo` 19, `progressivo` 13,
/// `crescente` 10, `split_negativo` 8, `intervalo_fixo` 2.
enum TipoControle: String, Codable, CaseIterable, Sendable {
    case constante
    case crescente
    case progressivo
    case split_negativo
    case continuo
    case intervalo_fixo
}

/// O que o corpo faz no bloco (spec 7.2, enum `modo`).
///
/// Distribuição na versão 1: `nado` 148, `educativo` 32, `bracada` 26,
/// `pernada` 20.
///
/// Governa duas coisas: os interruptores da Home — `educativo` e `pernada` só
/// entram na geração com o interruptor correspondente ligado (critério 8.4) —
/// e o multiplicador de modo da tabela de descanso: `educativo` 0,75×,
/// `pernada` 1,25×, `nado` e `bracada` 1,0× (regra 11.5).
enum ModoExercicio: String, Codable, CaseIterable, Sendable {
    case nado
    case bracada
    case pernada
    case educativo
}

/// Estilo de nado (spec 7.2, enum `nado`).
///
/// Todos os 226 registros da `versao_catalogo` 1 são `livre`. Os outros quatro
/// casos são declarados desde já para que a v2 (roadmap 28.4), que traz costas,
/// peito, borboleta e medley, não exija migração de enum.
enum Nado: String, Codable, CaseIterable, Sendable {
    case livre
    case costas
    case peito
    case borboleta
    case medley
}
