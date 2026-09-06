import Foundation
import SwiftData

/// Uma execução real na água (spec 7.9).
///
/// Nasce no relógio. É o registro do que **aconteceu**, distinto do treino
/// **planejado** — e essa distinção é o motivo de a entidade existir: o nadador
/// pode parar em 1.200 m de 2.100 m, e o histórico tem que contar a verdade.
///
/// Exclusão é **hard delete**, e só pelo iPhone (spec 7.10): o caso de uso é o
/// usuário que registrou errado e quer desfazer. O `HKWorkout` correspondente
/// **não** é apagado junto — é dado de saúde do usuário, e sai pelo app Saúde,
/// não por aqui (seção 20).
@Model
final class SessaoNatacao {

    @Attribute(.unique, originalName: "id")
    var id: UUID

    /// Nulo em sessão livre, sem treino associado (spec 7.9).
    @Relationship(originalName: "treino_id")
    var treino: Treino?

    /// Cópia do título no momento da execução.
    ///
    /// Existe para o Histórico sobreviver ao arquivamento do treino: mesmo com
    /// soft delete o vínculo se mantém, mas o snapshot garante que a linha
    /// continue legível se o treino for apagado de verdade (regra 11.15).
    @Attribute(originalName: "titulo_snapshot")
    var tituloSnapshot: String?

    /// Indexado — o Histórico ordena por ele (spec 7.11). A semana de uma
    /// sessão que atravessa a meia-noite é a do `iniciada_em` (regra 11.16).
    @Attribute(originalName: "iniciada_em")
    var iniciadaEm: Date

    /// Nulo enquanto em andamento ou pausada (spec 7.9).
    @Attribute(originalName: "encerrada_em")
    var encerradaEm: Date?

    /// Zero em sessão livre.
    @Attribute(originalName: "distancia_planejada_m")
    var distanciaPlanejadaM: Int = 0

    /// Medida pelo HealthKit. **É o que vai para o `HKWorkout`, nunca o
    /// planejado** (regra 11.10 e critério 8.9).
    @Attribute(originalName: "distancia_real_m")
    var distanciaRealM: Int = 0

    @Attribute(originalName: "series_concluidas")
    var seriesConcluidas: Int = 0

    /// Granularidade fina, para o resumo dizer "parou no meio do 3º de 4×100"
    /// (spec 7.9).
    @Attribute(originalName: "repeticoes_concluidas")
    var repeticoesConcluidas: Int = 0

    /// Nulo até gravar com sucesso, e **permanentemente nulo se a gravação
    /// falhar** — nesse caso `motivo_encerramento` fica `falhou` e o usuário é
    /// avisado pela copy 15.13 (spec 7.9 e critério 8.9).
    @Attribute(originalName: "healthkit_workout_uuid")
    var healthkitWorkoutUuid: UUID?

    /// Congelado no início da sessão. Trocar de piscina depois não altera
    /// histórico (spec 7.9).
    @Attribute(originalName: "tamanho_raia_m")
    var tamanhoRaiaM: Int

    /// Nulo enquanto em andamento. Os quatro valores são os quatro finais da
    /// máquina de estados 12.2.
    @Attribute(originalName: "motivo_encerramento")
    var motivoEncerramento: MotivoEncerramento?

    init(
        id: UUID = UUID(),
        treino: Treino? = nil,
        tituloSnapshot: String? = nil,
        iniciadaEm: Date,
        encerradaEm: Date? = nil,
        distanciaPlanejadaM: Int = 0,
        distanciaRealM: Int = 0,
        seriesConcluidas: Int = 0,
        repeticoesConcluidas: Int = 0,
        healthkitWorkoutUuid: UUID? = nil,
        tamanhoRaiaM: Int,
        motivoEncerramento: MotivoEncerramento? = nil
    ) {
        self.id = id
        self.treino = treino
        self.tituloSnapshot = tituloSnapshot
        self.iniciadaEm = iniciadaEm
        self.encerradaEm = encerradaEm
        self.distanciaPlanejadaM = distanciaPlanejadaM
        self.distanciaRealM = distanciaRealM
        self.seriesConcluidas = seriesConcluidas
        self.repeticoesConcluidas = repeticoesConcluidas
        self.healthkitWorkoutUuid = healthkitWorkoutUuid
        self.tamanhoRaiaM = tamanhoRaiaM
        self.motivoEncerramento = motivoEncerramento
    }
}

extension SessaoNatacao {

    /// Sessão ainda aberta: começou e não terminou (máquina de estados 12.2).
    var estaEmAndamento: Bool { encerradaEm == nil }

    /// Duração da sessão, ou `nil` enquanto ela não terminou.
    var duracao: TimeInterval? {
        encerradaEm.map { $0.timeIntervalSince(iniciadaEm) }
    }

    /// Distância mínima para a sessão ser gravada no HealthKit, em metros
    /// (regra 11.11, assunção 24.4).
    ///
    /// Abaixo disso a sessão é descartada com `descartado_curto` e nenhum
    /// `HKWorkout` é criado, para não poluir o histórico de saúde com toque
    /// acidental.
    static let distanciaMinimaParaGravar = 25
}
