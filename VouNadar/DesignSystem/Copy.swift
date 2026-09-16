import Foundation

/// Toda a copy da interface do iPhone, num lugar só.
///
/// O requisito 17.11 exige **zero string em `View`**: nenhuma View escreve
/// texto literal, e por isso o app já nasce pronto para tradução mesmo com o
/// inglês descartado no v1 (spec 3.2). O tipo é `LocalizedStringResource`, que
/// resolve pelo `Localizable.xcstrings` e mantém as chaves extraíveis.
///
/// Duas origens, marcadas caso a caso abaixo:
/// - **seção 15 do spec** — texto final, literal, não reescrever;
/// - **telas exportadas do Claude Design** — rótulos de estrutura que a seção
///   15 não fixa. Onde a tela e o design system discordarem, o design system
///   vence; onde a tela e o spec discordarem sobre comportamento, o spec vence.
enum Copy {

    // MARK: - Navegação e telas

    /// Título da Home e nome do app.
    static let appNome = LocalizedStringResource("Vou Nadar")

    /// As três abas da `TabView` (DESIGN-SYSTEM.md seção 3).
    static let abaTreino = LocalizedStringResource("Treino")
    static let abaFavoritos = LocalizedStringResource("Favoritos")
    static let abaHistorico = LocalizedStringResource("Histórico")

    /// Ajustes é uma engrenagem na barra de navegação da Home, **não uma aba**.
    static let ajustes = LocalizedStringResource("Ajustes")

    // MARK: - P1 Home

    /// Header da Section da faixa de distância. **Title Case** (guardrail 6).
    static let homeSecaoDistancia = LocalizedStringResource("Distância")

    /// Rótulo da linha de valor da faixa, um `LabeledContent`.
    static let homeFaixa = LocalizedStringResource("Faixa")

    static let homeSecaoEquipamento = LocalizedStringResource("Equipamento na mochila")

    static let homeIncluirEducativos = LocalizedStringResource("Incluir educativos")
    static let homeIncluirEducativosNota = LocalizedStringResource(
        "Um bloco de técnica no aquecimento")

    static let homeIncluirPernada = LocalizedStringResource("Incluir pernada")
    static let homeIncluirPernadaNota = LocalizedStringResource(
        "Um bloco de perna na parte principal")

    /// Copy 15.1 — botão principal.
    static let homeBotaoGerar = LocalizedStringResource("Gerar treino")

    /// Copy 15.2 — motivo do botão desabilitado, acima dele, em `.footnote`
    /// (regra 11.4 e critério 8.3.1).
    static let homeBloqueadoSemPiscina = LocalizedStringResource(
        "Configure o tamanho da piscina para gerar treinos.")

    /// Copy 15.17 — aviso de repertório curto (regra 11.19). Nunca bloqueia a
    /// geração: treino repetitivo é melhor que treino nenhum.
    static let homeRepertorioCurto = LocalizedStringResource(
        "Com essa piscina e esses filtros sobram poucos exercícios, então os treinos vão se repetir. Marcar mais equipamento ajuda."
    )

    // MARK: - P6 Piscina

    /// Copy 15.3 — título da tela, nos dois aparelhos.
    static let piscinaTitulo = LocalizedStringResource("Tamanho da piscina")

    /// Os dois atalhos (critério 8.3).
    static let piscinaAtalho25 = LocalizedStringResource("25 m")
    static let piscinaAtalho50 = LocalizedStringResource("50 m")

    static let piscinaOutro = LocalizedStringResource("Outro")

    /// Rótulo do `Stepper` de 10 a 50 (assunção 24.3).
    static let piscinaMetros = LocalizedStringResource("Metros")

    /// Footer da Section, explicando por que a faixa é tão larga.
    static let piscinaRodape = LocalizedStringResource(
        "Piscina de condomínio e academia costuma ter 12, 15, 16, 18 ou 20 metros.")

    /// Botão da barra inferior na primeira abertura, quando a tela é
    /// obrigatória e não tem botão voltar.
    static let piscinaContinuar = LocalizedStringResource("Continuar")

    // MARK: - P5 Ajustes

    static let ajustesSecaoPiscina = LocalizedStringResource("Piscina")
    static let ajustesSecaoDescanso = LocalizedStringResource("Descanso")
    static let ajustesSecaoEquipamento = LocalizedStringResource("Equipamento")

    static let ritmoCurto = LocalizedStringResource("Curto")
    static let ritmoNormal = LocalizedStringResource("Normal")
    static let ritmoLongo = LocalizedStringResource("Longo")

    /// Copy 15.5 — footer da Section de descanso, explicando o efeito em uma
    /// frase na própria tela (critério 8.3.5).
    static let ajustesDescansoExplicacao = LocalizedStringResource(
        "Ajusta o descanso de todo o treino. Curto para quem já tem fôlego, longo para quem está voltando."
    )

    // MARK: - P2 Detalhe do treino

    /// Unidade ao lado do numeral herói, em `.title3`.
    static let unidadeMetros = LocalizedStringResource("m")

    /// A contagem de travessias como a linha sob a metragem a mostra:
    /// `"1 chegada"`, `"4 chegadas"`, `"3 piscinas"`.
    ///
    /// Recebe: a contagem já decidida por `LapDisplay`.
    /// Devolve: o texto pronto, com singular e plural corretos — `2×54` em raia
    /// de 18 m tem três travessias e vira `"3 piscinas"`, e um `50 m` em raia de
    /// 25 m tem duas e vira `"1 chegada"`, que é o caso mais comum do catálogo.
    ///
    /// Singular e plural resolvidos aqui, e não por regra de plural do String
    /// Catalog, porque o app é só pt-BR (o inglês está fora do v1) e são quatro
    /// formas fixas — infraestrutura de pluralização aqui seria cerimônia sem
    /// uso.
    static func travessias(_ contagem: LapDisplay.Contagem) -> LocalizedStringResource {
        switch contagem {
        case .chegadas(let quantas):
            quantas == 1
                ? LocalizedStringResource("1 chegada")
                : LocalizedStringResource("\(quantas) chegadas")
        case .piscinas(let quantas):
            quantas == 1
                ? LocalizedStringResource("1 piscina")
                : LocalizedStringResource("\(quantas) piscinas")
        }
    }

    /// Rótulo sob o herói.
    static let heroiTotal = LocalizedStringResource("Total")

    /// Título provisório de treino não favoritado (regra 11.14).
    static func detalheTituloProvisorio(_ data: Date) -> LocalizedStringResource {
        LocalizedStringResource("Treino de \(data.formatted(date: .numeric, time: .omitted))")
    }

    /// Contador de execuções na linha do herói (regra 11.13).
    static func heroiFeitoVezes(_ vezes: Int) -> LocalizedStringResource {
        vezes == 1
            ? LocalizedStringResource("Feito 1 vez")
            : LocalizedStringResource("Feito \(vezes) vezes")
    }

    /// Copy 15.18 — a nota sob o herói, só quando a adaptação à raia mexeu em
    /// alguma série (regra 11.3, risco R2b).
    static func detalheDistanciasAjustadas(_ raiaM: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "As distâncias foram ajustadas para fechar voltas inteiras na sua piscina de \(raiaM) m."
        )
    }

    /// Seção da regra 11.1 que ficou sem série em treino curto. **Nunca é
    /// escondida** — some o conteúdo, não o cabeçalho.
    static let detalheSecaoSemSerie = LocalizedStringResource("Nenhuma série nesta parte.")

    static let detalheGerarOutro = LocalizedStringResource("Gerar outro")

    /// Copy 15.20 — rótulo da ação de copiar.
    static let detalheCopiarComoTexto = LocalizedStringResource("Copiar como texto")

    /// Copy 15.19 — a confirmação, um toque depois.
    static let detalheTreinoCopiado = LocalizedStringResource("Treino copiado.")

    /// Favoritar exige título (regra 11.14).
    static let detalheFavoritar = LocalizedStringResource("Favoritar")
    static let detalheFavoritarTitulo = LocalizedStringResource("Nome do treino")
    static let detalheFavoritarCampo = LocalizedStringResource("Terça leve")
    static let detalheFavoritarAjuda = LocalizedStringResource("De 1 a 60 caracteres.")

    // MARK: - P3 Favoritos

    static let favoritosRenomear = LocalizedStringResource("Renomear")
    static let favoritosApagar = LocalizedStringResource("Apagar")

    // MARK: - Ações genéricas

    static let acaoCancelar = LocalizedStringResource("Cancelar")
    static let acaoSalvar = LocalizedStringResource("Salvar")

    // MARK: - Selo de modo da série (tela P2)

    // `nado` não ganha selo: é o caso comum, e marcar o comum é ruído.
    static let seloBracada = LocalizedStringResource("braçada")
    static let seloPernada = LocalizedStringResource("pernada")
    static let seloTecnica = LocalizedStringResource("técnica")

    // MARK: - P7 Paywall

    /// Copy 15.14 — título.
    static let paywallTitulo = LocalizedStringResource("Continue nadando com o Vou Nadar")

    /// Copy 15.15 — corpo. Cada frase responde a uma dúvida real de quem vai
    /// pagar: é recorrente? tem anúncio? vale nos meus outros aparelhos?
    static let paywallCorpo = LocalizedStringResource(
        "Compra única. Sem assinatura, sem mensalidade, sem anúncio. Vale para sempre, em todos os seus aparelhos."
    )

    /// O botão de compra, com o preço vindo da App Store — nunca escrito à mão.
    static func paywallComprarPor(_ preco: String) -> LocalizedStringResource {
        LocalizedStringResource("Comprar por \(preco)")
    }

    static let paywallRestaurar = LocalizedStringResource("Restaurar compra")
    static let paywallComprado = LocalizedStringResource("Compra restaurada.")
    static let paywallFalhaAoRestaurar = LocalizedStringResource(
        "Não encontramos uma compra nesta Apple Account.")

    /// Aviso na Home quando as execuções livres estão acabando (assunção 24.5).
    static func paywallExecucoesRestantes(_ quantas: Int) -> LocalizedStringResource {
        quantas == 1
            ? LocalizedStringResource("Resta 1 treino guiado grátis.")
            : LocalizedStringResource("Restam \(quantas) treinos guiados grátis.")
    }

    // MARK: - P5 Ajustes: Sobre e dados

    static let ajustesSecaoSobre = LocalizedStringResource("Sobre")
    static let ajustesVersaoDoApp = LocalizedStringResource("Versão do app")
    static let ajustesVersaoDoCatalogo = LocalizedStringResource("Versão do catálogo")
    static let ajustesPrivacidade = LocalizedStringResource("Política de Privacidade")
    static let ajustesSuporte = LocalizedStringResource("Suporte")

    static let ajustesComprar = LocalizedStringResource("Comprar o Vou Nadar completo")
    static let ajustesApagarDados = LocalizedStringResource("Apagar todos os dados")
    static let ajustesApagarRodape = LocalizedStringResource(
        "Pede confirmação em duas etapas.")
    static let ajustesApagarPrimeiraPergunta = LocalizedStringResource(
        "Apagar todos os treinos e preferências deste iPhone?")
    static let ajustesApagarSegundaPergunta = LocalizedStringResource(
        "Isto não pode ser desfeito. Seus treinos no app Saúde não são apagados.")
    static let ajustesApagarConfirmar = LocalizedStringResource("Apagar")

    // MARK: - Estados vazios

    /// Copy 15.16 — P3 sem nenhum favorito. As duas linhas da copy viram título
    /// e corpo do `ContentUnavailableView`. Sem botão: gerar é na aba Treino.
    static let favoritosVazioTitulo = LocalizedStringResource("Nenhum treino salvo ainda.")
    static let favoritosVazioCorpo = LocalizedStringResource(
        "Gere um treino e toque em Favoritar.")

    /// P4 sem nenhuma sessão (DESIGN-SYSTEM.md seção 6).
    static let historicoVazioTitulo = LocalizedStringResource("Nenhum treino registrado")
    static let historicoVazioCorpo = LocalizedStringResource(
        "Gere um treino, nade com o relógio, e o volume aparece aqui.")

    // MARK: - P4 Histórico

    static let historicoEstaSemana = LocalizedStringResource("Esta semana")
    static let historicoMediaSemanal = LocalizedStringResource("Média semanal")
    static let historicoTreinos = LocalizedStringResource("Treinos")
    static let historicoSecaoSessoes = LocalizedStringResource("Sessões")

    /// Selo de sessão gravada por outro app (critério 8.10).
    ///
    /// Não é demérito, é contexto: o HealthKit é do usuário, não do Vou Nadar.
    static let historicoForaDoApp = LocalizedStringResource("fora do app")

    static let historicoSemAutorizacaoTitulo = LocalizedStringResource(
        "Sem acesso ao app Saúde")
    static let historicoSemAutorizacaoCorpo = LocalizedStringResource(
        "O Vou Nadar precisa ler o app Saúde para mostrar o que você nadou. Nada é enviado para fora do seu aparelho."
    )
    static let historicoAbrirAjustes = LocalizedStringResource("Abrir Ajustes")

    // MARK: - Erros de validação (critério 8.3.2)

    static let erroRaiaForaDaFaixa = LocalizedStringResource(
        "A piscina precisa ter entre 10 e 50 metros.")
    static let erroFaixaInvertida = LocalizedStringResource(
        "A distância mínima não pode ser maior que a máxima.")

    /// Fecha um alerta que só informa, sem escolha a fazer.
    static let acaoEntendi = LocalizedStringResource("Entendi")

    // MARK: - Acessibilidade

    /// `accessibilityLabel` de todo botão só com símbolo (DESIGN-SYSTEM.md
    /// seção 9).
    static let a11yAbrirAjustes = LocalizedStringResource("Abrir ajustes")
    static let a11yFechar = LocalizedStringResource("Fechar")
    static let a11ySelecionado = LocalizedStringResource("Selecionado")

    /// Os dois puxadores do slider de intervalo, que sem rótulo próprio seriam
    /// dois círculos idênticos para o VoiceOver.
    static let a11yFaixaMinima = LocalizedStringResource("Distância mínima")
    static let a11yFaixaMaxima = LocalizedStringResource("Distância máxima")

    /// O menu da barra no Detalhe, que só tem símbolo.
    static let a11yMaisAcoes = LocalizedStringResource("Mais ações")

    // MARK: - Nomes das quatro seções do treino

    // Em **Title Case** na tela (guardrail 6). A caixa alta da regra 14.2.3
    // vale só para o texto copiado, onde não há tipografia.
    static let secaoAquecimento = LocalizedStringResource("Aquecimento")
    static let secaoProgressao = LocalizedStringResource("Progressão")
    static let secaoPrincipal = LocalizedStringResource("Parte principal")
    static let secaoSoltura = LocalizedStringResource("Soltura")
}

/// Formatação de número no padrão pt-BR.
///
/// O separador de milhar é ponto (regra 14.2.1), e o app inteiro depende disso
/// para os metros ficarem legíveis: `2.100 m`, não `2100 m`.
enum Formato {

    /// Formata metros com separador de milhar pt-BR: `2100` → `"2.100"`.
    ///
    /// Recebe: a distância em metros.
    /// Devolve: só o número, **sem** a unidade — quem monta a frase decide onde
    /// o "m" entra, porque no herói ele é um `Text` separado em `.title3`.
    static func metros(_ valor: Int) -> String {
        valor.formatted(.number.grouping(.automatic).locale(Locale(identifier: "pt_BR")))
    }

    /// Dia e mês curtos, para o eixo do gráfico: `08/09`.
    static func diaEMes(_ data: Date) -> String {
        data.formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(Locale(identifier: "pt_BR")))
    }

    /// Data por extenso e curta, para a lista de sessões.
    static func dataPorExtenso(_ data: Date) -> String {
        data.formatted(
            .dateTime.day().month(.abbreviated).hour().minute()
                .locale(Locale(identifier: "pt_BR")))
    }

    /// A faixa de distância como a linha de valor da Home a mostra:
    /// `"1.500 – 2.500 m"`. Com faixa fechada, mostra um número só: `"2.000 m"`
    /// (estado declarado na seção 6 do design system).
    static func faixa(minM: Int, maxM: Int) -> String {
        minM == maxM
            ? "\(metros(minM)) m"
            // Travessão de intervalo (en dash, U+2013), não hífen.
            : "\(metros(minM)) \u{2013} \(metros(maxM)) m"
    }
}
