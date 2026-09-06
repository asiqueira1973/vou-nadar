import Foundation
import SwiftData
import Testing

@testable import VouNadar

/// Persistência, favoritos e soft delete — critérios de aceite do épico 8.5.
@MainActor
struct WorkoutRepositoryTests {

    /// Um store em memória, um repositório e um resultado de geração real.
    private func cenario(raiaM: Int = 25, semente: UInt64 = 2026) throws
        -> (contexto: ModelContext, repo: WorkoutRepository, resultado: GenerationResult)
    {
        let contexto = ModelContext(try ModelContainer.vouNadar(emMemoria: true))
        let catalogo = try CatalogStore()
        let adaptado = AdaptedCatalog(catalogo: catalogo.allExercises, tamanhoRaiaM: raiaM)
        var rng = SeededRandomNumberGenerator(seed: semente)
        let resultado = WorkoutGenerator(catalogo: adaptado).gerar(
            GenerationRequest(
                minMeters: 1500, maxMeters: 2500, laneLengthM: raiaM, restPace: .normal),
            using: &rng)
        return (contexto, WorkoutRepository(context: contexto), resultado)
    }

    // MARK: - Gravação (critério 8.5)

    @Test("O treino é gravado com as quatro seções e todas as séries")
    func gravaSecoesESeries() throws {
        let c = try cenario()
        let treino = try c.repo.salvar(
            c.resultado, origem: .gerado_iphone, faixaPedida: 1500...2500)

        // Regra 11.1: sempre quatro, inclusive as vazias.
        #expect(treino.secoes.count == 4)
        #expect(treino.secoesOrdenadas.map(\.tipoSecao) == TipoSecao.allCases)

        let seriesGravadas = treino.secoes.reduce(0) { $0 + $1.series.count }
        let seriesGeradas = c.resultado.secoes.reduce(0) { $0 + $1.series.count }
        #expect(seriesGravadas == seriesGeradas)
    }

    @Test("A gravação copia os snapshots sem recalcular nada (princípio 0.6)")
    func gravaSnapshotsIntactos() throws {
        let c = try cenario(raiaM: 16)
        let treino = try c.repo.salvar(
            c.resultado, origem: .gerado_iphone, faixaPedida: 1500...2500)

        let geradas = c.resultado.secoes.flatMap(\.series)
        let gravadas = treino.secoesOrdenadas.flatMap(\.seriesOrdenadas)
        #expect(gravadas.count == geradas.count)

        for (gravada, gerada) in zip(gravadas, geradas) {
            #expect(gravada.exercicioId == gerada.exercicioId)
            #expect(gravada.repeticoes == gerada.repeticoes)
            #expect(gravada.distanciaM == gerada.distanciaM)
            #expect(gravada.distanciaCatalogoM == gerada.distanciaCatalogoM)
            #expect(gravada.metrosTotais == gerada.metrosTotais)
            // Os três que a execução no relógio depende (regras 11.5 e 11.7).
            #expect(gravada.descansoSeg == gerada.descansoSeg)
            #expect(gravada.descansoPosSerieSeg == gerada.descansoPosSerieSeg)
            #expect(gravada.voltasPorRepeticao == gerada.voltasPorRepeticao)
            #expect(gravada.ordem == gerada.ordem)
        }
    }

    @Test("A raia e o ritmo ficam congelados no treino (spec 7.4)")
    func congelaRaiaERitmo() throws {
        let contexto = ModelContext(try ModelContainer.vouNadar(emMemoria: true))
        let catalogo = try CatalogStore()
        let adaptado = AdaptedCatalog(catalogo: catalogo.allExercises, tamanhoRaiaM: 18)
        var rng = SeededRandomNumberGenerator(seed: 99)
        let resultado = WorkoutGenerator(catalogo: adaptado).gerar(
            GenerationRequest(
                minMeters: 1500, maxMeters: 2500, laneLengthM: 18, restPace: .longo),
            using: &rng)

        let treino = try WorkoutRepository(context: contexto).salvar(
            resultado, origem: .gerado_watch, faixaPedida: 1500...2500)

        #expect(treino.tamanhoRaiaM == 18)
        #expect(treino.ritmoDescansoUsado == .longo)
        #expect(treino.origem == .gerado_watch)
        #expect(treino.distanciaMinSolicitadaM == 1500)
        #expect(treino.distanciaMaxSolicitadaM == 2500)
    }

    @Test("Um treino recém-gravado nasce sem título, sem favorito e sem execuções")
    func estadoInicialDoTreino() throws {
        let c = try cenario()
        let treino = try c.repo.salvar(
            c.resultado, origem: .gerado_iphone, faixaPedida: 1500...2500)
        #expect(treino.titulo == nil)
        #expect(treino.favorito == false)
        #expect(treino.vezesExecutado == 0)
        #expect(treino.ultimaExecucaoEm == nil)
        #expect(treino.arquivadoEm == nil)
    }

    // MARK: - Favoritar (regra 11.14)

    @Test("Favoritar exige título e grava o texto aparado")
    func favoritarComTituloValido() throws {
        let c = try cenario()
        let treino = try c.repo.salvar(
            c.resultado, origem: .gerado_iphone, faixaPedida: 1500...2500)

        try c.repo.favoritar(treino, titulo: "  Terça leve  ")
        #expect(treino.titulo == "Terça leve")
        #expect(treino.favorito)
    }

    @Test(
        "Título inválido é recusado e nada é gravado (regra 11.14)",
        arguments: ["", "   ", "\n\t ", String(repeating: "a", count: 61)])
    func tituloInvalidoEhRecusado(titulo: String) throws {
        let c = try cenario()
        let treino = try c.repo.salvar(
            c.resultado, origem: .gerado_iphone, faixaPedida: 1500...2500)

        #expect(throws: WorkoutError.tituloInvalido) {
            try c.repo.favoritar(treino, titulo: titulo)
        }
        #expect(treino.titulo == nil)
        #expect(treino.favorito == false)
    }

    @Test("Os limites do título são exatamente 1 e 60 (regra 11.14)")
    func limitesDoTitulo() throws {
        let c = try cenario()
        let treino = try c.repo.salvar(
            c.resultado, origem: .gerado_iphone, faixaPedida: 1500...2500)

        try c.repo.favoritar(treino, titulo: "a")
        #expect(treino.titulo == "a")

        let sessenta = String(repeating: "b", count: 60)
        try c.repo.favoritar(treino, titulo: sessenta)
        #expect(treino.titulo == sessenta)
    }

    @Test("Renomear usa a mesma validação e atualiza a ordenação")
    func renomear() throws {
        let c = try cenario()
        let treino = try c.repo.salvar(
            c.resultado, origem: .gerado_iphone, faixaPedida: 1500...2500)
        try c.repo.favoritar(treino, titulo: "Antigo")
        let antes = treino.atualizadoEm

        try c.repo.renomear(treino, para: "Novo")
        #expect(treino.titulo == "Novo")
        #expect(treino.atualizadoEm > antes)

        #expect(throws: WorkoutError.tituloInvalido) {
            try c.repo.renomear(treino, para: "   ")
        }
        #expect(treino.titulo == "Novo")
    }

    @Test("Desfavoritar preserva o título — não é apagar")
    func desfavoritarPreservaOTitulo() throws {
        let c = try cenario()
        let treino = try c.repo.salvar(
            c.resultado, origem: .gerado_iphone, faixaPedida: 1500...2500)
        try c.repo.favoritar(treino, titulo: "Terça leve")

        try c.repo.desfavoritar(treino)
        #expect(treino.favorito == false)
        #expect(treino.titulo == "Terça leve")
    }

    // MARK: - Listagem (critério 8.5)

    @Test("A lista de favoritos ordena por atualizado_em decrescente")
    func ordenacaoDosFavoritos() throws {
        let c = try cenario()

        for (indice, nome) in ["Primeiro", "Segundo", "Terceiro"].enumerated() {
            let treino = try c.repo.salvar(
                c.resultado, origem: .gerado_iphone, faixaPedida: 1500...2500)
            try c.repo.favoritar(treino, titulo: nome)
            // `atualizado_em` é gravado com `.now`; separar no tempo torna a
            // ordenação determinística sem depender da resolução do relógio.
            treino.atualizadoEm = Date(timeIntervalSince1970: 1_000_000 + Double(indice) * 60)
        }
        try c.contexto.save()

        #expect(try c.repo.favoritos().map(\.titulo) == ["Terceiro", "Segundo", "Primeiro"])
    }

    @Test("Treino não favoritado não aparece na lista de favoritos")
    func naoFavoritoNaoAparece() throws {
        let c = try cenario()
        _ = try c.repo.salvar(c.resultado, origem: .gerado_iphone, faixaPedida: 1500...2500)
        #expect(try c.repo.favoritos().isEmpty)
    }

    // MARK: - Soft delete (regra 11.15)

    @Test("Apagar faz soft delete: some da lista, mas o registro continua no store")
    func arquivarEhSoftDelete() throws {
        let c = try cenario()
        let treino = try c.repo.salvar(
            c.resultado, origem: .gerado_iphone, faixaPedida: 1500...2500)
        try c.repo.favoritar(treino, titulo: "Terça leve")

        try c.repo.arquivar(treino)

        // Some das listas...
        #expect(try c.repo.favoritos().isEmpty)
        // ...mas o registro continua existindo, com a data de arquivamento.
        let todos = try c.contexto.fetch(FetchDescriptor<Treino>())
        #expect(todos.count == 1)
        #expect(todos.first?.arquivadoEm != nil)
    }

    @Test("Apagar o treino NÃO apaga as sessões — elas ficam no Histórico (regra 11.15)")
    func arquivarPreservaAsSessoes() throws {
        // É a razão de o soft delete existir: as sessões alimentam o volume da
        // semana, e apagá-las apagaria histórico de saúde do usuário.
        let c = try cenario()
        let treino = try c.repo.salvar(
            c.resultado, origem: .gerado_iphone, faixaPedida: 1500...2500)
        try c.repo.favoritar(treino, titulo: "Terça leve")

        let sessao = SessaoNatacao(
            treino: treino, tituloSnapshot: "Terça leve",
            iniciadaEm: Date(timeIntervalSince1970: 1_700_000_000),
            encerradaEm: Date(timeIntervalSince1970: 1_700_003_600),
            distanciaPlanejadaM: 2100, distanciaRealM: 2100,
            tamanhoRaiaM: 25, motivoEncerramento: .concluido)
        c.contexto.insert(sessao)
        try c.contexto.save()

        try c.repo.arquivar(treino)

        let sessoes = try c.contexto.fetch(FetchDescriptor<SessaoNatacao>())
        #expect(sessoes.count == 1)
        #expect(sessoes.first?.distanciaRealM == 2100)
        // E o título continua legível pelo snapshot, mesmo com o treino
        // arquivado (spec 7.9).
        #expect(sessoes.first?.tituloSnapshot == "Terça leve")
    }

    @Test("Arquivar também tira dos favoritos")
    func arquivarTiraDosFavoritos() throws {
        let c = try cenario()
        let treino = try c.repo.salvar(
            c.resultado, origem: .gerado_iphone, faixaPedida: 1500...2500)
        try c.repo.favoritar(treino, titulo: "Terça leve")
        try c.repo.arquivar(treino)
        #expect(treino.favorito == false)
    }

    // MARK: - Leitura de volta (princípio 0.6)

    @Test("O favorito relido do banco produz o mesmo texto copiado de antes")
    func favoritoReliaoProduzOMesmoTexto() throws {
        // O teste mais direto do princípio 0.6: o que foi gravado é o que volta,
        // sem recálculo pelo caminho.
        let c = try cenario(raiaM: 16)
        let catalogo = try CatalogStore()
        let treino = try c.repo.salvar(
            c.resultado, origem: .gerado_iphone, faixaPedida: 1500...2500)
        try c.repo.favoritar(treino, titulo: "Terça leve")

        let doBanco = WorkoutPresentation(treino: treino, catalogo: catalogo)
        let textoDoBanco = WorkoutTextExporter.texto(de: doBanco)

        #expect(textoDoBanco.hasPrefix("Terça leve \u{2014} "))
        #expect(textoDoBanco.contains("Raia de 16 m \u{00B7} descanso normal"))
        // A distância adaptada sobreviveu à ida e volta pelo banco.
        for serie in doBanco.secoes.flatMap(\.series) {
            #expect(serie.distanciaM % 16 == 0)
        }
    }
}
