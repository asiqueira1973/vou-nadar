import Foundation

/// Limpeza do nome do exercício para exibição (regra 14.2.5).
///
/// **Existe por um conflito real entre o spec e o catálogo copiado.**
///
/// A regra 14.2.5 manda montar a linha como `{repeticoes}×{distancia_m}
/// {nome_snapshot}`, e o exemplo da seção 14.1 mostra nomes como `crawl leve`,
/// `pernada` e `nado livre solto` — isto é, **sem** a metragem embutida.
///
/// Mas os **226 nomes do catálogo copiado do Swim Builder começam com o prefixo
/// `NxM`**: `1x300 Aquecimento Leve`, `4x100 Crawl Ritmo Constante`. Ao pé da
/// letra, a regra produziria `1×300 1x300 Aquecimento Leve` — número duplicado.
/// E numa piscina de 16 m produziria `1×304 1x300 Aquecimento Leve`, onde o
/// segundo número **contradiz** o primeiro, porque o do nome é a distância do
/// catálogo e o da regra é a adaptada (regra 11.3).
///
/// Esta função remove o prefixo, restaurando exatamente a forma do exemplo do
/// spec. Ela é o **único** lugar onde isso acontece, e serve tanto ao texto
/// copiado quanto à tela P2 — para os dois nunca divergirem.
enum ExerciseName {

    /// Remove um prefixo `NxM` do começo do nome, se houver.
    ///
    /// Recebe: o `nome_snapshot` da série.
    /// Devolve: o nome sem a metragem embutida — `1x300 Aquecimento Leve` vira
    /// `Aquecimento Leve`.
    ///
    /// Nome sem prefixo passa intacto, e nome que sobraria vazio é devolvido
    /// como veio: é melhor mostrar a metragem duas vezes do que mostrar nada.
    static func semPrefixoDeSerie(_ nome: String) -> String {
        guard let intervalo = nome.range(of: #"^\d+\s*[xX\u{00D7}]\s*\d+\s+"#, options: .regularExpression)
        else { return nome }
        let limpo = String(nome[intervalo.upperBound...])
            .trimmingCharacters(in: .whitespaces)
        return limpo.isEmpty ? nome : limpo
    }
}
