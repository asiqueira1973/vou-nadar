import Foundation
import Testing

@testable import VouNadar

/// Volume por semana (regra 11.16) — critérios de aceite do épico 8.10.
///
/// A agregação é o que erra com mais facilidade: semana começando no dia errado,
/// sessão que atravessa a meia-noite caindo na semana errada, semana vazia
/// sumindo do eixo. Nada disso precisa de aparelho para ser verificado, e nada
/// disso é visível olhando a tela — um gráfico com a semana errada parece
/// perfeitamente normal.
struct VolumeSemanalTests {

    private let fuso = TimeZone(identifier: "America/Sao_Paulo")!

    private var calendario: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = fuso
        return c
    }

    private func data(_ ano: Int, _ mes: Int, _ dia: Int, _ hora: Int = 12, _ minuto: Int = 0)
        -> Date
    {
        calendario.date(
            from: DateComponents(year: ano, month: mes, day: dia, hour: hora, minute: minuto))!
    }

    private func sessao(_ quando: Date, _ metros: Int, externa: Bool = false)
        -> SessaoDoHistorico
    {
        SessaoDoHistorico(
            id: UUID(), iniciadaEm: quando, duracao: 3600, distanciaM: metros,
            titulo: externa ? nil : "Terça leve", origemExterna: externa)
    }

    // MARK: - A semana (regra 11.16)

    @Test("A semana começa na SEGUNDA, não no domingo")
    func semanaComecaNaSegunda() {
        // O padrão de `pt_BR` no `Calendar` é domingo. Usar o padrão jogaria
        // toda sessão de domingo para a semana seguinte, e o número ficaria
        // errado uma vez por semana — sem nada na tela denunciando.
        let quarta = data(2026, 9, 9)
        let inicio = Semana.inicio(de: quarta, fuso: fuso)
        let componentes = calendario.dateComponents([.weekday, .day, .hour], from: inicio)

        #expect(componentes.weekday == 2)
        #expect(componentes.day == 7)
        #expect(componentes.hour == 0, "a semana começa na meia-noite")
    }

    @Test("Domingo pertence à semana que ACABA, não à que começa")
    func domingoEhFimDeSemana() {
        // 6/9/2026 é domingo; 7/9 é segunda.
        let domingo = data(2026, 9, 6, 23, 40)
        let segunda = data(2026, 9, 7, 6, 0)

        #expect(Semana.inicio(de: domingo, fuso: fuso) == data(2026, 8, 31, 0, 0))
        #expect(Semana.inicio(de: segunda, fuso: fuso) == data(2026, 9, 7, 0, 0))
    }

    @Test("Sessão que atravessa a meia-noite conta na semana do início")
    func atravessaMeiaNoite() {
        // Quem entra na água 23h40 de domingo sai na segunda. O treino é de
        // domingo — a `duracao` não muda a semana, só o `iniciada_em`.
        let sessoes = [sessao(data(2026, 9, 6, 23, 40), 1500)]
        let semanas = VolumeSemanal.porSemana(
            sessoes, quantidade: 3, agora: data(2026, 9, 9), fuso: fuso)

        let semanaDoDomingo = semanas.first { $0.inicio == data(2026, 8, 31, 0, 0) }
        #expect(semanaDoDomingo?.metrosM == 1500)

        let semanaSeguinte = semanas.first { $0.inicio == data(2026, 9, 7, 0, 0) }
        #expect(semanaSeguinte?.metrosM == 0)
    }

    // MARK: - A agregação

    @Test("Soma as sessões da mesma semana")
    func somaDaSemana() {
        let sessoes = [
            sessao(data(2026, 9, 7), 1500),
            sessao(data(2026, 9, 9), 2100),
            sessao(data(2026, 9, 11), 1800),
        ]
        let semanas = VolumeSemanal.porSemana(
            sessoes, quantidade: 2, agora: data(2026, 9, 11), fuso: fuso)
        #expect(semanas.last?.metrosM == 5400)
    }

    @Test("Semana sem treino aparece como barra VAZIA, nunca como buraco no eixo")
    func semanaVaziaApareceNoEixo() {
        // É o critério 8.10 literal. Um buraco faria o gráfico mentir sobre o
        // intervalo; a semana parada é informação, não ausência dela.
        let sessoes = [sessao(data(2026, 9, 9), 2000)]
        let semanas = VolumeSemanal.porSemana(
            sessoes, quantidade: 6, agora: data(2026, 9, 11), fuso: fuso)

        #expect(semanas.count == 6, "seis entradas, mesmo com uma sessão só")
        #expect(semanas.count { $0.estaVazia } == 5)
        #expect(semanas.last?.estaVazia == false)
    }

    @Test("As semanas vêm da mais antiga para a mais recente")
    func ordemDoEixo() {
        let semanas = VolumeSemanal.porSemana(
            [], quantidade: 6, agora: data(2026, 9, 11), fuso: fuso)
        #expect(semanas.map(\.inicio) == semanas.map(\.inicio).sorted())
        #expect(semanas.last?.inicio == data(2026, 9, 7, 0, 0))
    }

    @Test("Sessão fora da janela não entra em semana nenhuma")
    func foraDaJanela() {
        let antiga = sessao(data(2026, 1, 5), 9999)
        let semanas = VolumeSemanal.porSemana(
            [antiga], quantidade: 6, agora: data(2026, 9, 11), fuso: fuso)
        let todasVazias = semanas.allSatisfy(\.estaVazia)
        #expect(todasVazias)
    }

    // MARK: - Os números soltos

    @Test("O volume da semana atual soma só o que veio da segunda para cá")
    func volumeDaSemanaAtual() {
        let agora = data(2026, 9, 11)
        let sessoes = [
            sessao(data(2026, 9, 7), 1500),  // esta semana
            sessao(data(2026, 9, 10), 2000),  // esta semana
            sessao(data(2026, 9, 6), 9999),  // domingo: semana passada
        ]
        #expect(VolumeSemanal.daSemanaAtual(sessoes, agora: agora, fuso: fuso) == 3500)
    }

    @Test("A média semanal INCLUI as semanas vazias no divisor")
    func mediaIncluiSemanasVazias() {
        // Uma média que ignora as semanas paradas é média de "quando eu treino",
        // não de constância — e constância é o que o nadador amador quer ver.
        let semanas = [
            SemanaDeVolume(inicio: data(2026, 8, 3), metrosM: 6000),
            SemanaDeVolume(inicio: data(2026, 8, 10), metrosM: 0),
            SemanaDeVolume(inicio: data(2026, 8, 17), metrosM: 0),
            SemanaDeVolume(inicio: data(2026, 8, 24), metrosM: 6000),
        ]
        #expect(VolumeSemanal.mediaSemanal(semanas) == 3000)
    }

    @Test("Média de lista vazia é zero, sem dividir por zero")
    func mediaDeListaVazia() {
        #expect(VolumeSemanal.mediaSemanal([]) == 0)
    }

    // MARK: - Origem externa (critério 8.10)

    @Test("Treino de outro app entra no volume igual aos nossos")
    func externoEntraNoVolume() {
        // O HealthKit é do usuário, não do Vou Nadar: se ele nadou com outro
        // app, isso é volume dele. Filtrar seria o app decidindo o que conta
        // como natação na vida de alguém.
        let sessoes = [
            sessao(data(2026, 9, 9), 1500),
            sessao(data(2026, 9, 10), 2000, externa: true),
        ]
        let semanas = VolumeSemanal.porSemana(
            sessoes, quantidade: 2, agora: data(2026, 9, 11), fuso: fuso)
        #expect(semanas.last?.metrosM == 3500)
    }

    @Test("Treino de outro app não tem título — ele não tem como saber disso")
    func externoNaoTemTitulo() {
        let externa = sessao(data(2026, 9, 9), 2000, externa: true)
        #expect(externa.titulo == nil)
        #expect(externa.origemExterna)
    }

    // MARK: - Fuso horário

    @Test("O fuso é o do aparelho, e mudar de fuso muda a semana (regra 11.16)")
    func fusoDoAparelho() {
        // Uma sessão de segunda-feira 00h30 em São Paulo é ainda domingo em
        // Los Angeles. A regra 11.16 diz "fuso do aparelho no momento da
        // consulta" — este teste prende esse comportamento em vez de deixá-lo
        // acontecer por acidente.
        let saoPaulo = TimeZone(identifier: "America/Sao_Paulo")!
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

        var cSaoPaulo = Calendar(identifier: .gregorian)
        cSaoPaulo.timeZone = saoPaulo
        let segundaDeMadrugada = cSaoPaulo.date(
            from: DateComponents(year: 2026, month: 9, day: 7, hour: 0, minute: 30))!

        #expect(
            Semana.inicio(de: segundaDeMadrugada, fuso: saoPaulo)
                != Semana.inicio(de: segundaDeMadrugada, fuso: losAngeles))
    }
}
