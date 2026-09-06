import Foundation
import Testing

@testable import VouNadar

/// Sincronização iPhone → Watch (regra 11.12, contrato 13.3) — critérios de
/// aceite do épico 8.6.
///
/// O que estes testes protegem: **duas metades de um contrato que vivem em
/// binários diferentes**. Um campo renomeado de um lado e não do outro não
/// quebra o build — quebra a sincronização em silêncio, e o nadador descobre no
/// vestiário que o treino não chegou.
struct SyncPayloadTests {

    // MARK: - applicationContext (contrato 13.3)

    private var estadoDeExemplo: EstadoLeve {
        EstadoLeve(
            tamanhoRaiaM: 16, raiaConfirmada: true, ritmoDescanso: .longo,
            distanciaMinM: 1500, distanciaMaxM: 2500,
            incluirEducativos: true, incluirPernada: false,
            equipamentos: ["pull_buoy", "nadadeiras"],
            prefsAtualizadoEm: Date(timeIntervalSince1970: 1_788_000_000),
            comprado: true)
    }

    @Test("O contexto tem exatamente as chaves da tabela 13.3")
    func chavesDoContexto() {
        let d = SyncPayload.dicionario(de: estadoDeExemplo)
        #expect(
            Set(d.keys) == [
                "tamanho_raia_m", "raia_confirmada", "ritmo_descanso",
                "distancia_min_m", "distancia_max_m",
                "incluir_educativos", "incluir_pernada",
                "equipamentos", "prefs_atualizado_em", "comprado",
            ])
    }

    @Test("O contexto sobrevive à ida e volta sem perder nada")
    func contextoIdaEVolta() {
        let original = estadoDeExemplo
        let lido = SyncPayload.estado(de: SyncPayload.dicionario(de: original))
        #expect(lido == original)
    }

    @Test("A data viaja como timestamp Double, não como Date (contrato 13.3)")
    func dataViajaComoTimestamp() {
        // `Date` não é tipo de property list em toda situação; mandar um
        // derrubaria a transferência inteira.
        let d = SyncPayload.dicionario(de: estadoDeExemplo)
        #expect(d["prefs_atualizado_em"] is Double)
        #expect(!(d["prefs_atualizado_em"] is Date))
    }

    @Test("O contexto cabe folgadíssimo no limite de 262.144 bytes (critério 8.6)")
    func contextoCabeFolgadoNoLimite() {
        let bytes = SyncPayload.tamanhoEmBytes(SyncPayload.dicionario(de: estadoDeExemplo))
        #expect(bytes < SyncPayload.limiteDoContexto)
        // "Folgadíssimo" é literal: o estado leve tem oito escalares e no máximo
        // quatro equipamentos. Se um dia passar de 1 KB, alguém pôs coisa demais
        // no canal errado — favorito vai por `transferUserInfo`, não por aqui.
        #expect(bytes < 1_024, "o contexto cresceu para \(bytes) bytes")
    }

    @Test("Payload incompleto é descartado inteiro, não completado com defaults")
    func payloadIncompletoEhDescartado() {
        var d = SyncPayload.dicionario(de: estadoDeExemplo)
        d.removeValue(forKey: "tamanho_raia_m")
        // Aplicar metade do contexto deixaria o relógio com a piscina de um
        // lugar e o ritmo de outro.
        #expect(SyncPayload.estado(de: d) == nil)
    }

    @Test("Ritmo desconhecido invalida o contexto em vez de virar `normal`")
    func ritmoDesconhecidoInvalida() {
        var d = SyncPayload.dicionario(de: estadoDeExemplo)
        d["ritmo_descanso"] = "altissimo"
        #expect(SyncPayload.estado(de: d) == nil)
    }

    @Test("A lista de equipamentos sai ordenada, para o contexto ser estável")
    func equipamentosOrdenados() {
        // Sem isto, o mesmo estado geraria dicionários diferentes entre
        // execuções e o app escreveria contexto à toa.
        let primeiro = SyncPayload.dicionario(de: estadoDeExemplo)["equipamentos"] as? [String]
        let segundo = SyncPayload.dicionario(de: estadoDeExemplo)["equipamentos"] as? [String]
        #expect(primeiro == segundo)
        #expect(primeiro == ["nadadeiras", "pull_buoy"])
    }

    // MARK: - Favoritos por transferUserInfo (regra 11.12)

    /// Um favorito sintético com `series` séries por seção.
    private func favorito(indice: Int, seriesPorSecao: Int = 3) -> WorkoutTransfer {
        WorkoutTransfer(
            id: UUID(),
            titulo: "Treino \(indice) com um título de tamanho realista",
            distanciaTotalM: 2100,
            tamanhoRaiaM: 25,
            ritmoDescansoUsado: .normal,
            atualizadoEm: Date(timeIntervalSince1970: 1_788_000_000 + Double(indice)),
            secoes: TipoSecao.allCases.map { tipo in
                WorkoutTransfer.SecaoTransferivel(
                    tipoSecao: tipo, ordem: tipo.ordem, descansoPosSecaoSeg: 45,
                    series: (1...seriesPorSecao).map { ordem in
                        WorkoutTransfer.SerieTransferivel(
                            exercicioId: "FS_04x100_STEADY", repeticoes: 4, distanciaM: 100,
                            metrosTotais: 400, descansoSeg: 30, descansoPosSerieSeg: 30,
                            voltasPorRepeticao: 4,
                            nomeSnapshot: "4x100 Crawl Ritmo Constante", modo: .nado, ordem: ordem)
                    })
            })
    }

    @Test("Um treino sobrevive à ida e volta com descanso e voltas intactos")
    func treinoIdaEVolta() {
        let original = favorito(indice: 1)
        let lido = WorkoutTransfer(dicionario: original.dicionario)
        #expect(lido == original)

        // Os três campos que a execução no relógio depende (regras 11.5 e 11.7).
        let serie = lido?.secoes.first?.series.first
        #expect(serie?.descansoSeg == 30)
        #expect(serie?.voltasPorRepeticao == 4)
        #expect(serie?.distanciaM == 100)
    }

    @Test("Poucos favoritos vão num lote só")
    func casoComumEhUmLoteSo() {
        let lotes = FavoritesSync.lotes(de: (1...5).map { favorito(indice: $0) })
        #expect(lotes.count == 1)
        #expect(lotes[0]["lote"] as? Int == 1)
        #expect(lotes[0]["total_lotes"] as? Int == 1)
        #expect(lotes[0]["tipo"] as? String == "favoritos")
    }

    @Test("500 favoritos: NENHUM lote passa de 65.536 bytes (critério 8.6)")
    func quinhentosFavoritosRespeitamOLimite() {
        // O número vem direto da seção 22 do spec, e o limite da regra 11.12.
        let lotes = FavoritesSync.lotes(de: (1...500).map { favorito(indice: $0) })

        #expect(lotes.count > 1, "500 favoritos deveriam exigir mais de um lote")

        for (indice, lote) in lotes.enumerated() {
            let bytes = SyncPayload.tamanhoEmBytes(lote)
            #expect(
                bytes <= FavoritesSync.limiteDeTransferencia,
                "lote \(indice + 1) tem \(bytes) bytes, acima de 65.536")
        }
    }

    @Test("Favoritos longos também respeitam o limite")
    func favoritosLongosRespeitamOLimite() {
        // 12 séries por seção, 48 séries por treino: o pior caso plausível. É
        // por isso que a divisão é por tamanho medido e não por contagem.
        let lotes = FavoritesSync.lotes(de: (1...200).map { favorito(indice: $0, seriesPorSecao: 12) })
        for lote in lotes {
            #expect(SyncPayload.tamanhoEmBytes(lote) <= FavoritesSync.limiteDeTransferencia)
        }
    }

    @Test("A numeração dos lotes é contígua e o total bate")
    func numeracaoDosLotes() {
        let lotes = FavoritesSync.lotes(de: (1...500).map { favorito(indice: $0) })
        for (indice, lote) in lotes.enumerated() {
            #expect(lote["lote"] as? Int == indice + 1)
            #expect(lote["total_lotes"] as? Int == lotes.count)
        }
    }

    @Test("Nenhum favorito se perde na divisão em lotes")
    func nenhumFavoritoSePerde() {
        let originais = (1...500).map { favorito(indice: $0) }
        let recebidos = FavoritesSync.lotes(de: originais)
            .compactMap(FavoritesSync.lerLote)
            .flatMap(\.treinos)

        #expect(recebidos.count == originais.count)
        #expect(Set(recebidos.map(\.id)) == Set(originais.map(\.id)))
    }

    @Test("Desfavoritar tudo manda um lote vazio, que substitui o conjunto por nada")
    func listaVaziaAindaGeraLote() {
        // É assim que "desfavoritei o último treino" chega ao relógio
        // (critério 8.6). Não mandar nada deixaria o favorito órfão lá para
        // sempre.
        let lotes = FavoritesSync.lotes(de: [])
        #expect(lotes.count == 1)
        #expect((lotes[0]["treinos"] as? [[String: Any]])?.isEmpty == true)
        #expect(FavoritesSync.lerLote(lotes[0])?.treinos.isEmpty == true)
    }

    @Test("Um payload que não é de favoritos é ignorado")
    func payloadDeOutroTipoEhIgnorado() {
        #expect(FavoritesSync.lerLote(["tipo": "outra_coisa"]) == nil)
        #expect(FavoritesSync.lerLote([:]) == nil)
    }

    @Test("Treino com seção corrompida é descartado, não guardado pela metade")
    func treinoCorrompidoEhDescartado() {
        var d = favorito(indice: 1).dicionario
        var secoes = d["secoes"] as! [[String: Any]]
        secoes[0].removeValue(forKey: "descanso_pos_secao_seg")
        d["secoes"] = secoes
        #expect(WorkoutTransfer(dicionario: d) == nil)
    }

    @Test("A descrição do exercício NÃO viaja — o relógio não a mostra")
    func descricaoNaoViaja() {
        // É o campo mais pesado do catálogo, e o limite de 65.536 bytes é o
        // recurso mais escasso desta rotina.
        let d = favorito(indice: 1).dicionario
        let serie = ((d["secoes"] as! [[String: Any]])[0]["series"] as! [[String: Any]])[0]
        #expect(serie["descricao_snapshot"] == nil)
        #expect(serie["descricao"] == nil)
    }
}

/// Remontagem dos lotes recebidos (regra 11.12) — a metade do relógio.
///
/// Separada porque o que ela protege é diferente: não é o **formato** do dado,
/// é o **comportamento da fila**. O `transferUserInfo` não garante ordem e pode
/// intercalar transferências, e os dois casos produzem uma lista errada em
/// silêncio se ninguém os tratar.
struct FavoritesBatchAssemblerTests {

    private func favorito(_ indice: Int) -> WorkoutTransfer {
        WorkoutTransfer(
            id: UUID(), titulo: "Treino \(indice)", distanciaTotalM: 2100,
            tamanhoRaiaM: 25, ritmoDescansoUsado: .normal,
            atualizadoEm: Date(timeIntervalSince1970: 1_788_000_000),
            secoes: [
                .init(
                    tipoSecao: .principal, ordem: 3, descansoPosSecaoSeg: 0,
                    series: [
                        .init(
                            exercicioId: "FS_04x100_STEADY", repeticoes: 4, distanciaM: 100,
                            metrosTotais: 400, descansoSeg: 30, descansoPosSerieSeg: 0,
                            voltasPorRepeticao: 4, nomeSnapshot: "4x100 Crawl", modo: .nado,
                            ordem: 1)
                    ])
            ])
    }

    @Test("Um lote único fecha o conjunto na hora")
    func loteUnico() {
        var montador = FavoritesBatchAssembler()
        let lotes = FavoritesSync.lotes(de: [favorito(1), favorito(2)])
        #expect(montador.receber(lotes[0])?.count == 2)
    }

    @Test("O conjunto só é entregue quando TODOS os lotes chegam")
    func conjuntoParcialNaoEhEntregue() {
        var montador = FavoritesBatchAssembler()
        let lotes = FavoritesSync.lotes(de: (1...500).map(favorito))
        #expect(lotes.count > 1)

        for lote in lotes.dropLast() {
            // Aplicar um lote parcial deixaria o relógio com um terço da lista
            // e sem saber disso.
            #expect(montador.receber(lote) == nil)
        }
        #expect(montador.receber(lotes.last!)?.count == 500)
    }

    @Test("Lotes fora de ordem montam a lista certa — a fila não garante ordem")
    func lotesForaDeOrdem() {
        var montador = FavoritesBatchAssembler()
        let originais = (1...500).map(favorito)
        let lotes = FavoritesSync.lotes(de: originais)

        var resultado: [WorkoutTransfer]?
        for lote in lotes.reversed() {
            if let completo = montador.receber(lote) { resultado = completo }
        }
        #expect(resultado?.count == 500)
        // E na ordem original, não na de chegada.
        #expect(resultado?.map(\.titulo) == originais.map(\.titulo))
    }

    @Test("Lote repetido é idempotente")
    func loteRepetido() {
        var montador = FavoritesBatchAssembler()
        let lotes = FavoritesSync.lotes(de: (1...500).map(favorito))

        _ = montador.receber(lotes[0])
        _ = montador.receber(lotes[0])
        for lote in lotes.dropFirst().dropLast() { _ = montador.receber(lote) }
        #expect(montador.receber(lotes.last!)?.count == 500)
    }

    @Test("Transferência nova descarta a anterior pela metade")
    func transferenciaNovaInvalidaAAnterior() {
        // O usuário favorita de novo enquanto a leva anterior ainda chega.
        // Misturar as duas produziria uma lista que nunca existiu.
        var montador = FavoritesBatchAssembler()
        let antiga = FavoritesSync.lotes(de: (1...500).map(favorito))
        _ = montador.receber(antiga[0])

        let nova = FavoritesSync.lotes(de: [favorito(999)])
        #expect(montador.receber(nova[0])?.count == 1)
        #expect(montador.lotesRecebidos == 0)
    }

    @Test("Lote vazio substitui o conjunto por nada (desfavoritar o último)")
    func loteVazio() {
        var montador = FavoritesBatchAssembler()
        let lotes = FavoritesSync.lotes(de: [])
        #expect(montador.receber(lotes[0])?.isEmpty == true)
    }

    @Test("Payload estranho é ignorado sem sujar o estado")
    func payloadEstranhoEhIgnorado() {
        var montador = FavoritesBatchAssembler()
        #expect(montador.receber(["tipo": "outra_coisa"]) == nil)
        #expect(montador.receber(["tipo": "favoritos", "lote": 0, "total_lotes": 2, "treinos": []]) == nil)
        #expect(montador.receber(["tipo": "favoritos", "lote": 5, "total_lotes": 2, "treinos": []]) == nil)
        #expect(montador.lotesRecebidos == 0)
    }
}
