import SwiftUI

// Tokens do Apple Watch (DESIGN-SYSTEM.md seções 1, 2 e 7).
//
// **O relógio não segue o design system do iPhone.** Não há Color Set, não há
// tema claro e não há Dynamic Type: a tela é fixa, o modo é escuro sempre, e a
// hierarquia é a do app Treino nativo da Apple — que é o vocabulário visual que
// o nadador já lê com o braço molhado.

extension Color {

    /// Fundo de **toda** tela do relógio.
    ///
    /// `#000000` puro é obrigatório: é OLED, pixel apagado não gasta bateria e
    /// dá o contraste máximo. **Nunca cinza escuro, nunca material.**
    static let watchFundo = Color.black

    /// Estado NADANDO. 6,50:1 sobre preto.
    static let watchNadando = Color(red: 0x0E / 255, green: 0x9B / 255, blue: 0xC4 / 255)

    /// Estado DESCANSANDO. 10,22:1 sobre preto.
    static let watchDescansando = Color(red: 0xFF / 255, green: 0x9F / 255, blue: 0x0A / 255)

    /// Últimos 3 segundos do descanso. 10,39:1 sobre preto.
    ///
    /// **Âmbar e verde têm 1,02:1 de contraste ENTRE SI**: para quem tem
    /// deuteranopia os dois estados são a mesma cor, justamente na transição que
    /// avisa "prepara pra sair". Por isso a mudança de estado nunca é só de cor
    /// — ver o requisito 17.12 e a seção 7 do design system.
    static let watchSaida = Color(red: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255)

    /// Encerrar. 6,16:1 sobre preto.
    static let watchDestrutivo = Color(red: 0xFF / 255, green: 0x45 / 255, blue: 0x3A / 255)

    static let watchTextoPrimario = Color.white
    static let watchTextoSecundario = Color(red: 0x98 / 255, green: 0x98 / 255, blue: 0x9F / 255)
    static let watchSuperficieDeBotao = Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255)

    /// Always-On, luminância reduzida (DESIGN-SYSTEM.md seção 7, item 7).
    static let watchNadandoApagado = Color(red: 0x7C / 255, green: 0x88 / 255, blue: 0x94 / 255)
    static let watchDescansandoApagado = Color(red: 0xA8 / 255, green: 0x92 / 255, blue: 0x5F / 255)
}

/// Tamanhos de tipografia do relógio (DESIGN-SYSTEM.md seção 2).
///
/// **Aqui tamanho explícito em pontos é permitido**, ao contrário do iPhone: a
/// tela é fixa, não há Dynamic Type na execução, e a hierarquia é a do app
/// Treino nativo. A fonte é SF Compact Rounded — `.rounded` no `Font.system`.
///
/// **Nada abaixo de 15 pt.** No Ultra de 49 mm, some de 12 a 30% em cada valor.
enum WatchTipografia {

    /// A contagem de descanso é o **maior elemento de todo o app**.
    /// Mínimo declarado: 52 pt; na prática 76 pt em 41 mm.
    static let contagemDescanso: CGFloat = 76

    /// Últimos 3 segundos: o número **cresce** além de mudar de cor.
    /// É um dos dois canais não-cromáticos que o requisito 17.12 exige.
    static let contagemDescansoFinal: CGFloat = 90

    /// Repetição atual, o `3` de "3 de 4".
    static let repeticaoAtual: CGFloat = 56

    /// Algarismo da contagem inicial de 3 segundos, em tela cheia.
    static let contagemInicial: CGFloat = 130

    /// Distância no resumo.
    static let distanciaResumo: CGFloat = 40

    /// Série e rótulos. **É o piso**: nada no relógio fica abaixo disto.
    static let rotulo: CGFloat = 15

    /// Distância na tela Início e na pré-visualização.
    static let distanciaDestaque: CGFloat = 34

    /// Área de toque mínima (DESIGN-SYSTEM.md seção 9).
    ///
    /// Vale para os botões da tela W9, lembrando que **na água nenhum botão é
    /// alcançável** (princípio 0.1): o Water Lock está ligado e a tela ignora o
    /// dedo. Estes 44 pt servem ao momento em que a coroa já destravou.
    static let alvoDeToque: CGFloat = 44
}

extension Font {

    /// SF Compact Rounded no tamanho pedido.
    ///
    /// Centraliza o `design: .rounded` para nenhuma tela do relógio esquecer e
    /// sair com a fonte errada no meio das outras.
    static func watch(_ tamanho: CGFloat, _ peso: Font.Weight = .semibold) -> Font {
        .system(size: tamanho, weight: peso, design: .rounded)
    }
}

extension View {

    /// Fundo preto puro em tela cheia (DESIGN-SYSTEM.md seção 7, item 1).
    func fundoDoRelogio() -> some View {
        background(Color.watchFundo.ignoresSafeArea())
    }
}
