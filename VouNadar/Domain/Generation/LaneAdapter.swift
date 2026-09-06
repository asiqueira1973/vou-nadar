import Foundation

/// A adaptação da distância à raia (regra 11.3).
///
/// **É função pura**: sem estado, sem `MainActor`, sem disco. Junto com a
/// `RestCalculator` (regra 11.5), é o núcleo do produto — por isso as duas vivem
/// aqui, testadas, e não espalhadas pela interface.
///
/// ## O problema que ela resolve
///
/// O relógio só sabe que uma repetição acabou quando conta um número **inteiro**
/// de voltas (regra 11.7). Exigir que a distância do catálogo fosse múltiplo
/// exato da piscina inviabilizaria o produto justamente nas piscinas mais comuns
/// de condomínio e academia: em raia de 16 m sobrariam 14 exercícios dos 226, e
/// em 18 m sobrariam 2.
///
/// Por isso o gerador **adapta** em vez de exigir:
///
/// ```
/// voltas_por_repeticao = max(1, arredonda(distancia_catalogo_m / tamanho_raia_m))
/// distancia_m          = voltas_por_repeticao × tamanho_raia_m
/// metros_totais        = repeticoes × distancia_m
/// ```
///
/// Um `4×100` do catálogo aparece como `4×96 m` numa piscina de 16 m, porque é
/// isso que o nadador vai nadar. **`distancia_m` é a distância real e é o que a
/// interface exibe em todo lugar** — tela, relógio e texto copiado. Mostrar a
/// distância do catálogo e nadar outra é exatamente o erro que esta regra evita
/// (risco R2b, mitigado também pela copy 15.18).
///
/// ## A guarda de desvio
///
/// Exercícios cuja adaptação passaria de 25% de desvio **saem do sorteio**
/// naquela piscina. Isso protege o caso ruim — os blocos de 25 m em piscina de
/// 16, 18 ou 50 m, onde a adaptação distorceria demais o exercício.
///
/// Cobertura verificada contra o catálogo real (tabela de "11.3 detalhado"):
/// 226 utilizáveis em 10, 12, 15, 20 e 25 m; 205 em 16 e 18 m; 203 em 50 m;
/// 133 em 33 m. O teste `LaneAdapterTests` prende essas nove contagens.
enum LaneAdapter {

    /// Desvio máximo aceito entre a distância do catálogo e a adaptada
    /// (assunção 24.3b, confirmada pelo Alexandre).
    ///
    /// **Está aqui, num lugar só, de propósito.** A pergunta Q6 do spec é se
    /// 25% está calibrado, e a resposta honesta só vem de nadar. Quando vier,
    /// mudar este número é uma linha de diff — e as contagens de cobertura do
    /// teste mudam junto, o que obriga a olhar o efeito antes de aceitar.
    static let desvioMaximo = 0.25

    /// Quantas voltas uma repetição exige na piscina configurada (regra 11.3).
    ///
    /// Recebe: a distância por repetição **do catálogo** e o comprimento da raia.
    /// Devolve: o número inteiro de voltas, **nunca menor que 1**.
    ///
    /// O piso de 1 existe para o caso da piscina grande: um bloco de 25 m em
    /// raia de 50 m daria meia volta, e meia volta o relógio não conta. Vira uma
    /// volta — 50 m — e aí a guarda de desvio decide se o exercício sobrevive,
    /// que nesse caso é não.
    ///
    /// O arredondamento é meio-para-cima (`.rounded()` =
    /// `.toNearestOrAwayFromZero`), não bancário: 2,5 voltas viram 3, não 2.
    static func voltasPorRepeticao(distanciaCatalogoM: Int, tamanhoRaiaM: Int) -> Int {
        guard tamanhoRaiaM > 0 else { return 1 }
        let exatas = Double(distanciaCatalogoM) / Double(tamanhoRaiaM)
        return max(1, Int(exatas.rounded()))
    }

    /// A distância real por repetição, em metros (regra 11.3).
    ///
    /// Recebe: a distância do catálogo e o comprimento da raia.
    /// Devolve: `voltas_por_repeticao × tamanho_raia_m` — sempre um múltiplo
    /// exato da raia, que é o que faz a contagem de voltas do relógio fechar.
    ///
    /// É o valor gravado em `serie_treino.distancia_m` e o único que a interface
    /// mostra.
    static func distanciaAdaptadaM(distanciaCatalogoM: Int, tamanhoRaiaM: Int) -> Int {
        voltasPorRepeticao(distanciaCatalogoM: distanciaCatalogoM, tamanhoRaiaM: tamanhoRaiaM)
            * tamanhoRaiaM
    }

    /// O desvio relativo entre a distância do catálogo e a adaptada.
    ///
    /// Recebe: as duas distâncias.
    /// Devolve: `|adaptada − catálogo| / catálogo`, de 0 a 1.
    static func desvio(distanciaCatalogoM: Int, distanciaAdaptadaM: Int) -> Double {
        guard distanciaCatalogoM > 0 else { return 0 }
        return abs(Double(distanciaAdaptadaM - distanciaCatalogoM)) / Double(distanciaCatalogoM)
    }

    /// O exercício sobrevive à adaptação nesta piscina? (regra 11.3)
    ///
    /// Recebe: as duas distâncias.
    /// Devolve: falso quando o desvio passa de `desvioMaximo` — e então o
    /// exercício **sai do sorteio** naquela raia.
    static func desvioAceitavel(distanciaCatalogoM: Int, distanciaAdaptadaM: Int) -> Bool {
        desvio(distanciaCatalogoM: distanciaCatalogoM, distanciaAdaptadaM: distanciaAdaptadaM)
            <= desvioMaximo
    }

    /// O exercício pode ser sorteado nesta piscina? (regra 11.3)
    ///
    /// Recebe: o exercício do catálogo e o comprimento da raia.
    /// Devolve: falso quando a adaptação passaria da guarda de desvio.
    ///
    /// É o predicado único de "utilizável nesta raia": o `AdaptedCatalog` do
    /// épico 8.4 e os testes de cobertura passam os dois por aqui, para não
    /// existirem duas versões da mesma decisão.
    static func podeSerSorteado(_ exercicio: ExercicioCatalogo, tamanhoRaiaM: Int) -> Bool {
        let adaptada = distanciaAdaptadaM(
            distanciaCatalogoM: exercicio.distancia_m, tamanhoRaiaM: tamanhoRaiaM)
        return desvioAceitavel(
            distanciaCatalogoM: exercicio.distancia_m, distanciaAdaptadaM: adaptada)
    }
}
