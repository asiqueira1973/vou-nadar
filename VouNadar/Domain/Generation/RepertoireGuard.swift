import Foundation

/// O aviso de repertório curto (regra 11.19).
///
/// **É função pura**, sem estado e sem plataforma, para o mesmo cálculo servir
/// à Home do iPhone e à tela Gerar do relógio sem duplicação.
///
/// A regra: se a combinação de raia, equipamentos e interruptores deixar **menos
/// de 30 candidatos**, o app gera assim mesmo mas avisa uma vez, dizendo o que
/// reduziria o problema. **Nunca bloqueia a geração** — treino repetitivo é
/// melhor que treino nenhum.
///
/// O caso que motiva a regra é concreto: em raia de 50 m saem 23 exercícios pela
/// guarda de desvio da 11.3, e **12 dos 32 educativos são blocos de 25 m**. Com
/// o interruptor de educativos ligado numa piscina olímpica, o repertório de
/// técnica encolhe para 20 e os treinos começam a se repetir (risco R2). Em
/// raia de 33 m o problema é maior: sobram 133 dos 226.
enum RepertoireGuard {

    /// Abaixo de quantos candidatos o aviso da copy 15.17 aparece (regra 11.19).
    static let minimoDeCandidatos = 30

    /// Quantos exercícios do catálogo podem ser sorteados com esta combinação
    /// (regra 11.19).
    ///
    /// Recebe: o catálogo, o comprimento da raia, os `equipamento_id` marcados e
    /// os dois interruptores.
    /// Devolve: a contagem de candidatos.
    ///
    /// Os quatro filtros são exatamente os quatro que a geração aplica antes de
    /// qualquer heurística de seção:
    /// 1. `ativo == true` — exercício desativado fica no arquivo e nunca é
    ///    sorteado;
    /// 2. sobrevive à adaptação à raia (regra 11.3);
    /// 3. o equipamento exigido é `nenhum` ou está marcado — **conjunto vazio é
    ///    estado válido**, e aí só entram os 168 sem equipamento;
    /// 4. o modo é permitido pelos interruptores.
    static func candidatos(
        catalogo: [ExercicioCatalogo],
        tamanhoRaiaM: Int,
        equipamentos: Set<String>,
        incluirEducativos: Bool,
        incluirPernada: Bool
    ) -> Int {
        catalogo.count { exercicio in
            exercicio.ativo
                && LaneAdapter.podeSerSorteado(exercicio, tamanhoRaiaM: tamanhoRaiaM)
                && equipamentoPermitido(exercicio, equipamentos)
                && modoPermitido(
                    exercicio, incluirEducativos: incluirEducativos,
                    incluirPernada: incluirPernada)
        }
    }

    /// O aviso da copy 15.17 deve aparecer? (regra 11.19)
    ///
    /// Devolve verdadeiro abaixo de 30 candidatos. **Nunca é motivo para
    /// desabilitar o botão Gerar** — o único bloqueio da Home é a piscina não
    /// confirmada (regra 11.4).
    static func deveAvisar(
        catalogo: [ExercicioCatalogo],
        tamanhoRaiaM: Int,
        equipamentos: Set<String>,
        incluirEducativos: Bool,
        incluirPernada: Bool
    ) -> Bool {
        candidatos(
            catalogo: catalogo, tamanhoRaiaM: tamanhoRaiaM, equipamentos: equipamentos,
            incluirEducativos: incluirEducativos, incluirPernada: incluirPernada)
            < minimoDeCandidatos
    }

    /// Equipamento aceito: `nenhum` ou um dos marcados na Home.
    ///
    /// **Conjunto vazio é estado válido e comum** — nadador sem equipamento
    /// nenhum —, e nesse caso só entram exercícios com `equipamento_exigido =
    /// nenhum`, que são 168 dos 226.
    static func equipamentoPermitido(
        _ exercicio: ExercicioCatalogo, _ selecionados: Set<String>
    ) -> Bool {
        exercicio.equipamento_exigido == "nenhum"
            || selecionados.contains(exercicio.equipamento_exigido)
    }

    /// Modo aceito pelos dois interruptores da Home.
    ///
    /// `nado` e `bracada` entram sempre — o filtro de equipamento já resolve o
    /// acesso à braçada. `educativo` e `pernada` só entram com o interruptor
    /// correspondente ligado.
    static func modoPermitido(
        _ exercicio: ExercicioCatalogo, incluirEducativos: Bool, incluirPernada: Bool
    ) -> Bool {
        switch exercicio.modo {
        case .nado, .bracada: true
        case .educativo: incluirEducativos
        case .pernada: incluirPernada
        }
    }
}
