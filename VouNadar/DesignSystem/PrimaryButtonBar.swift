import SwiftUI

/// O botão primário na barra inferior de área segura (DESIGN-SYSTEM.md seção 3).
///
/// Recebe: o rótulo, o texto opcional de motivo quando desabilitado, e a ação.
/// Devolve: a barra que vai em `.safeAreaInset(edge: .bottom)`.
///
/// **Sobre o estilo do botão — duas decisões, as duas do Alexandre.**
///
/// 1. *`glassProminent` é API do iOS 26, e o spec 4.1 fixa o alvo em iOS 18.0+.*
///    Decisão: manter o alvo em 18 e gatear a API por `#available`. Quem tem
///    iOS 26 vê vidro; quem tem 18 vê o equivalente nativo mais próximo.
///
/// 2. *O design system se contradiz sobre o preenchimento.* A seção 3 pede
///    `.glassProminent`, mas a seção 1 (restrição 2) e a seção 9 proíbem, nesta
///    ordem de palavras, "texto branco sobre `#0E9BC4`", que dá 3,23:1 e reprova
///    o AA — e `.glassProminent` renderiza exatamente isso no tema escuro
///    (medido no simulador: 3,27:1, reprovando também o requisito 17.9).
///
///    Decisão: **`.glass` com `.tint`**, que é o que as telas exportadas de fato
///    desenham — fundo translúcido, rótulo na cor de marca em vez de branco. O
///    contraste passa porque o rótulo tingido fica sobre a superfície da tela,
///    não sobre o azul.
///
///    O fallback do iOS 18 é `.bordered`, e não `.borderedProminent`, pelo mesmo
///    motivo: `.bordered` tinge o rótulo e deixa o fundo translúcido, enquanto
///    `.borderedProminent` preencheria sólido e traria de volta o branco sobre
///    `#0E9BC4`.
///
/// Nos dois casos o controle é do sistema, é `Capsule` por padrão, e continua
/// passando nos onze guardrails.
///
/// O motivo do bloqueio aparece **acima** do botão, em `.footnote` e cor
/// secundária, nunca dentro dele: é o estado "bloqueada" da tela P1 (seção 6 do
/// design system e critério 8.3.1).
struct BarraDeAcaoPrimaria<Rotulo: View>: View {

    /// Texto explicando por que o botão está desabilitado, ou `nil` quando não
    /// há motivo a explicar. Copy 15.2 no caso da Home sem piscina confirmada.
    ///
    /// Separado de `desabilitado` de propósito: a P6 na primeira abertura tem o
    /// botão inerte enquanto nenhuma opção foi tocada, e ali não há o que
    /// explicar — a tela inteira já é a explicação.
    var motivoDoBloqueio: LocalizedStringResource?

    /// Se o botão está inerte. Um motivo textual implica bloqueio; o contrário
    /// não é verdade.
    var desabilitado = false

    let acao: () -> Void
    @ViewBuilder let rotulo: () -> Rotulo

    var body: some View {
        VStack(spacing: 8) {
            if let motivoDoBloqueio {
                Text(motivoDoBloqueio)
                    .font(.footnote)
                    .foregroundStyle(Color.textoSecundario)
                    .multilineTextAlignment(.center)
                    // Dynamic Type até AX5 sem truncar (DESIGN-SYSTEM.md 9).
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: acao) {
                rotulo()
                    .font(.rotuloBotaoPrimario)
                    // O rótulo na cor de marca, sobre fundo translúcido — é o
                    // uso que a seção 1 permite ("rótulo de botão") e o que as
                    // telas exportadas desenham. O contraste do `AccentTint`
                    // sobre a superfície é 5,69:1 no escuro e 5,28:1 no claro,
                    // os dois acima do AA de 4,5:1.
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity)
            }
            .estiloPrimario()
            .disabled(desabilitado || motivoDoBloqueio != nil)
        }
        .padding(.horizontal)
        .padding(.top, Medidas.barraInferiorTopo)
        .padding(.bottom, Medidas.barraInferiorBase)
        .background(.bar)
    }
}

extension View {

    /// Aplica o estilo do botão primário, gateando a API de vidro do iOS 26.
    ///
    /// Ver `BarraDeAcaoPrimaria` para as duas decisões que este método
    /// materializa — o alvo em iOS 18 e o preenchimento translúcido em vez de
    /// sólido, que é o que mantém o contraste dentro do AA no tema escuro.
    @ViewBuilder
    func estiloPrimario() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass).controlSize(.large)
        } else {
            buttonStyle(.bordered).controlSize(.large)
        }
    }
}

/// Uma linha de `List` que se comporta como opção selecionável (DESIGN-SYSTEM.md
/// seção 3 e guardrail 5).
///
/// Recebe: o rótulo, se está marcada, e a ação.
/// Devolve: uma linha comum de `List` com `checkmark` no `.tint` quando
/// marcada.
///
/// **Não é "chip"** (guardrail 5): multi-seleção em iOS é linha de lista com
/// marcador, não cápsula colorida numa `HStack` rolável. E a marcação não é
/// sinalizada só por cor — o `checkmark` é o segundo canal que a seção 9 do
/// design system exige.
struct LinhaSelecionavel<Rotulo: View>: View {

    let selecionada: Bool
    let acao: () -> Void
    @ViewBuilder let rotulo: () -> Rotulo

    var body: some View {
        Button(action: acao) {
            HStack {
                rotulo()
                    .foregroundStyle(Color.textoPrimario)
                Spacer(minLength: 0)
                if selecionada {
                    Image(systemName: Simbolos.marcador)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            // A linha inteira é o alvo de toque, não só o texto.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selecionada ? [.isButton, .isSelected] : .isButton)
    }
}
