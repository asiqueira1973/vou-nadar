import Foundation

/// Monta o treino como texto puro para a área de transferência (seção 14).
///
/// Recebe: um `WorkoutPresentation`.
/// Devolve: o texto exato da seção 14 — UTF-8, quebra de linha `\n`, **sem
/// emoji, sem markdown e sem URL**.
///
/// **É função pura.** O destino é uma caixa de mensagem do WhatsApp, onde
/// asterisco e cerquilha viram lixo visual ou formatação indesejada.
///
/// Esta é a **única saída do app**. Não há importação, e não há folha de
/// compartilhamento: imagem é território do Swim Builder e ficou fora daqui de
/// propósito (spec 3.2).
enum WorkoutTextExporter {

    /// Sinal de multiplicação U+00D7 — **não** a letra `x` (regra 14.2.5).
    static let sinalDeMultiplicacao = "\u{00D7}"

    /// Travessão U+2014, o separador da primeira linha e do descanso.
    static let travessao = "\u{2014}"

    /// Ponto médio U+00B7, o separador da segunda linha.
    static let pontoMedio = "\u{00B7}"

    /// Monta o texto completo (seção 14).
    ///
    /// A ordem é fixa: cabeçalho de duas linhas, linha em branco, e as seções
    /// que têm série, separadas por uma linha em branco cada. **Nenhuma linha em
    /// branco no fim** — o WhatsApp preserva e fica feio (regra 14.2.7).
    static func texto(de treino: WorkoutPresentation) -> String {
        var blocos: [String] = [cabecalho(de: treino)]

        for secao in treino.secoes {
            // Regra 14.2.4: seção vazia é omitida INTEIRA, cabeçalho incluído.
            guard !secao.estaVazia else { continue }
            var linhas = [tituloDeSecao(secao.tipo)]
            linhas.append(contentsOf: secao.series.map(linha(de:)))
            blocos.append(linhas.joined(separator: "\n"))
        }

        return blocos.joined(separator: "\n\n")
    }

    // MARK: - Cabeçalho

    /// As duas primeiras linhas (regras 14.2.1 e 14.2.2).
    private static func cabecalho(de treino: WorkoutPresentation) -> String {
        // 14.2.1 — o título quando existe, senão o nome do app. Separador de
        // milhar em ponto, padrão pt-BR.
        let nome = treino.titulo?.trimmingCharacters(in: .whitespacesAndNewlines)
        let primeiraParte = (nome?.isEmpty == false ? nome! : "Vou Nadar")
        let primeira =
            "\(primeiraParte) \(travessao) \(Formato.metros(treino.distanciaTotalM)) m"

        // 14.2.2 — a linha da piscina. Ela existe porque o treino só faz sentido
        // na piscina para a qual foi gerado (regra 11.3): quem recebe precisa
        // saber disso para não nadar outra coisa.
        let segunda =
            "Raia de \(treino.tamanhoRaiaM) m \(pontoMedio) descanso \(treino.ritmo.rawValue)"

        return "\(primeira)\n\(segunda)"
    }

    /// Cabeçalho de seção em **caixa alta**, sem acentuação alterada
    /// (regra 14.2.3).
    ///
    /// Aqui a caixa alta é correta e é a única exceção do app: é texto puro sem
    /// tipografia, e é o único recurso de hierarquia disponível. Na tela vale o
    /// contrário — Title Case, nunca caixa alta (guardrail 6 do design system).
    static func tituloDeSecao(_ tipo: TipoSecao) -> String {
        switch tipo {
        case .aquecimento: "AQUECIMENTO"
        case .progressao: "PROGRESSÃO"
        case .principal: "PARTE PRINCIPAL"
        case .soltura: "SOLTURA"
        }
    }

    // MARK: - Linha de série

    /// Uma linha de série (regras 14.2.5 e 14.2.6).
    ///
    /// `{repeticoes}×{distancia_m} {nome}`, e ` — {descanso}s` no fim quando há
    /// descanso interno. A distância é a **real, já adaptada à raia** — numa
    /// piscina de 16 m sai `4×96`, igual à tela.
    private static func linha(de serie: WorkoutPresentation.SerieApresentada) -> String {
        let base =
            "\(serie.repeticoes)\(sinalDeMultiplicacao)\(serie.distanciaM) "
            + ExerciseName.semPrefixoDeSerie(serie.nome)
        // Série de uma repetição só não tem descanso interno (spec 7.2), e a
        // regra 14.2.5 só acrescenta o sufixo quando `descanso_seg > 0`.
        guard serie.descansoSeg > 0 else { return base }
        return "\(base) \(travessao) \(serie.descansoSeg)s"
    }
}
