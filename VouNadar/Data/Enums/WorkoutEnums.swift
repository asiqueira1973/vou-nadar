import Foundation

// Enums do modelo persistido (spec 7.4, 7.5, 7.7 e 7.9).
//
// Convenção de idioma (spec 7.0): casos e `rawValue` em português snake_case,
// porque fazem parte do schema gravado no SwiftData. Fonte dos dois targets
// (spec 4.2), sem import de framework de plataforma (critério 8.1.7).

/// Onde o treino foi gerado (spec 7.4, enum `origem_treino`).
///
/// Existe para a regra 11.18: o relógio nunca edita nem apaga treino com
/// `gerado_iphone`, e treino `gerado_watch` existe só no relógio no v1.
enum OrigemTreino: String, Codable, CaseIterable, Sendable {
    case gerado_iphone
    case gerado_watch
}

/// Multiplicador global da tabela de descanso (spec 7.7, enum `ritmo_descanso`).
///
/// É o único ajuste que o usuário tem sobre o descanso no v1 — editar bloco a
/// bloco ficou para a v2 (roadmap 28.3). O valor escolhido é congelado em
/// `treino.ritmo_descanso_usado` na geração, junto com os descansos das séries,
/// pelo princípio 0.6.
enum RitmoDescanso: String, Codable, CaseIterable, Sendable {
    /// 0,75× sobre a tabela da regra 11.5. Para quem já tem fôlego (copy 15.5).
    case curto
    /// 1,0× — o padrão de `preferencias.ritmo_descanso`.
    case normal
    /// 1,5× sobre a tabela. Para quem está voltando (copy 15.5).
    case longo

    /// O fator que a regra 11.5 aplica ao produto base × intensidade × modo.
    var multiplicador: Double {
        switch self {
        case .curto: 0.75
        case .normal: 1.0
        case .longo: 1.5
        }
    }
}

/// As quatro seções de um treino (spec 7.5, enum `tipo_secao`).
///
/// Todo treino tem as quatro, nessa ordem, inclusive quando alguma fica vazia
/// em treino curto (regra 11.1). A ordem dos casos É a ordem de exibição e a
/// ordem gravada em `secao_treino.ordem`, de 1 a 4.
enum TipoSecao: String, Codable, CaseIterable, Sendable {
    case aquecimento
    case progressao
    case principal
    case soltura

    /// `secao_treino.ordem`, de 1 a 4, única por treino (spec 7.5 e 7.11).
    var ordem: Int {
        switch self {
        case .aquecimento: 1
        case .progressao: 2
        case .principal: 3
        case .soltura: 4
        }
    }
}

/// Como uma sessão de natação terminou (spec 7.9, enum `motivo_encerramento`).
///
/// Nulo enquanto a sessão está em andamento. Os quatro casos são os quatro
/// finais da máquina de estados 12.2.
enum MotivoEncerramento: String, Codable, CaseIterable, Sendable {
    /// Nadou o treino inteiro até a última série da última seção.
    case concluido
    /// Encerrou antes do planejado. **Não é erro** e não gera mensagem de
    /// falha — o `HKWorkout` grava a distância real (regra 11.10).
    case encerrado_antes
    /// Menos de 25 m nadados: nada é gravado no HealthKit, para não poluir o
    /// histórico de saúde com toque acidental (regra 11.11, assunção 24.4).
    case descartado_curto
    /// A gravação do `HKWorkout` falhou. A sessão fica no relógio com
    /// `healthkit_workout_uuid = nil` e o usuário é avisado — nunca falha
    /// silenciosa (critério 8.9, copy 15.13).
    case falhou
}

extension MotivoEncerramento {

    /// Decide por que a sessão terminou (critério 8.9, regras 11.10 e 11.11).
    ///
    /// Recebe: a distância **real** medida pelo HealthKit e se o treino chegou
    /// ao fim do plano.
    /// Devolve: o motivo a gravar em `sessao_natacao.motivo_encerramento`.
    ///
    /// **É função pura**, para a decisão poder ser testada sem piscina e sem
    /// HealthKit. A ordem das checagens importa:
    ///
    /// 1. **Curto demais vence tudo** (regra 11.11): abaixo de 25 m nada é
    ///    gravado no app Saúde, mesmo que o treino tivesse acabado. Um toque
    ///    acidental que iniciou e encerrou a sessão não pode virar registro de
    ///    saúde.
    /// 2. Chegou ao fim do plano: `concluido`.
    /// 3. Parou antes: `encerrado_antes`. **Não é erro** e não gera mensagem de
    ///    falha (regra 11.10) — parar antes é decisão do nadador.
    ///
    /// `falhou` não sai daqui: ele é consequência de a gravação no HealthKit dar
    /// errado, e só quem tentou gravar sabe disso.
    static func decidir(distanciaRealM: Int, treinoConcluido: Bool) -> MotivoEncerramento {
        if distanciaRealM < SessaoNatacao.distanciaMinimaParaGravar {
            return .descartado_curto
        }
        return treinoConcluido ? .concluido : .encerrado_antes
    }

    /// A sessão deve virar um `HKWorkout`? (regra 11.11)
    ///
    /// Só `descartado_curto` não vira. `falhou` **tentou** e não conseguiu.
    var deveGravarNoHealthKit: Bool {
        self != .descartado_curto
    }
}
