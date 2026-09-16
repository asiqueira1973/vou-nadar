import Foundation

/// Como dizer ao nadador quantas travessias tem uma repetição.
///
/// Recebe: as voltas por repetição congeladas na geração (regra 11.3).
/// Devolve: a contagem em **chegadas** (ida e volta) ou em **piscinas**
/// (travessias soltas), conforme o número fechar ou não em pares.
///
/// Feature pedida pelo Alexandre em 15/09/2026, depois de nadar com o app numa
/// piscina de 18 m. Não está no spec: `1×198 m` diz quanto nadar, mas não diz
/// **quantas vezes bater na parede**, que é como o nadador conta dentro d'água.
///
/// ## Cuidado com a palavra "volta"
///
/// O código chama de **volta** uma travessia — `LaneAdapter.voltasPorRepeticao`
/// devolve 4 para um `100 m` em raia de 25 m, e `LapCounter` conta assim. Na
/// boca do nadador, isso é uma **piscina**; **chegada** é ida e volta, que são
/// duas voltas do nosso vocabulário. Esta é a única fronteira onde os dois
/// vocabulários se encontram, e é por isso que a tradução mora aqui, sozinha.
///
/// ## Por que pode ser calculada na leitura
///
/// O princípio 0.6 proíbe **recalcular** descanso, distância e voltas ao ler.
/// Aqui nada é recalculado: `voltas_por_repeticao` continua sendo o snapshot
/// gravado na geração, e esta função só o divide por dois. Um favorito antigo
/// mostra a mesma contagem para sempre, mesmo que o nadador troque de piscina.
enum LapDisplay {

    /// Acima desta raia a contagem não é exibida.
    ///
    /// Em piscina de 25 ou 50 m a conta é trivial e todo nadador já a faz de
    /// cabeça: `100 m` são quatro travessias, duas chegadas. Dizer isso na tela
    /// é ruído — e ruído numa tela que o nadador lê com pressa custa a atenção
    /// que os números importantes precisam.
    ///
    /// Abaixo de 25 m a conta deixa de ser óbvia: ninguém divide 198 por 18 na
    /// borda da piscina. É aí que a linha ganha o lugar dela, e é só aí.
    ///
    /// Decisão do Alexandre em 15/09/2026.
    static let raiaMaximaM = 25

    /// A contagem, na unidade que fecha.
    enum Contagem: Equatable, Sendable {

        /// Ida e volta, quando as travessias fecham em pares.
        case chegadas(Int)

        /// Travessias soltas, quando não fecham.
        ///
        /// **Não é um caso de erro nem de exceção.** Numa raia de 18 m a
        /// maioria das repetições cai aqui — `54 m` são três travessias —, e
        /// dizer "1,5 chegada" seria pior que dizer "3 piscinas": ninguém nada
        /// meia chegada.
        case piscinas(Int)
    }

    /// A contagem de uma repetição, quando vale a pena mostrá-la.
    ///
    /// Recebe: quantas travessias a repetição tem, como gravado em
    /// `serie_treino.voltas_por_repeticao`, e a raia do treino (spec 7.4).
    /// Devolve: a contagem, ou `nil` quando não há o que mostrar — raia de 25 m
    /// ou maior, onde a conta é óbvia, ou série sem volta gravada, que é dado
    /// inválido e não pode virar "0 piscinas" na tela.
    ///
    /// A raia vem do treino, **congelada na geração**, e não das preferências
    /// atuais: um favorito montado para a piscina do clube continua contando
    /// pela piscina do clube depois que o nadador trocar a preferência para a
    /// da academia (princípio 0.6).
    static func contagem(voltasPorRepeticao: Int, tamanhoRaiaM: Int) -> Contagem? {
        guard tamanhoRaiaM < raiaMaximaM else { return nil }
        guard voltasPorRepeticao > 0 else { return nil }
        return voltasPorRepeticao.isMultiple(of: 2)
            ? .chegadas(voltasPorRepeticao / 2)
            : .piscinas(voltasPorRepeticao)
    }
}
