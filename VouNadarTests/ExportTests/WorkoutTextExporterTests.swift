import Foundation
import Testing

@testable import VouNadar

/// O texto copiado (seção 14) — critérios de aceite do épico 8.5.
///
/// O critério exige verificação **caractere a caractere**, e é literal: o
/// destino é uma caixa de mensagem do WhatsApp, onde um asterisco a mais vira
/// formatação e uma linha em branco no fim vira espaço morto. Por isso os testes
/// comparam a string inteira, e não pedaços dela.
struct WorkoutTextExporterTests {

    // MARK: - Construção de casos

    private func serie(
        _ repeticoes: Int, _ distanciaM: Int, _ nome: String,
        descanso: Int = 0, catalogoM: Int? = nil, modo: ModoExercicio = .nado
    ) -> WorkoutPresentation.SerieApresentada {
        WorkoutPresentation.SerieApresentada(
            id: "\(nome)-\(repeticoes)-\(distanciaM)",
            exercicioId: "TESTE",
            repeticoes: repeticoes,
            distanciaM: distanciaM,
            distanciaCatalogoM: catalogoM ?? distanciaM,
            nome: nome,
            descricao: "descrição de teste",
            equipamentoExigido: "nenhum",
            modo: modo,
            intensidade: .aerobico,
            descansoSeg: descanso,
            simboloDoEquipamento: nil)
    }

    private func treino(
        titulo: String? = nil,
        totalM: Int,
        raiaM: Int = 25,
        ritmo: RitmoDescanso = .normal,
        aquecimento: [WorkoutPresentation.SerieApresentada] = [],
        progressao: [WorkoutPresentation.SerieApresentada] = [],
        principal: [WorkoutPresentation.SerieApresentada] = [],
        soltura: [WorkoutPresentation.SerieApresentada] = []
    ) -> WorkoutPresentation {
        WorkoutPresentation(
            titulo: titulo,
            criadoEm: Date(timeIntervalSince1970: 1_788_000_000),
            distanciaTotalM: totalM,
            tamanhoRaiaM: raiaM,
            ritmo: ritmo,
            vezesExecutado: 0,
            secoes: [
                .init(tipo: .aquecimento, series: aquecimento),
                .init(tipo: .progressao, series: progressao),
                .init(tipo: .principal, series: principal),
                .init(tipo: .soltura, series: soltura),
            ])
    }

    // MARK: - O exemplo literal da seção 14.1

    @Test("O texto bate caractere a caractere com o exemplo da seção 14.1")
    func exemploDaSecao141() {
        // Os nomes vêm com o prefixo `NxM`, como os 226 do catálogo real, para
        // este teste também provar a limpeza do `ExerciseName`.
        let treino = treino(
            totalM: 2100,
            aquecimento: [
                serie(1, 300, "1x300 crawl leve"),
                serie(4, 50, "4x50 pernada", descanso: 20, modo: .pernada),
            ],
            progressao: [serie(6, 50, "6x50 crawl progressivo", descanso: 25)],
            principal: [
                serie(4, 100, "4x100 crawl forte", descanso: 30),
                serie(4, 75, "4x75 crawl com pull buoy", descanso: 25),
                serie(8, 25, "8x25 tiro com nadadeiras", descanso: 20),
            ],
            soltura: [serie(1, 200, "1x200 nado livre solto")])

        let esperado = """
            Vou Nadar \u{2014} 2.100 m
            Raia de 25 m \u{00B7} descanso normal

            AQUECIMENTO
            1\u{00D7}300 crawl leve
            4\u{00D7}50 pernada \u{2014} 20s

            PROGRESSÃO
            6\u{00D7}50 crawl progressivo \u{2014} 25s

            PARTE PRINCIPAL
            4\u{00D7}100 crawl forte \u{2014} 30s
            4\u{00D7}75 crawl com pull buoy \u{2014} 25s
            8\u{00D7}25 tiro com nadadeiras \u{2014} 20s

            SOLTURA
            1\u{00D7}200 nado livre solto
            """

        #expect(WorkoutTextExporter.texto(de: treino) == esperado)
    }

    // MARK: - Os três casos que o critério 8.5 nomeia

    @Test("Treino com seção vazia: a seção some inteira, cabeçalho incluído (14.2.4)")
    func secaoVaziaEhOmitida() {
        let treino = treino(
            totalM: 700,
            aquecimento: [serie(1, 300, "1x300 crawl leve")],
            // progressão e parte principal vazias
            soltura: [serie(2, 200, "2x200 solto", descanso: 45)])

        let esperado = """
            Vou Nadar \u{2014} 700 m
            Raia de 25 m \u{00B7} descanso normal

            AQUECIMENTO
            1\u{00D7}300 crawl leve

            SOLTURA
            2\u{00D7}200 solto \u{2014} 45s
            """

        let texto = WorkoutTextExporter.texto(de: treino)
        #expect(texto == esperado)
        #expect(!texto.contains("PROGRESSÃO"))
        #expect(!texto.contains("PARTE PRINCIPAL"))
    }

    @Test("Piscina de tamanho incomum: sai a distância adaptada (14.2.6)")
    func piscinaDeTamanhoIncomum() {
        // O caso do fluxo 9.3: o 4×100 do catálogo vira 4×96 numa raia de 16 m,
        // e é 4×96 que quem recebe a mensagem precisa ler.
        let treino = treino(
            totalM: 480,
            raiaM: 16,
            principal: [
                serie(4, 96, "4x100 crawl forte", descanso: 30, catalogoM: 100),
                serie(1, 96, "1x100 solto", catalogoM: 100),
            ])

        let esperado = """
            Vou Nadar \u{2014} 480 m
            Raia de 16 m \u{00B7} descanso normal

            PARTE PRINCIPAL
            4\u{00D7}96 crawl forte \u{2014} 30s
            1\u{00D7}96 solto
            """

        let texto = WorkoutTextExporter.texto(de: treino)
        #expect(texto == esperado)
        // A distância do catálogo NUNCA aparece: mostrar 100 e nadar 96 é
        // exatamente o erro que a regra 11.3 evita (risco R2b).
        #expect(!texto.contains("100"))
    }

    @Test("Treino com título: a primeira linha usa o título (14.2.1)")
    func treinoComTitulo() {
        let treino = treino(
            titulo: "Terça leve",
            totalM: 1500,
            ritmo: .longo,
            principal: [serie(3, 500, "3x500 crawl", descanso: 90)])

        let esperado = """
            Terça leve \u{2014} 1.500 m
            Raia de 25 m \u{00B7} descanso longo

            PARTE PRINCIPAL
            3\u{00D7}500 crawl \u{2014} 90s
            """

        #expect(WorkoutTextExporter.texto(de: treino) == esperado)
    }

    // MARK: - As proibições da seção 14

    @Test("Nenhuma linha em branco no fim — o WhatsApp preserva (14.2.7)")
    func semLinhaEmBrancoNoFim() {
        let texto = WorkoutTextExporter.texto(
            de: treino(totalM: 300, soltura: [serie(1, 300, "1x300 solto")]))
        #expect(!texto.hasSuffix("\n"))
        #expect(!texto.hasSuffix(" "))
    }

    @Test("O sinal de multiplicação é U+00D7, não a letra x (14.2.5)")
    func sinalDeMultiplicacaoCorreto() {
        let texto = WorkoutTextExporter.texto(
            de: treino(totalM: 200, principal: [serie(4, 50, "4x50 crawl", descanso: 20)]))
        // A linha de série usa U+00D7. A letra `x` minúscula não aparece em
        // nenhuma linha de série — mas pode aparecer dentro de um nome, então a
        // verificação é sobre a linha montada.
        let linhaDaSerie = texto.split(separator: "\n")
            .first { $0.contains("50") && $0.contains("20s") }
        #expect(linhaDaSerie?.contains("\u{00D7}") == true)
        #expect(linhaDaSerie?.hasPrefix("4\u{00D7}50") == true)
    }

    @Test("Sem markdown, sem emoji e sem URL (14.1 e 14.2.8)")
    func semLixoDeFormatacao() {
        let texto = WorkoutTextExporter.texto(
            de: treino(
                titulo: "Terça leve", totalM: 1200,
                aquecimento: [serie(1, 400, "1x400 crawl leve")],
                principal: [serie(8, 100, "8x100 crawl forte", descanso: 30)]))

        for proibido in ["*", "#", "_", "`", "http", "://", "[", "]"] {
            #expect(!texto.contains(proibido), "o texto contém \(proibido)")
        }
        // `isEmoji` é verdadeiro para os dígitos 0–9 e para `#` e `*`, que são
        // base de sequências de keycap em Unicode. Quem responde "isto é
        // desenhado como emoji" é `isEmojiPresentation`.
        let temEmoji = texto.unicodeScalars.contains { $0.properties.isEmojiPresentation }
        #expect(!temEmoji)
    }

    @Test("O separador de milhar é ponto, padrão pt-BR (14.2.1)")
    func separadorDeMilhar() {
        let texto = WorkoutTextExporter.texto(de: treino(totalM: 12500))
        #expect(texto.hasPrefix("Vou Nadar \u{2014} 12.500 m"))
    }

    @Test("Treino inteiramente vazio ainda produz o cabeçalho, sem seção nenhuma")
    func treinoVazio() {
        // Estado que a regra 11.2 permite no limite. O texto não pode virar
        // string vazia nem terminar em linha em branco.
        let texto = WorkoutTextExporter.texto(de: treino(totalM: 0))
        #expect(
            texto == "Vou Nadar \u{2014} 0 m\nRaia de 25 m \u{00B7} descanso normal")
    }

    // MARK: - A limpeza do nome (conflito entre a 14.2.5 e o catálogo)

    @Test("O prefixo NxM do nome do catálogo é removido")
    func prefixoRemovido() {
        #expect(ExerciseName.semPrefixoDeSerie("1x300 Aquecimento Leve") == "Aquecimento Leve")
        #expect(ExerciseName.semPrefixoDeSerie("4x100 Crawl Ritmo Constante") == "Crawl Ritmo Constante")
        #expect(ExerciseName.semPrefixoDeSerie("8x25 solto") == "solto")
        // Também aceita o sinal de multiplicação e espaço em volta.
        #expect(ExerciseName.semPrefixoDeSerie("6 \u{00D7} 50 Progressivo") == "Progressivo")
    }

    @Test("Nome sem prefixo passa intacto, e nome que ficaria vazio é preservado")
    func prefixoAusenteOuDegenerado() {
        #expect(ExerciseName.semPrefixoDeSerie("Crawl Ritmo Constante") == "Crawl Ritmo Constante")
        #expect(ExerciseName.semPrefixoDeSerie("Pernada com Prancha") == "Pernada com Prancha")
        // Sem nada depois do prefixo, é melhor mostrar a metragem duas vezes do
        // que mostrar nada.
        #expect(ExerciseName.semPrefixoDeSerie("4x50") == "4x50")
        #expect(ExerciseName.semPrefixoDeSerie("") == "")
    }

    @Test("Os 226 nomes do catálogo ficam não-vazios depois da limpeza")
    func catalogoInteiroSobreviveALimpeza() throws {
        let catalogo = try CatalogStore()
        for e in catalogo.allExercises {
            let limpo = ExerciseName.semPrefixoDeSerie(e.nome)
            #expect(!limpo.isEmpty, "\(e.exercicio_id) ficou vazio")
            #expect(
                limpo.range(of: #"^\d+\s*[xX\u{00D7}]\s*\d+\s"#, options: .regularExpression) == nil,
                "\(e.exercicio_id) ainda começa com metragem: \(limpo)")
        }
    }
}
