import Foundation
import Testing

@testable import VouNadar

/// A adaptação da distância à raia (regra 11.3).
///
/// Junto com a tabela de descanso, é o núcleo do produto. Esta suíte é a
/// varredura que o Definition of Done (seção 26) exige: os 226 exercícios nas
/// oito piscinas da tabela de "11.3 detalhado", com **as contagens batendo**.
///
/// A razão de as contagens serem testadas, e não só as invariantes: elas são a
/// única prova de que a guarda de desvio de 25% (assunção 24.3b) continua
/// calibrada. Se um catálogo futuro mudar as distâncias, ou se a guarda for
/// mexida para responder a Q6, estes números mudam — e a mudança tem que ser
/// vista e aceita, não descoberta na borda da piscina.
struct LaneAdapterTests {

    private func catalogo() throws -> CatalogStore { try CatalogStore() }

    /// Quantos dos 226 exercícios sobrevivem à guarda de desvio numa raia.
    private func utilizaveis(em raia: Int, _ catalogo: CatalogStore) -> Int {
        catalogo.allExercises.count { LaneAdapter.podeSerSorteado($0, tamanhoRaiaM: raia) }
    }

    // MARK: - A tabela de cobertura de "11.3 detalhado"

    @Test(
        "Cobertura por raia bate com a tabela de 11.3 detalhado",
        arguments: [
            (raia: 10, utilizaveis: 226),
            (raia: 12, utilizaveis: 226),
            (raia: 15, utilizaveis: 226),
            (raia: 16, utilizaveis: 205),
            (raia: 18, utilizaveis: 205),
            (raia: 20, utilizaveis: 226),
            (raia: 25, utilizaveis: 226),
            (raia: 50, utilizaveis: 203),
        ])
    func coberturaPorRaia(caso: (raia: Int, utilizaveis: Int)) throws {
        let catalogo = try catalogo()
        #expect(
            utilizaveis(em: caso.raia, catalogo) == caso.utilizaveis,
            "raia de \(caso.raia) m: o spec diz \(caso.utilizaveis) utilizáveis")
    }

    @Test("Raia de 33 m derruba 93 dos 226, restando 133 (11.3 detalhado)")
    func piscinaRuimParaEsteCatalogo() throws {
        // O spec chama esta de "piscina ruim para este catálogo": quase nenhuma
        // distância do catálogo se aproxima de um múltiplo de 33. É rara o
        // bastante para não tratar no v1, mas é ela que justifica o aviso de
        // repertório curto da regra 11.19.
        let catalogo = try catalogo()
        #expect(utilizaveis(em: 33, catalogo) == 133)
        #expect(catalogo.allExercises.count - utilizaveis(em: 33, catalogo) == 93)
    }

    @Test("Em raia de 25 m a adaptação nunca dispara (11.3 detalhado)")
    func raiaDeVinteECincoNaoAdapta() throws {
        // Todas as distâncias do catálogo são múltiplos de 25, então o desvio é
        // zero em todas — é a piscina para a qual o catálogo foi escrito.
        let catalogo = try catalogo()
        for e in catalogo.allExercises {
            let adaptada = LaneAdapter.distanciaAdaptadaM(
                distanciaCatalogoM: e.distancia_m, tamanhoRaiaM: 25)
            #expect(adaptada == e.distancia_m, "\(e.exercicio_id) mudou numa piscina de 25 m")
        }
    }

    @Test("Em raia de 16 m saem exatamente os 21 blocos de 25 m (fluxo 9.3)")
    func blocosDeVinteECincoSaemEmDezesseis() throws {
        let catalogo = try catalogo()
        let removidos = catalogo.allExercises.filter {
            !LaneAdapter.podeSerSorteado($0, tamanhoRaiaM: 16)
        }
        #expect(removidos.count == 21)
        // 25 m em raia de 16 m daria 2 voltas, 32 m — desvio de 28%, que
        // estoura a guarda de 25%.
        #expect(removidos.allSatisfy { $0.distancia_m == 25 })
    }

    @Test("Em raia de 50 m saem os 21 blocos de 25 m e os 2 de 75 m (fluxo 9.3)")
    func blocosCurtosSaemEmCinquenta() throws {
        let catalogo = try catalogo()
        let removidos = catalogo.allExercises.filter {
            !LaneAdapter.podeSerSorteado($0, tamanhoRaiaM: 50)
        }
        #expect(removidos.count == 23)
        #expect(removidos.count { $0.distancia_m == 25 } == 21)
        #expect(removidos.count { $0.distancia_m == 75 } == 2)
    }

    @Test("12 dos 32 educativos são blocos de 25 m — a base do risco R2")
    func educativosCurtos() throws {
        let catalogo = try catalogo()
        let educativos = catalogo.allExercises.filter { $0.modo == .educativo }
        #expect(educativos.count == 32)
        #expect(educativos.count { $0.distancia_m == 25 } == 12)
        // Numa piscina olímpica esses 12 saem, e o repertório de técnica
        // encolhe. Aceito no v1 (resposta à Q4); mitigado pela regra 11.19.
        #expect(educativos.count { LaneAdapter.podeSerSorteado($0, tamanhoRaiaM: 50) } == 20)
    }

    // MARK: - Invariantes da fórmula (regra 11.3)

    @Test("A distância adaptada é sempre múltiplo exato da raia (regra 11.3)")
    func distanciaSempreMultiploDaRaia() throws {
        // É esta propriedade que faz a contagem de voltas do relógio fechar
        // (regra 11.7). Sem ela a repetição nunca terminaria num número inteiro
        // de voltas, e o descanso nunca começaria.
        let catalogo = try catalogo()
        for raia in Preferencias.faixaDeRaia {
            for e in catalogo.allExercises {
                let adaptada = LaneAdapter.distanciaAdaptadaM(
                    distanciaCatalogoM: e.distancia_m, tamanhoRaiaM: raia)
                #expect(
                    adaptada % raia == 0,
                    "\(e.exercicio_id) em raia de \(raia) m: \(adaptada) não é múltiplo")
            }
        }
    }

    @Test("voltas_por_repeticao é sempre 1 ou mais (regra 11.3)")
    func voltasSempreAoMenosUma() throws {
        // O piso de 1 protege a piscina grande: um bloco de 25 m em raia de
        // 50 m daria meia volta, e meia volta o relógio não conta.
        let catalogo = try catalogo()
        for raia in Preferencias.faixaDeRaia {
            for e in catalogo.allExercises {
                let voltas = LaneAdapter.voltasPorRepeticao(
                    distanciaCatalogoM: e.distancia_m, tamanhoRaiaM: raia)
                #expect(voltas >= 1, "\(e.exercicio_id) em raia de \(raia) m: \(voltas) voltas")
            }
        }
    }

    @Test("Nenhum exercício sorteável passa de 25% de desvio (regra 11.3)")
    func nenhumSorteavelEstouraAGuarda() throws {
        let catalogo = try catalogo()
        for raia in Preferencias.faixaDeRaia {
            for e in catalogo.allExercises
            where LaneAdapter.podeSerSorteado(e, tamanhoRaiaM: raia) {
                let adaptada = LaneAdapter.distanciaAdaptadaM(
                    distanciaCatalogoM: e.distancia_m, tamanhoRaiaM: raia)
                let desvio = LaneAdapter.desvio(
                    distanciaCatalogoM: e.distancia_m, distanciaAdaptadaM: adaptada)
                #expect(
                    desvio <= LaneAdapter.desvioMaximo,
                    "\(e.exercicio_id) em raia de \(raia) m: desvio de \(desvio)")
            }
        }
    }

    @Test("Toda raia de 10 a 50 m deixa ao menos um exercício sorteável")
    func nenhumaRaiaFicaSemRepertorio() throws {
        // Nenhuma piscina suportada pode ficar sem nenhum exercício: a regra
        // 11.19 avisa quando sobram poucos, mas geração impossível não é
        // estado aceitável em piscina nenhuma da faixa de 24.3.
        let catalogo = try catalogo()
        for raia in Preferencias.faixaDeRaia {
            #expect(utilizaveis(em: raia, catalogo) > 0, "raia de \(raia) m ficou sem repertório")
        }
    }

    // MARK: - Os exemplos nomeados no spec

    @Test("O 4×100 do catálogo vira 4×96 m numa piscina de 16 m (fluxo 9.3)")
    func exemploDoFluxo93() {
        // O exemplo que o spec usa para explicar a adaptação, e o que a copy
        // 15.18 precisa justificar para o usuário não achar que o app errou.
        #expect(
            LaneAdapter.voltasPorRepeticao(distanciaCatalogoM: 100, tamanhoRaiaM: 16) == 6)
        #expect(
            LaneAdapter.distanciaAdaptadaM(distanciaCatalogoM: 100, tamanhoRaiaM: 16) == 96)
    }

    @Test("Um bloco de 25 m em raia de 20 m vira uma volta, 20 m (11.3 detalhado)")
    func piorCasoEmVinte() {
        #expect(LaneAdapter.distanciaAdaptadaM(distanciaCatalogoM: 25, tamanhoRaiaM: 20) == 20)
        // Desvio de 20%: passa raspando na guarda de 25%, e é por isso que a
        // raia de 20 m mantém os 226.
        #expect(LaneAdapter.podeSerSorteado(exercicioDe25m, tamanhoRaiaM: 20))
    }

    @Test("Um bloco de 25 m em raia de 16 m daria 32 m — 28% de desvio, sai (11.3 detalhado)")
    func piorCasoEmDezesseis() {
        #expect(LaneAdapter.distanciaAdaptadaM(distanciaCatalogoM: 25, tamanhoRaiaM: 16) == 32)
        #expect(!LaneAdapter.podeSerSorteado(exercicioDe25m, tamanhoRaiaM: 16))
    }

    /// Um exercício sintético de 25 m por repetição, para os casos de fronteira
    /// da guarda que não dependem de um registro específico do catálogo.
    private var exercicioDe25m: ExercicioCatalogo {
        ExercicioCatalogo(
            exercicio_id: "TESTE_01x25", nome: "1×25", descricao: "sintético",
            repeticoes: 1, distancia_m: 25, metros_totais: 25,
            intensidade: .aerobico, tipo_controle: .constante,
            equipamento_exigido: "nenhum", modo: .nado, nado: .livre,
            ativo: true, adicionado_na_versao: 1)
    }
}
