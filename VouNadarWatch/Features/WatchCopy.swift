import Foundation

/// A copy do app do relógio (requisito 17.11: zero string em `View`).
///
/// Separada da copy do iPhone de propósito: o relógio tem telas próprias,
/// vocabulário mais curto e um `Localizable.xcstrings` no bundle dele. Repetir
/// as chaves do iPhone aqui seria acoplar dois catálogos que evoluem separados.
enum WatchCopy {

    // MARK: - W1 Início

    static let appNome = LocalizedStringResource("Vou Nadar")
    static let inicioEstaSemana = LocalizedStringResource("Esta semana")
    static let inicioGerarTreino = LocalizedStringResource("Gerar treino")
    static let inicioFavoritos = LocalizedStringResource("Favoritos")

    // MARK: - W2 Gerar

    static let gerarTitulo = LocalizedStringResource("Gerar")
    static let unidadeMetros = LocalizedStringResource("m")

    /// Rodapé que ensina o gesto, porque a faixa é ajustada pela coroa e não por
    /// arraste — e ninguém descobre isso sozinho.
    static let gerarAjudaDaCoroa = LocalizedStringResource("Gire a coroa para ajustar")

    // MARK: - W3 Favoritos

    static let favoritosTitulo = LocalizedStringResource("Favoritos")

    /// Copy 15.4, literal. As duas linhas viram título e corpo.
    static let favoritosVazioTitulo = LocalizedStringResource("Nenhum treino salvo.")
    static let favoritosVazioCorpo = LocalizedStringResource(
        "Favorite um treino no iPhone e ele aparece aqui.")

    // MARK: - W4 Pré-visualização

    /// Copy 15.6 — a linha da piscina, destacada e tocável (mitigação do risco R1).
    static func raiaDe(_ metros: Int) -> LocalizedStringResource {
        LocalizedStringResource("Raia de \(metros) m")
    }

    static let previaTrocar = LocalizedStringResource("Trocar")
    static let previaIniciar = LocalizedStringResource("Iniciar")

    // MARK: - W5 Piscina

    /// Copy 15.3 — o mesmo título do iPhone.
    static let piscinaTitulo = LocalizedStringResource("Tamanho da piscina")
    static let piscinaAtalho25 = LocalizedStringResource("25 m")
    static let piscinaAtalho50 = LocalizedStringResource("50 m")
    static let piscinaOutro = LocalizedStringResource("Outro")

    /// Rodapé do valor livre: a faixa e o gesto, em uma linha.
    static let piscinaAjudaDaCoroa = LocalizedStringResource("10 a 50 · coroa")

    static let acaoConfirmar = LocalizedStringResource("Confirmar")

    // MARK: - Execução guiada (W6 a W11)

    /// Copy 15.7 — o rótulo da contagem de descanso.
    static let execucaoDescanso = LocalizedStringResource("DESCANSO")

    /// O "de 4" de "3 de 4".
    static func execucaoDeTotal(_ total: Int) -> LocalizedStringResource {
        LocalizedStringResource("de \(total)")
    }

    static let execucaoConcluido = LocalizedStringResource("Treino concluído")
    static let execucaoRetomar = LocalizedStringResource("Retomar")
    static let execucaoPularSerie = LocalizedStringResource("Pular série")
    static let execucaoEncerrar = LocalizedStringResource("Encerrar")

    /// Copy 15.11 — sem autorização do app Saúde.
    static let execucaoSemAutorizacao = LocalizedStringResource(
        "O Vou Nadar precisa do app Saúde para contar as voltas. Sem isso, o treino não avança sozinho."
    )

    /// O caminho para conceder a autorização.
    ///
    /// **Não vem da seção 15**: o critério 8.8 exige "oferece abrir os Ajustes",
    /// e no watchOS não há como abrir os Ajustes de Saúde de outro app por URL —
    /// a permissão de HealthKit se concede **no iPhone**. Dizer isso é o caminho
    /// verdadeiro; um botão que não leva a lugar nenhum seria pior que nada.
    static let execucaoComoAutorizar = LocalizedStringResource(
        "Autorize no app Saúde do iPhone.")

    /// Copy 15.9 — falha ao iniciar.
    static let execucaoFalhaAoIniciar = LocalizedStringResource(
        "Não foi possível iniciar o treino. Tente de novo.")

    // MARK: - W10 Resumo (épico 8.9)

    /// Copy 15.8 — encerrado antes do planejado. **Não é mensagem de erro**:
    /// parar antes é decisão do nadador (regra 11.10).
    static func resumoRealDePlanejado(real: Int, planejado: Int) -> LocalizedStringResource {
        LocalizedStringResource("\(real) m de \(planejado) m")
    }

    /// Copy 15.12 — descartado por ser curto demais (regra 11.11).
    static let resumoMuitoCurto = LocalizedStringResource("Treino muito curto. Nada foi salvo.")

    /// Copy 15.13 — a gravação no app Saúde falhou. **Nunca falha silenciosa.**
    static let resumoFalhaAoSalvar = LocalizedStringResource(
        "O treino não foi salvo no app Saúde. Os dados ficaram no relógio.")

    static let resumoSeries = LocalizedStringResource("séries")
    static let resumoTempo = LocalizedStringResource("tempo")

    // MARK: - Compra (épico 8.11)

    static let compraTitulo = LocalizedStringResource("Treinos guiados")

    /// A compra acontece no iPhone: o watchOS não tem tela de compra decente, e
    /// mandar o nadador comprar de pulso molhado na borda seria pior ainda.
    static let compraCorpo = LocalizedStringResource(
        "Os treinos guiados grátis acabaram. Continue no app do iPhone.")

    static let acaoConcluir = LocalizedStringResource("Concluir")
    static let acaoVoltar = LocalizedStringResource("Voltar")

    // MARK: - Equipamento

    /// Os quatro nomes vêm do catálogo (`tipos_equipamento.json`), não daqui.
    static let equipamentoTitulo = LocalizedStringResource("Equipamento")
}

/// Formatação de número no relógio.
///
/// Mesma regra do iPhone: separador de milhar em ponto, padrão pt-BR.
enum WatchFormato {

    static func metros(_ valor: Int) -> String {
        valor.formatted(.number.grouping(.automatic).locale(Locale(identifier: "pt_BR")))
    }

    /// A faixa como a tela Gerar a mostra: `1.400–2.200`.
    ///
    /// **Sem espaço em volta do travessão**, ao contrário do iPhone: a tela do
    /// relógio é estreita e cada caractere conta.
    static func faixa(minM: Int, maxM: Int) -> String {
        minM == maxM ? metros(minM) : "\(metros(minM))\u{2013}\(metros(maxM))"
    }

    /// O resumo de séries da pré-visualização: `300 · 6×50 · 4×100 · 200`.
    ///
    /// Dá ao nadador a forma do treino numa linha, antes de entrar na água. As
    /// séries de uma repetição só aparecem como a distância pura — `300`, não
    /// `1×300` —, que é como treinador escreve.
    static func resumoDeSeries(_ treino: Treino) -> String {
        treino.secoesOrdenadas
            .flatMap(\.seriesOrdenadas)
            .map { serie in
                serie.repeticoes == 1
                    ? "\(serie.distanciaM)"
                    : "\(serie.repeticoes)\u{00D7}\(serie.distanciaM)"
            }
            .joined(separator: " \u{00B7} ")
    }
}
