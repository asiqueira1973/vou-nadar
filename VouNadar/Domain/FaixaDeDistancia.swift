import Foundation

/// A faixa de distância que o usuário pode pedir.
///
/// **É compartilhada pelos dois targets**, porque as duas telas de geração a
/// usam: o slider de dois puxadores no iPhone e a coroa digital no relógio.
/// Deixá-la numa delas faria a outra ter um segundo conjunto de limites, e os
/// dois divergiriam no primeiro ajuste.
///
/// Os valores vêm do Swim Builder, que tem a mesma tela sobre o mesmo catálogo —
/// herdados em vez de inventados (spec 4.4). Nem o spec nem o design system do
/// Vou Nadar fixam esses limites; o que eles fixam é o default de 1.500–2.500 m
/// (spec 7.7), que cai no meio desta faixa.
enum FaixaDeDistancia {

    /// Piso e teto absolutos, em metros.
    static let limites = 400...6000

    /// Passo de ajuste, em metros.
    ///
    /// **Cem não é arbitrário**: a geração sorteia o alvo total entre os
    /// múltiplos de 100 da faixa pedida. Um passo menor deixaria a interface
    /// produzir faixas como 1.520–1.580, que não têm múltiplo de 100 dentro e
    /// obrigariam o motor a se defender de uma entrada que não deveria existir.
    static let passo = 100
}
