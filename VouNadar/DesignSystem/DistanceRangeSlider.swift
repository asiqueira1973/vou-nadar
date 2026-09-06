import SwiftUI

/// Slider de intervalo de dois puxadores para a faixa de distância
/// (DESIGN-SYSTEM.md seção 3).
///
/// Recebe: os dois extremos da faixa, em metros.
/// Escreve: os dois extremos, sempre em passos de 100 m e nunca invertidos.
///
/// **É a única exceção do guardrail 11.** O guardrail proíbe reconstruir
/// controle do sistema — `Toggle`, `Stepper`, linha de lista e swipe actions são
/// os nativos. Este existe porque o SwiftUI não fornece slider de intervalo, e
/// o design system o declara nominalmente como a exceção. Nenhum outro controle
/// do app é desenhado à mão.
///
/// **Acessibilidade.** Cada puxador é um elemento ajustável próprio para o
/// VoiceOver, com `accessibilityAdjustableAction` — sem isso o controle seria
/// invisível para quem navega por gesto, e o requisito 17.9 pede VoiceOver em
/// todas as telas do iPhone. A área de toque de cada puxador é de 44 × 44 pt
/// (seção 9 do design system), maior que os 26 pt que ele desenha.
struct DistanceRangeSlider: View {

    /// Faixa total que o controle percorre e o passo de ajuste.
    ///
    /// Vêm de `FaixaDeDistancia`, que é compartilhada com o relógio: as duas
    /// telas de geração têm que concordar sobre os limites.
    static let limites = FaixaDeDistancia.limites
    static let passo = FaixaDeDistancia.passo

    @Binding var minM: Int
    @Binding var maxM: Int

    /// Chamado ao terminar um arraste, para gravar uma vez só em vez de a cada
    /// quadro.
    var aoTerminarAjuste: () -> Void = {}

    /// Diâmetro desenhado do puxador (DESIGN-SYSTEM.md, tela P1).
    private let diametroPuxador: CGFloat = 26

    /// Espessura do trilho.
    private let alturaTrilho: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let largura = geo.size.width
            let util = max(1, largura - diametroPuxador)
            let centroMin = diametroPuxador / 2 + fracao(minM) * util
            let centroMax = diametroPuxador / 2 + fracao(maxM) * util

            ZStack(alignment: .leading) {
                // O trilho e a faixa preenchida são as únicas formas desenhadas
                // aqui; os puxadores são views, para poderem receber gesto e
                // foco de VoiceOver.
                Canvas { contexto, tamanho in
                    let y = tamanho.height / 2
                    let trilho = Path(
                        roundedRect: CGRect(
                            x: 0, y: y - alturaTrilho / 2, width: tamanho.width,
                            height: alturaTrilho),
                        cornerRadius: alturaTrilho / 2)
                    contexto.fill(trilho, with: .color(.hairline))

                    let preenchida = Path(
                        roundedRect: CGRect(
                            x: centroMin, y: y - alturaTrilho / 2, width: max(0, centroMax - centroMin),
                            height: alturaTrilho),
                        cornerRadius: alturaTrilho / 2)
                    // A trilha preenchida é um dos usos permitidos do
                    // `AccentTint` (DESIGN-SYSTEM.md seção 1).
                    contexto.fill(preenchida, with: .color(.destaque))
                }

                puxador(centro: centroMin, util: util, ehMinimo: true)
                puxador(centro: centroMax, util: util, ehMinimo: false)
            }
        }
        .frame(height: Medidas.alvoDeToque)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Puxador

    @ViewBuilder
    private func puxador(centro: CGFloat, util: CGFloat, ehMinimo: Bool) -> some View {
        Circle()
            .fill(.white)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            .frame(width: diametroPuxador, height: diametroPuxador)
            // A área de toque é maior que o desenho (seção 9).
            .frame(width: Medidas.alvoDeToque, height: Medidas.alvoDeToque)
            .contentShape(Circle())
            .position(x: centro, y: Medidas.alvoDeToque / 2)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { valor in
                        let bruto = valorPara(x: valor.location.x, util: util)
                        if ehMinimo {
                            minM = min(bruto, maxM)
                        } else {
                            maxM = max(bruto, minM)
                        }
                    }
                    .onEnded { _ in aoTerminarAjuste() }
            )
            .accessibilityElement()
            .accessibilityLabel(
                Text(ehMinimo ? Copy.a11yFaixaMinima : Copy.a11yFaixaMaxima)
            )
            .accessibilityValue(Text(verbatim: "\(Formato.metros(ehMinimo ? minM : maxM)) m"))
            .accessibilityAdjustableAction { direcao in
                ajustar(ehMinimo: ehMinimo, direcao: direcao)
            }
    }

    // MARK: - Conversão entre metros e posição

    /// Onde um valor cai no trilho, de 0 a 1.
    private func fracao(_ valor: Int) -> CGFloat {
        let total = CGFloat(Self.limites.upperBound - Self.limites.lowerBound)
        guard total > 0 else { return 0 }
        return CGFloat(valor - Self.limites.lowerBound) / total
    }

    /// O valor em metros de uma posição no trilho, já ajustado ao passo de 100 m
    /// e preso aos limites.
    ///
    /// O passo existe porque a geração sorteia o alvo entre os múltiplos de 100
    /// da faixa pedida: uma faixa como 1.520–1.580 não tem múltiplo de 100
    /// dentro e obrigaria o motor a se defender de uma entrada que a interface
    /// nunca deveria produzir.
    private func valorPara(x: CGFloat, util: CGFloat) -> Int {
        let fracao = ((x - diametroPuxador / 2) / max(1, util)).clamped(to: 0...1)
        let total = Self.limites.upperBound - Self.limites.lowerBound
        let bruto = Double(Self.limites.lowerBound) + Double(total) * Double(fracao)
        let emPassos = (bruto / Double(Self.passo)).rounded() * Double(Self.passo)
        return Int(emPassos).clamped(to: Self.limites)
    }

    /// Um passo de 100 m para cima ou para baixo, pelo VoiceOver.
    private func ajustar(ehMinimo: Bool, direcao: AccessibilityAdjustmentDirection) {
        let delta = direcao == .increment ? Self.passo : -Self.passo
        if ehMinimo {
            minM = min((minM + delta).clamped(to: Self.limites), maxM)
        } else {
            maxM = max((maxM + delta).clamped(to: Self.limites), minM)
        }
        aoTerminarAjuste()
    }
}

extension Comparable {

    /// Prende um valor a um intervalo fechado.
    func clamped(to limites: ClosedRange<Self>) -> Self {
        min(max(self, limites.lowerBound), limites.upperBound)
    }
}
