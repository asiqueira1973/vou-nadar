import Foundation
import SwiftData

/// Falhas de validação das preferências (spec 7.11).
///
/// O SwiftData não expressa faixa de valor nem comparação entre colunas, então
/// as duas invariantes de 7.11 vivem aqui, na camada de acesso — que é o único
/// caminho por onde `preferencias` é escrita.
enum PreferencesError: Error, Equatable, CustomStringConvertible {

    /// `tamanho_raia_m` fora de 10...50 (assunção 24.3).
    case tamanhoRaiaForaDaFaixa(Int)

    /// `distancia_min_m > distancia_max_m`. Igual é permitido — faixa fechada é
    /// caso de uso legítimo (spec 7.7).
    case faixaInvertida(min: Int, max: Int)

    var description: String {
        switch self {
        case .tamanhoRaiaForaDaFaixa(let valor):
            "tamanho de raia \(valor) m fora de 10 a 50 m"
        case .faixaInvertida(let min, let max):
            "faixa invertida: \(min) m maior que \(max) m"
        }
    }

    /// A mensagem que a interface mostra (critério 8.3.2).
    var mensagemParaUsuario: String {
        switch self {
        case .tamanhoRaiaForaDaFaixa:
            "A piscina precisa ter entre 10 e 50 metros."
        case .faixaInvertida:
            "A distância mínima não pode ser maior que a máxima."
        }
    }
}

/// Acesso à linha única de `preferencias` e ao conjunto de equipamentos
/// marcados (spec 7.7 e 7.8).
///
/// Recebe: o `ModelContext` do store do aparelho.
/// Devolve: leitura e escrita das preferências, sempre validadas.
///
/// **A unicidade de `preferencias` é garantida aqui, por código**: o SwiftData
/// não expressa "no máximo uma linha" (spec 7.11). Todo acesso passa por
/// `preferenciasAtuais()`, que busca a primeira ou cria — nunca insere uma
/// segunda.
///
/// É `@MainActor` de propósito: mexe no `ModelContext` da UI. O domínio puro —
/// gerador e calculadora de descanso — fica fora daqui justamente para não
/// herdar esse isolamento (contratos 13.1 e 13.2).
@MainActor
final class PreferencesRepository {

    private let context: ModelContext

    /// A versão do catálogo embarcado, gravada no seed para instalação nova não
    /// ver banner de novidade no primeiro dia (spec 7.7).
    private let versaoCatalogoEmbarcada: Int

    init(context: ModelContext, versaoCatalogoEmbarcada: Int) {
        self.context = context
        self.versaoCatalogoEmbarcada = versaoCatalogoEmbarcada
    }

    // MARK: - Seed e leitura

    /// Cria a linha de `preferencias` na primeira abertura, com os defaults de
    /// 7.7, ou devolve a existente (spec 7.7 e 7.13).
    ///
    /// Recebe: nada.
    /// Devolve: a linha única de preferências.
    /// Erros: os do `ModelContext` ao salvar.
    ///
    /// É idempotente: chamar dez vezes cria uma linha só. Se por qualquer
    /// motivo o store tiver mais de uma — corrupção, bug antigo —, a primeira
    /// por `criado_em` vence e as outras são apagadas, porque duas linhas de
    /// preferência significam duas piscinas configuradas e nenhuma verdade.
    @discardableResult
    func seedPreferencesIfNeeded() throws -> Preferencias {
        let existentes = try context.fetch(
            FetchDescriptor<Preferencias>(sortBy: [SortDescriptor(\.criadoEm, order: .forward)]))

        if let primeira = existentes.first {
            for excedente in existentes.dropFirst() {
                context.delete(excedente)
            }
            if existentes.count > 1 { try context.save() }
            return primeira
        }

        // O seed grava a versão embarcada, e não o default 0 do schema: numa
        // instalação nova nada é "novidade" (spec 7.7).
        let novas = Preferencias(versaoCatalogoVisto: versaoCatalogoEmbarcada)
        context.insert(novas)
        try context.save()
        return novas
    }

    /// A linha única de preferências, criando-a se ainda não existir.
    func preferenciasAtuais() throws -> Preferencias {
        try seedPreferencesIfNeeded()
    }

    // MARK: - Piscina (regra 11.4 e critério 8.3)

    /// Grava o comprimento da raia e marca a piscina como confirmada
    /// (regra 11.4, critérios 8.3.1 e 8.3.2).
    ///
    /// Recebe: o comprimento em metros.
    /// Erros: `.tamanhoRaiaForaDaFaixa` fora de 10...50 — e aí **nada é
    /// gravado**, nem o tamanho nem a confirmação.
    ///
    /// Confirmar é o que destrava a geração nos dois aparelhos. Não é só
    /// requisito da execução: a regra 11.3 adapta as distâncias à raia, então
    /// gerar antes de saber a piscina produziria um treino para piscina nenhuma.
    ///
    /// **Trocar de piscina aqui não reescreve treino salvo** (spec 7.4): cada
    /// treino congelou o seu `tamanho_raia_m` na geração, e é por ele que a
    /// execução se guia.
    func confirmarPiscina(tamanhoRaiaM: Int) throws {
        guard Preferencias.faixaDeRaia.contains(tamanhoRaiaM) else {
            throw PreferencesError.tamanhoRaiaForaDaFaixa(tamanhoRaiaM)
        }
        let prefs = try preferenciasAtuais()
        prefs.tamanhoRaiaM = tamanhoRaiaM
        prefs.raiaConfirmada = true
        prefs.atualizadoEm = .now
        try context.save()
    }

    // MARK: - Faixa de distância

    /// Grava a faixa de distância pedida na Home.
    ///
    /// Recebe: piso e teto em metros.
    /// Erros: `.faixaInvertida` quando o piso passa do teto. **Piso igual ao
    /// teto é válido** — faixa fechada é caso de uso legítimo (spec 7.7).
    func atualizarFaixa(minM: Int, maxM: Int) throws {
        guard minM <= maxM else {
            throw PreferencesError.faixaInvertida(min: minM, max: maxM)
        }
        let prefs = try preferenciasAtuais()
        prefs.distanciaMinM = minM
        prefs.distanciaMaxM = maxM
        prefs.atualizadoEm = .now
        try context.save()
    }

    // MARK: - Ritmo de descanso (critério 8.3.5)

    /// Grava o ritmo de descanso global (regra 11.5).
    ///
    /// O valor passa a valer para as **próximas** gerações. Treino já salvo
    /// mantém o ritmo com que nasceu, congelado em `ritmo_descanso_usado`
    /// (princípio 0.6) — mudar aqui não altera um descanso já gravado.
    func atualizarRitmoDescanso(_ ritmo: RitmoDescanso) throws {
        let prefs = try preferenciasAtuais()
        prefs.ritmoDescanso = ritmo
        prefs.atualizadoEm = .now
        try context.save()
    }

    // MARK: - Interruptores

    /// Grava os interruptores de educativo e pernada da Home.
    ///
    /// Eles governam a **geração automática**: com o interruptor desligado, o
    /// modo correspondente não entra no sorteio (critério 8.4).
    func atualizarInterruptores(incluirEducativos: Bool, incluirPernada: Bool) throws {
        let prefs = try preferenciasAtuais()
        prefs.incluirEducativos = incluirEducativos
        prefs.incluirPernada = incluirPernada
        prefs.atualizadoEm = .now
        try context.save()
    }

    // MARK: - Equipamento na mochila (spec 7.8)

    /// Os `equipamento_id` marcados, em conjunto.
    ///
    /// **Conjunto vazio é estado válido e comum**: nadador sem equipamento
    /// nenhum. Nesse caso a geração usa só exercícios com `equipamento_exigido
    /// = nenhum`, que são 168 dos 226 (critério 8.4).
    func equipamentosSelecionados() throws -> Set<String> {
        let linhas = try context.fetch(FetchDescriptor<EquipamentoSelecionado>())
        return Set(linhas.map(\.equipamentoId))
    }

    /// Marca ou desmarca um equipamento (spec 7.8).
    ///
    /// Recebe: o `equipamento_id` e se ele deve ficar marcado.
    ///
    /// Desmarcar é **hard delete**: isto é estado de configuração, não
    /// histórico, e nada aponta para a linha (spec 7.10).
    func definirEquipamento(_ equipamentoId: String, selecionado: Bool) throws {
        let existentes = try context.fetch(
            FetchDescriptor<EquipamentoSelecionado>(
                predicate: #Predicate { $0.equipamentoId == equipamentoId }))

        if selecionado {
            // A unicidade também é constraint do modelo; a checagem evita
            // depender de erro do store para um caso previsível.
            guard existentes.isEmpty else { return }
            context.insert(EquipamentoSelecionado(equipamentoId: equipamentoId))
        } else {
            for linha in existentes { context.delete(linha) }
        }
        try marcarPreferenciasComoAtualizadas()
    }

    /// Toca o `atualizado_em` das preferências.
    ///
    /// Existe porque a seleção de equipamento vive noutra tabela mas viaja no
    /// mesmo `applicationContext` da sincronização, e é o `prefs_atualizado_em`
    /// que decide quem vence em conflito (regra 11.12).
    private func marcarPreferenciasComoAtualizadas() throws {
        let prefs = try preferenciasAtuais()
        prefs.atualizadoEm = .now
        try context.save()
    }
}
