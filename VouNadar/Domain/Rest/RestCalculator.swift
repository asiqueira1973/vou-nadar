import Foundation

/// A tabela de descanso (regras 11.5 e 11.6) — contrato 13.2.
///
/// Recebe: a distância de uma repetição, a intensidade, o modo e o ritmo global.
/// Devolve: o descanso em segundos, entre 10 e 90.
///
/// **É função pura**: sem estado, sem `MainActor`, sem acesso a disco, sem
/// relógio, sem aleatoriedade. É essa disciplina que permite varrer os 226
/// exercícios nos três ritmos num teste (critério 8.2), e é por isso que a
/// regra 11.5 vive aqui e não espalhada pela interface.
///
/// **O resultado é snapshot, não cálculo de leitura.** O gerador chama isto uma
/// vez, na geração, e grava o número em `serie_treino.descanso_seg`. A tela
/// nunca recalcula: um treino favoritado hoje tem que abrir com os mesmos
/// descansos daqui a dois anos, mesmo que esta tabela mude numa release
/// (princípio 0.6 e decisão 4.3).
///
/// Por que descanso fixo e não intervalo de saída: o nadador amador não sabe o
/// próprio pace. "Descanse 30s" ele executa; "saia a cada 1:45" ele não sabe se
/// é fácil ou impossível. Intervalo de saída é v2 (roadmap 28.1).
enum RestCalculator {

    // MARK: - Contrato 13.2

    /// Descanso **entre as repetições** de uma série, em segundos (regra 11.5).
    ///
    /// Recebe: `distanciaM` — a distância de UMA repetição, já adaptada à raia
    /// (regra 11.3) —, a intensidade e o modo do exercício, e o ritmo global de
    /// `preferencias.ritmo_descanso`.
    /// Devolve: o descanso arredondado para o múltiplo de 5 mais próximo e
    /// limitado a 10–90 segundos.
    ///
    /// A fórmula é literal:
    /// `base(distancia_m) × mult(intensidade) × mult(modo) × mult(ritmo)`.
    static func descansoSegundos(
        distanciaM: Int,
        intensidade: Intensidade,
        modo: ModoExercicio,
        ritmo: RitmoDescanso
    ) -> Int {
        let bruto =
            Double(base(distanciaM: distanciaM))
            * multiplicador(intensidade: intensidade)
            * multiplicador(modo: modo)
            * ritmo.multiplicador
        return limitar(arredondarParaMultiploDeCinco(bruto))
    }

    // MARK: - Regra 11.6

    /// Descanso entre uma série e a próxima da **mesma seção**, em segundos
    /// (regra 11.6).
    ///
    /// São 30 s ajustados pelo ritmo global, arredondados para múltiplo de 5:
    /// 25 s no curto, 30 s no normal, 45 s no longo.
    ///
    /// **Zero na última série da seção** — ali vale o descanso de seção. Quem
    /// aplica essa exceção é o gerador, não esta função: aqui só existe o valor
    /// nominal.
    static func descansoEntreSeries(ritmo: RitmoDescanso) -> Int {
        arredondarParaMultiploDeCinco(baseEntreSeries * ritmo.multiplicador)
    }

    /// Descanso entre uma seção e a próxima, em segundos (regra 11.6).
    ///
    /// São 45 s ajustados pelo ritmo global, arredondados para múltiplo de 5:
    /// 35 s no curto, 45 s no normal, 70 s no longo.
    ///
    /// **Zero na última seção** — ali o treino acabou. A exceção é do gerador.
    static func descansoEntreSecoes(ritmo: RitmoDescanso) -> Int {
        arredondarParaMultiploDeCinco(baseEntreSecoes * ritmo.multiplicador)
    }

    // MARK: - A tabela da regra 11.5

    /// Base por distância da repetição, em segundos (tabela da regra 11.5).
    ///
    /// As oito linhas são exatamente as da tabela, e as distâncias delas são
    /// exatamente as distâncias que o catálogo usa.
    static let tabelaDeBase: [(distanciaM: Int, baseSeg: Int)] = [
        (25, 15),
        (50, 20),
        (75, 25),
        (100, 30),
        (150, 40),
        (200, 45),
        (250, 50),
        (300, 60),
    ]

    /// Descanso nominal entre séries, antes do ritmo (regra 11.6, assunção 24.6).
    static let baseEntreSeries = 30.0

    /// Descanso nominal entre seções, antes do ritmo (regra 11.6, assunção 24.6).
    static let baseEntreSecoes = 45.0

    /// Piso e teto do descanso entre repetições (regra 11.5).
    static let limites = 10...90

    /// A base da tabela para uma distância qualquer (regra 11.5).
    ///
    /// Recebe: a distância de uma repetição, em metros.
    /// Devolve: a base em segundos da **linha mais próxima** da tabela; 60 s
    /// para 300 m ou mais.
    ///
    /// **Por que "linha mais próxima" e não interpolação nem degrau.** A tabela
    /// da 11.5 é discreta e as distâncias dela são as do catálogo, mas a regra
    /// 11.3 adapta a distância à raia: numa piscina de 16 m um `4×100` vira
    /// `4×96`, e 96 não é linha da tabela. Foi preciso escolher como ler a
    /// tabela fora das linhas dela, e a escolha foi verificada contra o
    /// catálogo real, não estimada:
    ///
    /// varrendo os 226 exercícios nas oito piscinas da tabela de 11.3 detalhado,
    /// **a linha mais próxima da distância adaptada é sempre a mesma linha da
    /// distância do catálogo — zero divergências**. Não é coincidência: a guarda
    /// de desvio de 25% (assunção 24.3b) tira do sorteio justamente os
    /// exercícios que a adaptação empurraria para outra faixa. O degrau ("maior
    /// linha ≤ distância") divergiria em até 106 dos 205 exercícios em raia de
    /// 16 m, sempre para menos descanso.
    ///
    /// A consequência é que os números verificados na 11.5 e a amplitude de
    /// 10–75 s no ritmo normal valem igual em qualquer piscina suportada. O
    /// teste `descansoNaoMudaComAAdaptacaoDaRaia` prende essa propriedade: se um
    /// catálogo futuro quebrá-la, ele reprova em vez de mudar o descanso de todo
    /// mundo em silêncio.
    ///
    /// Empate — 125 m fica a 25 m de 100 e de 150 — resolve para a linha
    /// **maior**, isto é, mais descanso. Distância maior com descanso a menos é
    /// o erro que machuca o nadador; o contrário só o deixa esperando.
    static func base(distanciaM: Int) -> Int {
        // "300 ou mais" é a última linha da tabela, e é aberta à direita: o
        // catálogo vai até 1500 m por repetição.
        if let ultima = tabelaDeBase.last, distanciaM >= ultima.distanciaM {
            return ultima.baseSeg
        }
        let maisProxima = tabelaDeBase.min { a, b in
            let distA = abs(a.distanciaM - distanciaM)
            let distB = abs(b.distanciaM - distanciaM)
            // Empate resolve para a linha de distância maior.
            return distA == distB ? a.distanciaM > b.distanciaM : distA < distB
        }
        return maisProxima?.baseSeg ?? tabelaDeBase[0].baseSeg
    }

    /// Multiplicador por intensidade (regra 11.5).
    ///
    /// `aquecimento` e `soltura` pedem menos descanso porque o esforço é menor;
    /// `resistencia` pede mais porque é o bloco que cansa.
    static func multiplicador(intensidade: Intensidade) -> Double {
        switch intensidade {
        case .aquecimento, .soltura: 0.75
        case .moderado, .aerobico, .variavel: 1.0
        case .resistencia: 1.25
        }
    }

    /// Multiplicador por modo (regra 11.5).
    ///
    /// `educativo` é técnica em ritmo baixo e pede menos; `pernada` isola a
    /// musculatura maior do corpo e pede mais.
    static func multiplicador(modo: ModoExercicio) -> Double {
        switch modo {
        case .nado, .bracada: 1.0
        case .educativo: 0.75
        case .pernada: 1.25
        }
    }

    // MARK: - Arredondamento e limites

    /// Arredonda para o múltiplo de 5 mais próximo (regra 11.5).
    ///
    /// Meio para cima — `.toNearestOrAwayFromZero`, o padrão de `.rounded()` —
    /// e não arredondamento bancário: 37,5 tem que virar 40, como o exemplo
    /// `3×100 resistência/nado` da tabela da 11.5 exige. O bancário devolveria
    /// 35.
    static func arredondarParaMultiploDeCinco(_ valor: Double) -> Int {
        Int((valor / 5).rounded()) * 5
    }

    /// Aplica o piso de 10 s e o teto de 90 s (regra 11.5).
    ///
    /// O piso existe porque um educativo curto no ritmo curto cairia para 5 s,
    /// que não é descanso — é uma pausa para respirar. O teto existe para o
    /// ritmo longo num bloco de 300 m ou mais não parar o treino por um minuto
    /// e meio sem limite.
    static func limitar(_ segundos: Int) -> Int {
        min(max(segundos, limites.lowerBound), limites.upperBound)
    }
}
