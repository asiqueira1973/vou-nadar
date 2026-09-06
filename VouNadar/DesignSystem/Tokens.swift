import SwiftUI

// Tokens de cor e tipografia do iPhone (DESIGN-SYSTEM.md seções 1, 2 e 5).
//
// Todo valor aqui é literal e vem do documento. Nenhum é escolhido no código:
// os hex vivem nos Color Sets do asset catalog, e este arquivo só dá nome a
// eles para que nenhuma View precise escrever `Color("...")` e errar a string.

extension Color {

    // MARK: - Superfícies

    /// Fundo de tela. **Nunca** em linha de lista nem em texto.
    static let fundoPrimario = Color("BackgroundPrimary")

    /// Fundo das linhas do `List`. Quem pinta é o `List`; não aplique
    /// manualmente, exceto no contêiner do gráfico do Histórico.
    static let superficieAgrupada = Color("SurfaceGrouped")

    /// Fundo do controle embutido do `Stepper` e da faixa de confirmação
    /// "Treino copiado.". **Nunca** como fundo de tela nem de linha comum.
    static let superficieElevada = Color("SurfaceElevated")

    // MARK: - Texto e traço

    /// Todo texto de conteúdo. **Nunca** sobre `destaque`.
    static let textoPrimario = Color("TextPrimary")

    /// Metragem, descanso, descrição, rótulo de número, selo de modo, footer de
    /// Section, texto de estado vazio. **Nunca** em título de tela.
    static let textoSecundario = Color("TextSecondary")

    /// Separador do `List`, borda do botão da barra inferior, barra vazia do
    /// gráfico. **Nunca** em texto.
    static let hairline = Color("Hairline")

    // MARK: - Marca

    /// O `.tint` do app: glyph da aba ativa, marcador de seleção, rótulo de
    /// botão, `Toggle` ligado, traço do gráfico, trilha preenchida do slider.
    ///
    /// **Nunca como fundo** de pílula, card, faixa larga ou bloco (guardrail 4).
    /// É `#0A7593` no tema claro e `#0E9BC4` no escuro, e a diferença não é
    /// estética: o azul de marca sobre branco dá 3,23:1 e reprova o critério de
    /// acessibilidade do app.
    ///
    /// Na prática quase nunca é preciso citar este token — o asset já é o
    /// accent color global do target, então `.tint` do sistema já o usa.
    static let destaque = Color("AccentTint")

    // MARK: - Semânticas, reservadas a significado

    /// **Apenas** o símbolo de confirmação de cópia.
    static let statusSucesso = Color("StatusSuccess")

    /// **Apenas** o símbolo e a moldura do aviso de repertório curto (11.19).
    static let statusAlerta = Color("StatusWarning")

    /// **Apenas** "Apagar todos os dados", a ação de swipe Apagar e o alerta de
    /// confirmação. **Nunca decorativo.**
    static let statusErro = Color("StatusError")
}

extension TipoSecao {

    /// A cor da seção, usada **apenas** no traço de 14 × 3 pt junto ao header
    /// da `Section` — nunca como fundo, faixa larga ou cor de texto
    /// (DESIGN-SYSTEM.md seção 1).
    var cor: Color {
        switch self {
        case .aquecimento: Color("SectionWarmup")
        case .progressao: Color("SectionProgression")
        case .principal: Color("SectionMain")
        case .soltura: Color("SectionCooldown")
        }
    }

    /// O header da `Section`, em **Title Case** — nunca caixa alta, nunca
    /// `letter-spacing` (guardrail 6).
    ///
    /// A caixa alta é correta só no texto copiado (regra 14.2.3), onde não há
    /// tipografia e ela é o único recurso de hierarquia disponível.
    var tituloNaTela: LocalizedStringResource {
        switch self {
        case .aquecimento: Copy.secaoAquecimento
        case .progressao: Copy.secaoProgressao
        case .principal: Copy.secaoPrincipal
        case .soltura: Copy.secaoSoltura
        }
    }
}

// MARK: - Medidas declaradas

/// As únicas medidas fixas permitidas no iPhone (DESIGN-SYSTEM.md seção 5).
///
/// Tudo o mais usa o padrão do sistema: padding do `List`, inset das linhas,
/// espaçamento entre Sections, área segura. **Não declare padding em linha de
/// lista** (guardrail 9) — as exceções são estas, e são poucas de propósito.
enum Medidas {

    /// Padding horizontal do numeral herói, um dos dois contêineres desenhados
    /// à mão que o design system permite.
    static let heroiPaddingHorizontal: CGFloat = 20

    /// Padding inferior do numeral herói.
    static let heroiPaddingInferior: CGFloat = 10

    /// Espaçamento interno do herói; 6 pt quando há a nota de ajuste da 15.18.
    static let heroiEspacamento: CGFloat = 2
    static let heroiEspacamentoComNota: CGFloat = 6

    /// O traço de cor ao lado do header da Section: 14 × 3 pt, canto 2 pt.
    static let tracoSecaoLargura: CGFloat = 14
    static let tracoSecaoAltura: CGFloat = 3
    static let tracoSecaoCanto: CGFloat = 2
    static let tracoSecaoEspacamento: CGFloat = 7

    /// Altura do gráfico de volume — o outro contêiner desenhado à mão.
    static let graficoAltura: CGFloat = 112
    static let graficoEspacamentoBarras: CGFloat = 6
    static let graficoCantoBarra: CGFloat = 2

    /// Espaçamento entre os números da semana no Histórico.
    static let numerosSemanaEspacamento: CGFloat = 26

    /// Padding vertical da barra inferior do botão primário.
    static let barraInferiorTopo: CGFloat = 10
    static let barraInferiorBase: CGFloat = 12

    /// **Um único raio de canto** em contêiner desenhado à mão (guardrail 3).
    /// O botão da barra inferior é `Capsule()`. Nenhum outro raio existe no app.
    static let canto: CGFloat = 12

    /// Área de toque mínima (DESIGN-SYSTEM.md seção 9).
    static let alvoDeToque: CGFloat = 44
}

// MARK: - Tipografia

extension Font {

    /// Distância total do herói: `.largeTitle` bold, SF Pro **Rounded**,
    /// dígitos monoespaçados.
    ///
    /// É o único lugar do app com SF Pro Rounded. Repare que continua sendo um
    /// estilo semântico: `Font.system(_:design:)` respeita Dynamic Type, ao
    /// contrário de `Font.system(size:)`, que o guardrail 2 proíbe.
    static let heroiNumeral = Font.system(.largeTitle, design: .rounded).bold().monospacedDigit()

    /// A unidade "m" ao lado do numeral herói: `.title3` bold, rounded.
    static let heroiUnidade = Font.system(.title3, design: .rounded).bold()

    /// Metragem da série: `.body` com dígitos monoespaçados.
    ///
    /// O monoespaçado é o que alinha os números à direita sem `.frame(width:)`,
    /// que o guardrail 8 proíbe.
    static let metragemSerie = Font.body.monospacedDigit()

    /// Descanso da série: `.footnote` com dígitos monoespaçados.
    static let descansoSerie = Font.footnote.monospacedDigit()

    /// Valor à direita de uma linha de lista: `.body` monoespaçado.
    static let valorDaLinha = Font.body.monospacedDigit()

    /// Número da semana no Histórico: `.title2` semibold, monoespaçado.
    static let numeroDaSemana = Font.title2.weight(.semibold).monospacedDigit()

    /// Rótulo do botão primário: `.body` semibold.
    static let rotuloBotaoPrimario = Font.body.weight(.semibold)
}
