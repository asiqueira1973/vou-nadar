import Foundation

/// Todo nome de SF Symbol usado no app, num lugar só.
///
/// **Nome de símbolo inventado não quebra o build: ele vira um quadrado vazio em
/// produção.** É por isso que os nomes vivem aqui em vez de espalhados por
/// literais nas Views, e é por isso que existe `SymbolsTests`, que resolve cada
/// um destes nomes de verdade e reprova se algum não existir no sistema.
///
/// A lista da seção 4 do `DESIGN-SYSTEM.md` é a fonte. Os três símbolos do selo
/// de modo estão marcados abaixo porque o design system **não os nomeia** — ele
/// exige "SF Symbol antes" do selo na tabela de tipografia, mas não diz qual.
///
/// Os símbolos de equipamento **não estão aqui**: eles vêm do campo `icone_sf`
/// de `tipos_equipamento.json` (spec 7.3), que é dado, não código. O teste os
/// valida junto, lendo do catálogo.
///
/// **Este arquivo é fonte dos DOIS targets.** O relógio tem design system
/// próprio (DESIGN-SYSTEM.md seção 7) mas usa alguns dos mesmos glyphs, e um
/// registro por target significaria dois lugares para o nome errado se esconder
/// — sendo que só um deles teria teste.
enum Simbolos {

    // MARK: - Navegação (DESIGN-SYSTEM.md seção 4)

    /// Aba Treino, e o estado vazio do Histórico.
    static let abaTreino = "figure.pool.swim"
    static let abaFavoritos = "star"
    static let favoritarPreenchido = "star.fill"
    static let abaHistorico = "chart.bar"
    static let ajustes = "gearshape"

    // MARK: - Seleção e navegação de lista

    static let marcador = "checkmark"

    // MARK: - Estados e avisos

    /// Aviso de repertório curto (regra 11.19).
    static let avisoRepertorioCurto = "exclamationmark.triangle.fill"
    /// Confirmação "Treino copiado." (copy 15.19).
    static let confirmacaoCopia = "checkmark.circle.fill"
    /// Tela de erro de autorização do HealthKit, no relógio (copy 15.11).
    static let semAutorizacao = "hand.raised.slash"

    // MARK: - Ações

    /// "Copiar como texto" (copy 15.20).
    static let copiar = "doc.on.doc"
    /// Menu "Gerar outro".
    static let menu = "ellipsis.circle"
    /// Selo de sessão de origem externa, no Histórico.
    static let foraDoApp = "arrow.up.forward"
    static let apagar = "trash"
    static let renomear = "pencil"
    static let fechar = "xmark"

    // MARK: - Selo de modo do exercício
    //
    // O DESIGN-SYSTEM.md pede "SF Symbol antes" do selo mas **não diz qual**.
    // Estes três foram escolhidos aqui e são validados por `SymbolsTests`; se
    // algum dia o design nomear outros, a troca é nesta lista e em nenhum outro
    // lugar.

    /// Selo "braçada" — o mesmo glyph de mão que o pull buoy e o palmar usam no
    /// catálogo, porque braçada é o gesto do braço.
    static let modoBracada = "hand.raised"
    /// Selo "pernada".
    static let modoPernada = "shoeprints.fill"
    /// Selo "técnica", para exercício educativo.
    static let modoTecnica = "figure.mind.and.body"

    /// Todos os nomes acima, para o teste conseguir varrer sem repetir a lista.
    static let todos: [String] = [
        abaTreino, abaFavoritos, favoritarPreenchido, abaHistorico, ajustes,
        marcador, avisoRepertorioCurto, confirmacaoCopia, semAutorizacao,
        copiar, menu, foraDoApp, apagar, renomear, fechar,
        modoBracada, modoPernada, modoTecnica,
    ]
}
