import Foundation

/// Converte distância acumulada em voltas contabilizadas (regra 11.7).
///
/// **É função pura**, sem HealthKit: recebe metros, devolve quantas voltas novas
/// fecharam. É o que permite testar a contagem "com distâncias simuladas, sem
/// HealthKit real" (seção 22).
///
/// ## Por que a distância, e não o evento de volta
///
/// O HealthKit emite `HKWorkoutEvent` do tipo `.lap` em piscina, mas o **atraso
/// desses eventos é o risco R3 do spec** — o mais provável de todos. A distância
/// acumulada de `.distanceSwimming` é atualizada com a mesma detecção de virada,
/// chega em amostras mais frequentes, e é monotônica.
///
/// Usar a distância também dá uma propriedade que o evento não dá: se duas
/// voltas chegarem juntas, depois de uma amostragem atrasada, **as duas são
/// contabilizadas**. Com eventos discretos, uma perdida é uma perdida para
/// sempre, e a repetição terminaria uma volta atrasada até o fim do treino.
///
/// ## O que ele não resolve
///
/// O atraso em si. Se o HealthKit demorar 4 segundos para reportar a virada, o
/// descanso começa 4 segundos atrasado — é o que a regra 11.8 aceita
/// explicitamente e o que o requisito 17.4 limita em 5 segundos. **Não há
/// conserto no app**: a informação simplesmente não existe antes disso.
struct LapCounter: Equatable {

    /// O comprimento da raia, em metros. Congelado no treino (spec 7.4).
    let tamanhoRaiaM: Int

    /// Quantas voltas já foram reportadas para o motor.
    private(set) var voltasContabilizadas = 0

    /// A maior distância já vista, em metros.
    ///
    /// Guardada porque a distância do HealthKit **pode regredir** entre
    /// amostras, por correção da própria detecção. Regressão nunca desconta
    /// volta: uma repetição não "desacontece", e desfazer um avanço no meio de
    /// um treino confundiria o nadador sem nenhum ganho.
    private(set) var maiorDistanciaM: Double = 0

    init(tamanhoRaiaM: Int) {
        // Uma raia de zero dividiria por zero a cada amostra. A validação de
        // 10 a 50 é do repositório (spec 7.11); aqui é só a defesa final.
        self.tamanhoRaiaM = max(1, tamanhoRaiaM)
    }

    /// Registra a distância acumulada e devolve quantas voltas **novas**
    /// fecharam.
    ///
    /// Recebe: a distância total da sessão, em metros, como o HealthKit reporta.
    /// Devolve: 0 ou mais voltas a entregar ao motor de execução, uma a uma.
    mutating func registrar(distanciaTotalM: Double) -> Int {
        maiorDistanciaM = max(maiorDistanciaM, distanciaTotalM)

        let voltasFechadas = Int(maiorDistanciaM / Double(tamanhoRaiaM))
        guard voltasFechadas > voltasContabilizadas else { return 0 }

        let novas = voltasFechadas - voltasContabilizadas
        voltasContabilizadas = voltasFechadas
        return novas
    }
}
