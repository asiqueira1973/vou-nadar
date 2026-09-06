import Foundation
import SwiftData

/// Falhas ao favoritar ou renomear (regra 11.14).
enum WorkoutError: Error, Equatable, CustomStringConvertible {

    /// Título vazio, só espaços, ou acima de 60 caracteres.
    case tituloInvalido

    var description: String { "título inválido" }

    /// A mensagem que a interface mostra.
    var mensagemParaUsuario: String {
        "O nome precisa ter de 1 a 60 caracteres."
    }
}

/// Persistência de treinos (épico 8.5).
///
/// Recebe: o `ModelContext` do store do aparelho.
/// Devolve: gravação do treino gerado, favoritar, renomear, listar e arquivar.
///
/// **A gravação é o momento em que os snapshots viram permanentes.** O gerador
/// já congelou descanso, distância adaptada e voltas (princípio 0.6); aqui eles
/// só são copiados campo a campo para as entidades. Nada é recalculado — se
/// fosse, um favorito mudaria sozinho na primeira release que mexesse na tabela
/// de descanso.
///
/// É `@MainActor` porque mexe no `ModelContext` da UI. O domínio puro fica fora
/// daqui de propósito (contratos 13.1 e 13.2).
@MainActor
final class WorkoutRepository {

    /// Limites do título do favorito (regra 11.14).
    static let limitesDoTitulo = 1...60

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Gravação (critério 8.5)

    /// Grava um treino gerado, com todas as seções e todas as séries.
    ///
    /// Recebe: o resultado da geração e a faixa que o usuário pediu.
    /// Devolve: o `Treino` já inserido no store.
    ///
    /// **Sempre grava as quatro seções**, inclusive as vazias (regra 11.1): a
    /// seção existe como registro mesmo sem série, porque a tela e a execução
    /// contam com as quatro estarem lá.
    @discardableResult
    func salvar(
        _ resultado: GenerationResult,
        origem: OrigemTreino,
        faixaPedida: ClosedRange<Int>
    ) throws -> Treino {
        let treino = Treino(
            origem: origem,
            distanciaTotalM: resultado.totalM,
            distanciaMinSolicitadaM: faixaPedida.lowerBound,
            distanciaMaxSolicitadaM: faixaPedida.upperBound,
            // Congelados na geração, os dois (spec 7.4 e princípio 0.6).
            tamanhoRaiaM: resultado.laneLengthM,
            ritmoDescansoUsado: resultado.restPace,
            comEducativos: resultado.secoes.contains {
                $0.series.contains { $0.modo == .educativo }
            },
            comPernada: resultado.secoes.contains {
                $0.series.contains { $0.modo == .pernada }
            })

        treino.secoes = resultado.secoes.map { secaoGerada in
            let secao = SecaoTreino(
                tipoSecao: secaoGerada.tipo,
                distanciaAlvoM: secaoGerada.alvoM,
                descansoPosSecaoSeg: secaoGerada.descansoPosSecaoSeg)
            secao.series = secaoGerada.series.map { serie in
                SerieTreino(
                    exercicioId: serie.exercicioId,
                    repeticoes: serie.repeticoes,
                    distanciaM: serie.distanciaM,
                    distanciaCatalogoM: serie.distanciaCatalogoM,
                    metrosTotais: serie.metrosTotais,
                    descansoSeg: serie.descansoSeg,
                    descansoPosSerieSeg: serie.descansoPosSerieSeg,
                    voltasPorRepeticao: serie.voltasPorRepeticao,
                    nomeSnapshot: serie.nomeSnapshot,
                    descricaoSnapshot: serie.descricaoSnapshot,
                    equipamentoExigido: serie.equipamentoExigido,
                    modo: serie.modo,
                    intensidade: serie.intensidade,
                    ordem: serie.ordem)
            }
            return secao
        }

        context.insert(treino)
        try context.save()
        return treino
    }

    // MARK: - Favoritar e renomear (regra 11.14)

    /// Favorita um treino, exigindo título válido (regra 11.14, critério 8.5).
    ///
    /// Recebe: o treino e o título digitado.
    /// Erros: `.tituloInvalido` quando o texto fica vazio depois de aparado ou
    /// passa de 60 caracteres — e aí **nada é gravado**, nem o título nem o
    /// estado de favorito.
    ///
    /// Favoritar é o que manda o treino para o relógio (regra 11.12).
    func favoritar(_ treino: Treino, titulo: String) throws {
        let limpo = titulo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.limitesDoTitulo.contains(limpo.count) else {
            throw WorkoutError.tituloInvalido
        }
        treino.titulo = limpo
        treino.favorito = true
        treino.atualizadoEm = .now
        try context.save()
    }

    /// Renomeia um favorito, com a mesma validação da regra 11.14.
    func renomear(_ treino: Treino, para titulo: String) throws {
        let limpo = titulo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.limitesDoTitulo.contains(limpo.count) else {
            throw WorkoutError.tituloInvalido
        }
        treino.titulo = limpo
        treino.atualizadoEm = .now
        try context.save()
    }

    /// Tira o treino dos favoritos.
    ///
    /// O título é preservado: desfavoritar não é apagar, e o treino continua
    /// legível. O relógio remove o treino na próxima sincronização (critério 8.6).
    func desfavoritar(_ treino: Treino) throws {
        treino.favorito = false
        treino.atualizadoEm = .now
        try context.save()
    }

    // MARK: - Listagem

    /// Os favoritos ativos, do mais recente para o mais antigo (critério 8.5).
    ///
    /// Ordena por `atualizado_em` decrescente, e **exclui os arquivados**: o
    /// soft delete some das listas mas mantém as sessões no Histórico
    /// (regra 11.15).
    func favoritos() throws -> [Treino] {
        try context.fetch(
            FetchDescriptor<Treino>(
                predicate: #Predicate { $0.favorito && $0.arquivadoEm == nil },
                sortBy: [SortDescriptor(\.atualizadoEm, order: .reverse)]))
    }

    // MARK: - Exclusão (regra 11.15)

    /// Apaga um treino por **soft delete** (regra 11.15, spec 7.10).
    ///
    /// Preenche `arquivado_em`. O treino some das listas, **mas as sessões
    /// continuam no Histórico e no volume da semana** — é por isso que a
    /// exclusão não é real: apagar de verdade apagaria o histórico de saúde do
    /// usuário junto, e esse dado não é do app.
    func arquivar(_ treino: Treino) throws {
        treino.arquivadoEm = .now
        treino.favorito = false
        treino.atualizadoEm = .now
        try context.save()
    }
}

// MARK: - Sessões de natação (regra 11.13)

extension WorkoutRepository {

    /// Grava uma sessão executada e atualiza o contador do treino
    /// **na mesma transação** (regra 11.13).
    ///
    /// Recebe: a sessão já montada, com distância real e motivo.
    /// Devolve: a sessão inserida.
    ///
    /// ## Por que "na mesma transação" é a parte importante
    ///
    /// `treino.vezes_executado` e `ultima_execucao_em` são **denormalizados**:
    /// eles poderiam ser derivados de `sessoes`, e existem porque a lista de
    /// Favoritos exibe o contador em toda linha, e contar relação por linha no
    /// SwiftData é lento o bastante para ser percebido (spec 7.4).
    ///
    /// O preço desse ganho é exatamente esta função. Inserir a sessão num
    /// `save()` e atualizar o contador noutro abre uma janela em que os dois
    /// discordam — e se o app morrer nessa janela, eles discordam para sempre,
    /// sem nada que reconcilie. Por isso os dois acontecem antes de um único
    /// `save()`.
    @discardableResult
    func registrarSessao(_ sessao: SessaoNatacao) throws -> SessaoNatacao {
        context.insert(sessao)

        if let treino = sessao.treino {
            treino.vezesExecutado += 1
            // Só avança se for mais recente: registrar uma sessão antiga não
            // pode fazer o treino parecer executado hoje.
            if let anterior = treino.ultimaExecucaoEm {
                treino.ultimaExecucaoEm = max(anterior, sessao.iniciadaEm)
            } else {
                treino.ultimaExecucaoEm = sessao.iniciadaEm
            }
        }

        try context.save()
        return sessao
    }

    /// Apaga uma sessão e **desconta** o contador, na mesma transação
    /// (regra 11.13, spec 7.10).
    ///
    /// É **hard delete**, e só pelo iPhone: o caso de uso é o usuário que
    /// registrou errado e quer desfazer.
    ///
    /// **O `HKWorkout` correspondente NÃO é apagado junto.** É dado de saúde do
    /// usuário e sai pelo app Saúde, não por aqui (spec 7.10 e seção 20). Apagar
    /// dado de saúde por conta própria seria assumir uma autoridade que o app
    /// não tem.
    func removerSessao(_ sessao: SessaoNatacao) throws {
        if let treino = sessao.treino {
            treino.vezesExecutado = max(0, treino.vezesExecutado - 1)

            // A última execução passa a ser a da sessão restante mais recente.
            // Recalcular aqui é barato — são as sessões de um treino só — e
            // deixar a data de uma sessão apagada seria mentira visível na tela.
            let restantes = treino.sessoes
                .filter { $0.id != sessao.id }
                .map(\.iniciadaEm)
            treino.ultimaExecucaoEm = restantes.max()
        }

        context.delete(sessao)
        try context.save()
    }

    /// As sessões, da mais recente para a mais antiga (tela P4).
    func sessoes() throws -> [SessaoNatacao] {
        try context.fetch(
            FetchDescriptor<SessaoNatacao>(
                sortBy: [SortDescriptor(\.iniciadaEm, order: .reverse)]))
    }
}
