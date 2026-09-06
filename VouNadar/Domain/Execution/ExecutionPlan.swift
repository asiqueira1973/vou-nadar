import Foundation

/// O treino achatado numa sequência linear de séries, pronto para executar
/// (épico 8.8).
///
/// **É tipo puro**, sem HealthKit e sem SwiftData: é o que permite testar a
/// contagem de voltas com distâncias simuladas, como a seção 22 exige.
///
/// ## Por que achatar
///
/// Na água não existe "seção": existe a série de agora e a próxima. As quatro
/// seções da regra 11.1 são estrutura de **montagem** e de **leitura**, não de
/// execução. Achatar aqui, uma vez, evita que o motor de execução tenha de
/// atravessar duas dimensões a cada volta contada — e evita o bug clássico de
/// avançar de seção esquecendo a série.
///
/// A seção continua junto de cada série, porque a tela mostra em que parte do
/// treino o nadador está.
struct ExecutionPlan: Sendable, Equatable {

    /// Todas as séries, na ordem de execução. **Séries de seções vazias
    /// simplesmente não estão aqui** (regra 11.1: a seção existe, mas sem série
    /// não há nada a executar).
    let series: [SeriePlanejada]

    /// A raia para a qual o treino foi montado, congelada na geração (spec 7.4).
    ///
    /// **É esta que vale, não a das preferências.** Se o nadador trocou a
    /// piscina nos Ajustes depois de favoritar, o treino salvo continua sendo
    /// para a piscina de origem — recalcular aqui violaria o princípio 0.6.
    let tamanhoRaiaM: Int

    var estaVazio: Bool { series.isEmpty }

    /// Quantas voltas o treino inteiro exige.
    var voltasTotais: Int {
        series.reduce(0) { $0 + $1.repeticoes * $1.voltasPorRepeticao }
    }

    /// A distância planejada, em metros.
    var distanciaPlanejadaM: Int {
        series.reduce(0) { $0 + $1.repeticoes * $1.distanciaM }
    }

    struct SeriePlanejada: Sendable, Equatable {

        /// Posição na sequência linear, de 0 em diante.
        let indice: Int

        /// A seção de origem. Só para a tela dizer onde o nadador está.
        let secao: TipoSecao

        /// Nome exibido, **sem o prefixo de metragem** do catálogo — a tela do
        /// relógio já mostra `4×100` do lado.
        let nome: String

        let repeticoes: Int

        /// Distância real por repetição, já adaptada à raia (regra 11.3).
        let distanciaM: Int

        /// **O contador que encerra a repetição** (regras 11.3 e 11.7).
        /// Congelado na geração; nunca recalculado aqui.
        let voltasPorRepeticao: Int

        /// Descanso ENTRE as repetições desta série, em segundos (regra 11.5).
        /// Zero quando há uma repetição só.
        let descansoSeg: Int

        /// Descanso DEPOIS desta série, em segundos (regra 11.6).
        ///
        /// Já resolve a distinção da regra: é o `descanso_pos_serie_seg` no meio
        /// da seção e o `descanso_pos_secao_seg` na última série dela. **Os dois
        /// nunca se somam**, e resolver isso aqui, na montagem do plano, evita
        /// que o motor de execução tenha de saber dessa regra.
        let descansoDepoisSeg: Int

        /// Voltas que esta série inteira exige.
        var voltasTotais: Int { repeticoes * voltasPorRepeticao }
    }
}

extension ExecutionPlan {

    /// Monta o plano a partir de um treino salvo (épico 8.8).
    ///
    /// **Nada é recalculado**: descanso, distância e voltas vêm dos snapshots
    /// gravados na geração (princípio 0.6). A única coisa que este método
    /// decide é qual dos dois descansos vale depois de cada série — e isso é
    /// leitura da regra 11.6, não recálculo.
    init(treino: Treino) {
        var series: [SeriePlanejada] = []
        var indice = 0

        for secao in treino.secoesOrdenadas {
            let daSecao = secao.seriesOrdenadas
            for (posicao, serie) in daSecao.enumerated() {
                let ehUltimaDaSecao = posicao == daSecao.count - 1
                series.append(
                    SeriePlanejada(
                        indice: indice,
                        secao: secao.tipoSecao,
                        nome: ExerciseName.semPrefixoDeSerie(serie.nomeSnapshot),
                        repeticoes: serie.repeticoes,
                        distanciaM: serie.distanciaM,
                        voltasPorRepeticao: serie.voltasPorRepeticao,
                        descansoSeg: serie.descansoSeg,
                        // Regra 11.6: no meio da seção vale o descanso de série;
                        // na última, o de seção.
                        descansoDepoisSeg: ehUltimaDaSecao
                            ? secao.descansoPosSecaoSeg : serie.descansoPosSerieSeg))
                indice += 1
            }
        }

        self.init(series: series, tamanhoRaiaM: treino.tamanhoRaiaM)
    }
}
