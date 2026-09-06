import Foundation
import SwiftData
import Testing

@testable import VouNadar

/// Encerramento e gravação — critérios de aceite do épico 8.9.
///
/// O que dá para testar aqui: **a decisão do motivo** (função pura) e **o
/// contador denormalizado da regra 11.13** (transação). O que não dá: se o
/// `HKWorkout` aparece no app Saúde — isso é o teste manual em piscina do
/// Definition of Done.
@MainActor
struct SessionRecordingTests {

    // MARK: - A decisão do motivo (regras 11.10 e 11.11)

    @Test("Abaixo de 25 m é descartado, mesmo com o treino concluído (regra 11.11)")
    func curtoDemaisVenceTudo() {
        // Um toque acidental que iniciou e encerrou a sessão não pode virar
        // registro de saúde.
        #expect(
            MotivoEncerramento.decidir(distanciaRealM: 24, treinoConcluido: true)
                == .descartado_curto)
        #expect(
            MotivoEncerramento.decidir(distanciaRealM: 0, treinoConcluido: false)
                == .descartado_curto)
    }

    @Test("Exatamente 25 m já grava — o limite é inclusivo (assunção 24.4)")
    func vinteECincoGrava() {
        #expect(
            MotivoEncerramento.decidir(distanciaRealM: 25, treinoConcluido: false)
                == .encerrado_antes)
    }

    @Test("Chegou ao fim do plano: concluído")
    func concluido() {
        #expect(
            MotivoEncerramento.decidir(distanciaRealM: 2100, treinoConcluido: true) == .concluido)
    }

    @Test("Parou antes NÃO é erro (regra 11.10)")
    func pararAntesNaoEhErro() {
        let motivo = MotivoEncerramento.decidir(distanciaRealM: 1200, treinoConcluido: false)
        #expect(motivo == .encerrado_antes)
        // E continua indo para o app Saúde: o que foi nadado, foi nadado.
        #expect(motivo.deveGravarNoHealthKit)
    }

    @Test("Só o descarte por curto não vai para o HealthKit (regra 11.11)")
    func oQueVaiParaOHealthKit() {
        #expect(MotivoEncerramento.concluido.deveGravarNoHealthKit)
        #expect(MotivoEncerramento.encerrado_antes.deveGravarNoHealthKit)
        #expect(!MotivoEncerramento.descartado_curto.deveGravarNoHealthKit)
        // `falhou` TENTOU gravar e não conseguiu — a intenção era gravar.
        #expect(MotivoEncerramento.falhou.deveGravarNoHealthKit)
    }

    // MARK: - O contador denormalizado (regra 11.13)

    private func cenario() throws -> (ModelContext, WorkoutRepository, Treino) {
        let contexto = ModelContext(try ModelContainer.vouNadar(emMemoria: true))
        let repo = WorkoutRepository(context: contexto)
        let treino = Treino(
            titulo: "Terça leve", origem: .gerado_iphone, distanciaTotalM: 2100,
            distanciaMinSolicitadaM: 1500, distanciaMaxSolicitadaM: 2500,
            tamanhoRaiaM: 25, ritmoDescansoUsado: .normal,
            comEducativos: false, comPernada: false, favorito: true)
        contexto.insert(treino)
        try contexto.save()
        return (contexto, repo, treino)
    }

    private func sessao(
        _ treino: Treino, em data: Date, real: Int = 2100,
        motivo: MotivoEncerramento = .concluido
    ) -> SessaoNatacao {
        SessaoNatacao(
            treino: treino, tituloSnapshot: treino.titulo, iniciadaEm: data,
            encerradaEm: data.addingTimeInterval(3600),
            distanciaPlanejadaM: 2100, distanciaRealM: real,
            seriesConcluidas: 5, repeticoesConcluidas: 18,
            healthkitWorkoutUuid: UUID(), tamanhoRaiaM: 25, motivoEncerramento: motivo)
    }

    @Test("Registrar sessão incrementa o contador e a última execução, junto")
    func registrarAtualizaOContador() throws {
        let (_, repo, treino) = try cenario()
        #expect(treino.vezesExecutado == 0)
        #expect(treino.ultimaExecucaoEm == nil)

        let quando = Date(timeIntervalSince1970: 1_700_000_000)
        try repo.registrarSessao(sessao(treino, em: quando))

        #expect(treino.vezesExecutado == 1)
        #expect(treino.ultimaExecucaoEm == quando)
    }

    @Test("Duas sessões contam duas vezes, e a última execução é a mais recente")
    func duasSessoes() throws {
        let (_, repo, treino) = try cenario()
        let antiga = Date(timeIntervalSince1970: 1_700_000_000)
        let recente = Date(timeIntervalSince1970: 1_800_000_000)

        try repo.registrarSessao(sessao(treino, em: recente))
        try repo.registrarSessao(sessao(treino, em: antiga))

        #expect(treino.vezesExecutado == 2)
        // Registrar uma sessão ANTIGA não pode fazer o treino parecer executado
        // hoje.
        #expect(treino.ultimaExecucaoEm == recente)
    }

    @Test("O contador denormalizado bate com a contagem real das sessões (regra 11.13)")
    func contadorNaoDiverge() throws {
        // É a invariante que justifica o campo existir. Se ela quebrar, a lista
        // de Favoritos mente e ninguém percebe.
        let (_, repo, treino) = try cenario()
        for indice in 0..<7 {
            try repo.registrarSessao(
                sessao(treino, em: Date(timeIntervalSince1970: 1_700_000_000 + Double(indice))))
        }
        #expect(treino.vezesExecutado == treino.sessoes.count)
        #expect(treino.vezesExecutado == 7)
    }

    @Test("Remover sessão desconta o contador e recalcula a última execução")
    func removerDesconta() throws {
        let (_, repo, treino) = try cenario()
        let antiga = Date(timeIntervalSince1970: 1_700_000_000)
        let recente = Date(timeIntervalSince1970: 1_800_000_000)
        try repo.registrarSessao(sessao(treino, em: antiga))
        let aRemover = try repo.registrarSessao(sessao(treino, em: recente))

        try repo.removerSessao(aRemover)

        #expect(treino.vezesExecutado == 1)
        // Deixar a data de uma sessão apagada seria mentira visível na tela.
        #expect(treino.ultimaExecucaoEm == antiga)
        #expect(treino.sessoes.count == 1)
    }

    @Test("Remover a última sessão zera o contador e limpa a data")
    func removerAUltima() throws {
        let (_, repo, treino) = try cenario()
        let unica = try repo.registrarSessao(
            sessao(treino, em: Date(timeIntervalSince1970: 1_700_000_000)))

        try repo.removerSessao(unica)

        #expect(treino.vezesExecutado == 0)
        #expect(treino.ultimaExecucaoEm == nil)
    }

    // MARK: - O que a sessão guarda (spec 7.9)

    @Test("A sessão guarda a distância REAL, não a planejada (regra 11.10)")
    func guardaADistanciaReal() throws {
        let (_, repo, treino) = try cenario()
        // O nadador parou em 1.200 de 2.100.
        let parcial = sessao(
            treino, em: Date(timeIntervalSince1970: 1_700_000_000), real: 1200,
            motivo: .encerrado_antes)
        try repo.registrarSessao(parcial)

        #expect(parcial.distanciaRealM == 1200)
        #expect(parcial.distanciaPlanejadaM == 2100)
        #expect(parcial.motivoEncerramento == .encerrado_antes)
    }

    @Test("O título é copiado como snapshot, para sobreviver ao arquivamento (7.9)")
    func tituloEhSnapshot() throws {
        let (_, repo, treino) = try cenario()
        let executada = sessao(treino, em: Date(timeIntervalSince1970: 1_700_000_000))
        try repo.registrarSessao(executada)

        try repo.renomear(treino, para: "Outro nome")
        try repo.arquivar(treino)

        // A sessão continua legível com o nome de quando foi executada.
        #expect(executada.tituloSnapshot == "Terça leve")
    }

    @Test("Falha de gravação preserva a sessão com uuid nulo (critério 8.9)")
    func falhaPreservaASessao() throws {
        let (contexto, repo, treino) = try cenario()
        let falhada = SessaoNatacao(
            treino: treino, tituloSnapshot: treino.titulo,
            iniciadaEm: Date(timeIntervalSince1970: 1_700_000_000),
            encerradaEm: Date(timeIntervalSince1970: 1_700_003_600),
            distanciaPlanejadaM: 2100, distanciaRealM: 2100,
            seriesConcluidas: 5, repeticoesConcluidas: 18,
            // Nulo, e permanentemente nulo (spec 7.9).
            healthkitWorkoutUuid: nil,
            tamanhoRaiaM: 25, motivoEncerramento: .falhou)
        try repo.registrarSessao(falhada)

        // "Os dados ficaram no relógio" (copy 15.13) tem que ser verdade.
        let gravadas = try contexto.fetch(FetchDescriptor<SessaoNatacao>())
        #expect(gravadas.count == 1)
        #expect(gravadas.first?.healthkitWorkoutUuid == nil)
        #expect(gravadas.first?.motivoEncerramento == .falhou)
        #expect(gravadas.first?.distanciaRealM == 2100)
        // E ela conta como execução: o treino foi nadado.
        #expect(treino.vezesExecutado == 1)
    }

    @Test("Sessão descartada por curta não chega ao banco — decisão declarada")
    func descartadaNaoEhGravada() {
        // O spec é ambíguo: a seção 7.9 lista `descartado_curto` no enum, mas a
        // copy 15.12 diz "Nada foi salvo" e a regra 11.13 incrementaria o
        // contador. Gravar faria um toque acidental de 10 m virar "Feito 1 vez"
        // na lista de Favoritos.
        //
        // O controlador não grava; este teste prende a decisão do lado do
        // domínio, que é onde ela é verificável sem aparelho.
        #expect(
            MotivoEncerramento.decidir(distanciaRealM: 10, treinoConcluido: false)
                == .descartado_curto)
        #expect(!MotivoEncerramento.descartado_curto.deveGravarNoHealthKit)
    }

    @Test("Sessão livre, sem treino associado, não quebra o contador (spec 7.9)")
    func sessaoLivre() throws {
        let (contexto, repo, _) = try cenario()
        let livre = SessaoNatacao(
            treino: nil, iniciadaEm: Date(timeIntervalSince1970: 1_700_000_000),
            encerradaEm: Date(timeIntervalSince1970: 1_700_001_800),
            distanciaPlanejadaM: 0, distanciaRealM: 800,
            tamanhoRaiaM: 25, motivoEncerramento: .concluido)
        try repo.registrarSessao(livre)

        #expect(try contexto.fetch(FetchDescriptor<SessaoNatacao>()).count == 1)
        #expect(livre.distanciaPlanejadaM == 0)
    }

    // MARK: - A semana (regra 11.16)

    @Test("A semana começa na segunda-feira, não no domingo")
    func semanaComecaNaSegunda() {
        // O padrão de `pt_BR` no `Calendar` é domingo; usar o padrão daria o
        // número errado toda segunda.
        let fuso = TimeZone(identifier: "America/Sao_Paulo")!
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = fuso

        // Uma quarta-feira qualquer.
        let quarta = calendario.date(from: DateComponents(year: 2026, month: 9, day: 9))!
        let inicio = Semana.inicio(de: quarta, fuso: fuso)

        let componentes = calendario.dateComponents([.weekday, .day], from: inicio)
        #expect(componentes.weekday == 2, "deveria ser segunda-feira")
        #expect(componentes.day == 7)
    }

    @Test("Sessão que atravessa a meia-noite conta na semana do início (regra 11.16)")
    func atravessaMeiaNoite() {
        // Quem nada 23h40 de domingo termina na segunda, e o treino é de
        // domingo — a semana que acabou, não a que começou.
        let fuso = TimeZone(identifier: "America/Sao_Paulo")!
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = fuso

        let domingoTarde = calendario.date(
            from: DateComponents(year: 2026, month: 9, day: 6, hour: 23, minute: 40))!
        let segunda = calendario.date(from: DateComponents(year: 2026, month: 9, day: 7))!

        #expect(Semana.inicio(de: domingoTarde, fuso: fuso) != Semana.inicio(de: segunda, fuso: fuso))
    }

    @Test("O eixo do gráfico tem uma entrada por semana, mesmo sem treino")
    func eixoDeSemanas() {
        // Semana sem treino tem que aparecer como barra vazia, nunca como
        // buraco no eixo (critério 8.10).
        let inicios = Semana.inicios(ultimas: 6)
        #expect(inicios.count == 6)
        #expect(inicios == inicios.sorted(), "da mais antiga para a mais recente")
        #expect(inicios.last == Semana.inicioDaSemanaAtual())
    }
}
