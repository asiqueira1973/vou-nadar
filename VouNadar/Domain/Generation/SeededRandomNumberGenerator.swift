import Foundation

/// Gerador de números aleatórios com semente, reprodutível (contrato 13.1).
///
/// Recebe: uma semente inteira.
/// Devolve: sempre a mesma sequência para a mesma semente, em qualquer
/// execução e em qualquer aparelho.
///
/// Existe porque o `seed` do gerador é **obrigatoriamente injetável**
/// (contrato 13.1): sem semente fixa não há teste reprodutível, e o gerador é a
/// parte do app que mais precisa de teste — a seção 22 pede 500 gerações com
/// sementes variadas. Em produção o app usa `SystemRandomNumberGenerator`; nos
/// testes, este.
///
/// Copiado do Swim Builder sem mudança de algoritmo (spec 4.4, assunção 24.2).
///
/// O algoritmo é SplitMix64 — quatro linhas, sem dependência, distribuição boa
/// o bastante para sortear exercício. Não serve para criptografia, e não
/// precisa servir.
struct SeededRandomNumberGenerator: RandomNumberGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        // Semente zero degeneraria a sequência; o desvio mantém o gerador
        // válido para qualquer entrada, inclusive 0.
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Deriva uma semente estável a partir de textos e números.
    ///
    /// Recebe: as partes que identificam o caso (faixa, equipamentos,
    /// interruptores).
    /// Devolve: a mesma semente em toda execução do processo.
    ///
    /// **Não use `hashValue` do Swift para isto.** O `Hasher` é aleatorizado a
    /// cada processo, então um teste semeado por ele mudaria de resultado a
    /// cada execução — o oposto do que a seção 22 pede. Este FNV-1a é
    /// determinístico por construção.
    ///
    /// A semente sai da
    /// **identidade** do conjunto de equipamentos, não do tamanho dele. Derivar
    /// de `count` faria `{pull_buoy}`, `{palmares}` e `{nadadeiras}`
    /// compartilharem a mesma sequência, e as 16 combinações virariam 5 fluxos
    /// distintos — o teste perderia poder sem avisar.
    static func seed(from parts: [String]) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325  // offset basis do FNV-1a
        for parte in parts {
            for byte in parte.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x0000_0100_0000_01B3  // primo do FNV-1a
            }
            hash ^= UInt64(ascii: "|")
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}

extension UInt64 {
    fileprivate init(ascii character: Unicode.Scalar) {
        self = UInt64(character.value)
    }
}
