import Foundation
import SwiftData
import Testing

@testable import VouNadar

/// Preferências, piscina e ritmo — critérios de aceite do épico 8.3.
///
/// Todos os testes rodam sobre um store em memória: nada toca o disco do
/// aparelho, e cada teste nasce com um banco vazio.
@MainActor
struct PreferencesRepositoryTests {

    /// Um repositório novo sobre um store em memória.
    private func repositorio(versaoCatalogo: Int = 1) throws -> PreferencesRepository {
        let container = try ModelContainer.vouNadar(emMemoria: true)
        return PreferencesRepository(
            context: ModelContext(container), versaoCatalogoEmbarcada: versaoCatalogo)
    }

    // MARK: - Seed (spec 7.7 e 7.13)

    @Test("O seed cria a linha única com os defaults da seção 7.7")
    func seedCriaComOsDefaults() throws {
        let repo = try repositorio()
        let prefs = try repo.seedPreferencesIfNeeded()

        #expect(prefs.distanciaMinM == 1500)
        #expect(prefs.distanciaMaxM == 2500)
        #expect(prefs.incluirEducativos == false)
        #expect(prefs.incluirPernada == false)
        #expect(prefs.tamanhoRaiaM == 25)
        #expect(prefs.ritmoDescanso == .normal)
        // Nasce FALSO: é o que bloqueia a geração até o usuário confirmar a
        // piscina (regra 11.4).
        #expect(prefs.raiaConfirmada == false)
    }

    @Test("O seed grava a versão embarcada, não o default 0 do schema (7.7)")
    func seedGravaVersaoDoCatalogo() throws {
        // Instalação nova não pode ver banner de novidade no primeiro dia.
        let repo = try repositorio(versaoCatalogo: 7)
        #expect(try repo.seedPreferencesIfNeeded().versaoCatalogoVisto == 7)
    }

    @Test("O seed é idempotente: dez chamadas criam uma linha só (7.11)")
    func seedEhIdempotente() throws {
        let container = try ModelContainer.vouNadar(emMemoria: true)
        let context = ModelContext(container)
        let repo = PreferencesRepository(context: context, versaoCatalogoEmbarcada: 1)

        let primeira = try repo.seedPreferencesIfNeeded()
        for _ in 0..<9 { _ = try repo.seedPreferencesIfNeeded() }

        let todas = try context.fetch(FetchDescriptor<Preferencias>())
        #expect(todas.count == 1)
        #expect(todas.first?.id == primeira.id)
    }

    @Test("Havendo mais de uma linha, a mais antiga vence e as outras somem (7.11)")
    func singletonSeCuraSozinho() throws {
        // O SwiftData não expressa "no máximo uma linha"; a unicidade é
        // garantida por código. Duas linhas de preferência significariam duas
        // piscinas configuradas e nenhuma verdade.
        let container = try ModelContainer.vouNadar(emMemoria: true)
        let context = ModelContext(container)

        let antiga = Preferencias(tamanhoRaiaM: 16, criadoEm: .now.addingTimeInterval(-100))
        context.insert(antiga)
        context.insert(Preferencias(tamanhoRaiaM: 50))
        try context.save()

        let repo = PreferencesRepository(context: context, versaoCatalogoEmbarcada: 1)
        let sobrevivente = try repo.seedPreferencesIfNeeded()

        #expect(try context.fetch(FetchDescriptor<Preferencias>()).count == 1)
        #expect(sobrevivente.tamanhoRaiaM == 16)
    }

    // MARK: - Piscina (critérios 8.3.1 a 8.3.3)

    @Test(
        "As piscinas de 12, 15, 16, 18 e 20 m são configuráveis (critério 8.3.3)",
        arguments: [10, 12, 15, 16, 18, 20, 25, 33, 50])
    func piscinasIncomunsSaoConfiguraveis(metros: Int) throws {
        let repo = try repositorio()
        try repo.confirmarPiscina(tamanhoRaiaM: metros)

        let prefs = try repo.preferenciasAtuais()
        #expect(prefs.tamanhoRaiaM == metros)
        #expect(prefs.raiaConfirmada == true)
    }

    @Test(
        "Valor fora de 10–50 é rejeitado com mensagem (critério 8.3.2)",
        arguments: [0, 9, 51, 100, -5])
    func piscinaForaDaFaixaEhRejeitada(metros: Int) throws {
        let repo = try repositorio()

        #expect(throws: PreferencesError.tamanhoRaiaForaDaFaixa(metros)) {
            try repo.confirmarPiscina(tamanhoRaiaM: metros)
        }

        // Nada é gravado: nem o tamanho, nem a confirmação. Confirmar uma
        // piscina impossível destravaria a geração com dado inválido.
        let prefs = try repo.preferenciasAtuais()
        #expect(prefs.tamanhoRaiaM == 25)
        #expect(prefs.raiaConfirmada == false)
    }

    @Test("A mensagem de erro da piscina é a que a interface mostra (8.3.2)")
    func mensagemDeErroDaPiscina() {
        #expect(
            PreferencesError.tamanhoRaiaForaDaFaixa(60).mensagemParaUsuario
                == "A piscina precisa ter entre 10 e 50 metros.")
    }

    @Test("Confirmar a piscina é o que destrava a geração (regra 11.4)")
    func confirmarDestravaAGeracao() throws {
        let repo = try repositorio()
        #expect(try repo.preferenciasAtuais().raiaConfirmada == false)

        try repo.confirmarPiscina(tamanhoRaiaM: 25)
        #expect(try repo.preferenciasAtuais().raiaConfirmada == true)
    }

    // MARK: - Trocar de piscina não reescreve treino salvo (critério 8.3.4)

    @Test("Trocar de piscina nos Ajustes NÃO reescreve treino já salvo (7.4)")
    func trocarPiscinaNaoReescreveTreinoSalvo() throws {
        // É o princípio 0.6 em forma de teste: um treino guardado hoje abre
        // igual daqui a dois anos. Ele foi montado para uma piscina específica,
        // com as distâncias adaptadas àquela raia (regra 11.3) — se a troca
        // reescrevesse o treino, o favorito mudaria sozinho e o nadador
        // executaria outra coisa.
        let container = try ModelContainer.vouNadar(emMemoria: true)
        let context = ModelContext(container)
        let repo = PreferencesRepository(context: context, versaoCatalogoEmbarcada: 1)

        try repo.confirmarPiscina(tamanhoRaiaM: 16)

        // Um treino gerado naquela piscina de 16 m: o 4×100 do catálogo virou
        // 4×96, seis voltas por repetição (fluxo 9.3).
        let treino = Treino(
            titulo: "Terça leve", origem: .gerado_iphone, distanciaTotalM: 384,
            distanciaMinSolicitadaM: 300, distanciaMaxSolicitadaM: 500,
            tamanhoRaiaM: 16, ritmoDescansoUsado: .normal,
            comEducativos: false, comPernada: false)
        let secao = SecaoTreino(tipoSecao: .principal, distanciaAlvoM: 384, descansoPosSecaoSeg: 0)
        let serie = SerieTreino(
            exercicioId: "FS_04x100_STEADY", repeticoes: 4, distanciaM: 96,
            distanciaCatalogoM: 100, metrosTotais: 384, descansoSeg: 30,
            descansoPosSerieSeg: 0, voltasPorRepeticao: 6,
            nomeSnapshot: "4×100 constante", descricaoSnapshot: "ritmo firme",
            equipamentoExigido: "nenhum", modo: .nado, intensidade: .aerobico, ordem: 1)
        secao.series = [serie]
        treino.secoes = [secao]
        context.insert(treino)
        try context.save()

        // O nadador vai a outra piscina e troca a configuração.
        try repo.confirmarPiscina(tamanhoRaiaM: 50)
        #expect(try repo.preferenciasAtuais().tamanhoRaiaM == 50)

        // O treino salvo continua exatamente como nasceu.
        let salvo = try #require(try context.fetch(FetchDescriptor<Treino>()).first)
        #expect(salvo.tamanhoRaiaM == 16)
        let serieSalva = try #require(salvo.secoesOrdenadas.first?.seriesOrdenadas.first)
        #expect(serieSalva.distanciaM == 96)
        #expect(serieSalva.distanciaCatalogoM == 100)
        #expect(serieSalva.voltasPorRepeticao == 6)
        #expect(serieSalva.descansoSeg == 30)
        #expect(salvo.distanciaTotalM == 384)
    }

    // MARK: - Faixa de distância (spec 7.7 e 7.11)

    @Test("Faixa fechada — piso igual ao teto — é válida (spec 7.7)")
    func faixaFechadaEhValida() throws {
        let repo = try repositorio()
        try repo.atualizarFaixa(minM: 2000, maxM: 2000)

        let prefs = try repo.preferenciasAtuais()
        #expect(prefs.distanciaMinM == 2000)
        #expect(prefs.faixaEstaFechada)
    }

    @Test("Faixa invertida é rejeitada (spec 7.11)")
    func faixaInvertidaEhRejeitada() throws {
        let repo = try repositorio()
        #expect(throws: PreferencesError.faixaInvertida(min: 3000, max: 1000)) {
            try repo.atualizarFaixa(minM: 3000, maxM: 1000)
        }
        #expect(try repo.preferenciasAtuais().distanciaMinM == 1500)
    }

    // MARK: - Ritmo de descanso (critério 8.3.5)

    @Test("O ritmo de descanso é configurável e persiste", arguments: RitmoDescanso.allCases)
    func ritmoPersiste(ritmo: RitmoDescanso) throws {
        let repo = try repositorio()
        try repo.atualizarRitmoDescanso(ritmo)
        #expect(try repo.preferenciasAtuais().ritmoDescanso == ritmo)
    }

    // MARK: - Equipamento (spec 7.8)

    @Test("Nenhum equipamento marcado é estado válido (spec 7.8)")
    func conjuntoVazioEhValido() throws {
        let repo = try repositorio()
        #expect(try repo.equipamentosSelecionados().isEmpty)
    }

    @Test("Marcar e desmarcar equipamento funciona, e marcar duas vezes não duplica")
    func marcarEDesmarcarEquipamento() throws {
        let repo = try repositorio()

        try repo.definirEquipamento("pull_buoy", selecionado: true)
        try repo.definirEquipamento("pull_buoy", selecionado: true)
        #expect(try repo.equipamentosSelecionados() == ["pull_buoy"])

        try repo.definirEquipamento("nadadeiras", selecionado: true)
        #expect(try repo.equipamentosSelecionados() == ["pull_buoy", "nadadeiras"])

        // Desmarcar é hard delete: estado de configuração, não histórico (7.10).
        try repo.definirEquipamento("pull_buoy", selecionado: false)
        #expect(try repo.equipamentosSelecionados() == ["nadadeiras"])
    }

    @Test("Mexer em equipamento toca o atualizado_em das preferências (regra 11.12)")
    func equipamentoTocaOAtualizadoEm() throws {
        // A seleção vive noutra tabela mas viaja no mesmo applicationContext, e
        // é o `prefs_atualizado_em` que decide quem vence em conflito.
        let repo = try repositorio()
        let antes = try repo.preferenciasAtuais().atualizadoEm

        try repo.definirEquipamento("prancha", selecionado: true)
        #expect(try repo.preferenciasAtuais().atualizadoEm > antes)
    }
}
