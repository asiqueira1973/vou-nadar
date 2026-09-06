import SwiftUI

// Aplicação dos tokens de superfície às listas (DESIGN-SYSTEM.md seção 1).
//
// Sem isto o app usa as cores do sistema — `systemGroupedBackground` e
// `secondarySystemGroupedBackground` —, que são cinzas neutros. A paleta do Vou
// Nadar é azul-esverdeada e derivada do ícone: `BackgroundPrimary` `#061620` no
// escuro, `SurfaceGrouped` `#0C2531`. A diferença é visível lado a lado.
//
// **Isto não viola o guardrail 1.** O guardrail proíbe aninhar contêiner —
// `.background()` com `RoundedRectangle` numa linha, `GroupBox` dentro de
// `Section`. Quem continua desenhando fundo, canto, inset e separador é o
// `List`; `.listRowBackground` e `.scrollContentBackground` são os pontos que o
// próprio SwiftUI oferece para trocar a **cor** desse desenho, não para
// substituí-lo.

extension View {

    /// O fundo de tela do app (`BackgroundPrimary`), atrás de um `List`.
    ///
    /// Esconde o fundo do `ScrollView` para a cor do app aparecer, sem desenhar
    /// nenhum contêiner novo.
    func fundoDeTela() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.fundoPrimario)
    }

    /// A cor de linha de `List` do app (`SurfaceGrouped`).
    ///
    /// Aplicada nas linhas, não em volta delas: o `List` mantém o canto, o inset
    /// e o separador dele.
    func linhaAgrupada() -> some View {
        listRowBackground(Color.superficieAgrupada)
    }
}

/// Aplica os tokens de superfície a um `List` inteiro de uma vez.
///
/// Existe para as telas não repetirem `.linhaAgrupada()` em toda linha e
/// esquecerem numa — que é como um app fica com uma linha cinza no meio de
/// linhas azuis.
struct ListaDoApp: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.insetGrouped)
            .fundoDeTela()
            // Aplicado ao `List`, propaga para todas as linhas dele — em vez de
            // repetir por Section e esquecer numa.
            .linhaAgrupada()
            .environment(\.defaultMinListRowHeight, Medidas.alvoDeToque)
    }
}

extension View {

    /// `List` no estilo do app: inset grouped, fundo `BackgroundPrimary` e
    /// altura mínima de linha igual ao alvo de toque de 44 pt
    /// (DESIGN-SYSTEM.md seção 9).
    func listaDoApp() -> some View {
        modifier(ListaDoApp())
    }
}
