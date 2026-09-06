import Foundation
import HealthKit
import SwiftUI
import WatchKit

/// Conduz a execução guiada na água (épico 8.8, máquina 12.2).
///
/// Recebe: o treino a executar.
/// Escreve: a `sessao_natacao` local e, no fim, o `HKWorkout` (épico 8.9).
///
/// ## O que esta classe é, e o que ela não é
///
/// Ela é a **casca** em volta do `ExecutionEngine`. Toda a regra — quando a
/// repetição acaba, qual descanso vale, que háptico disparar — vive no motor
/// puro e está testada sem aparelho. Aqui só acontece o que precisa de
/// plataforma: falar com o `HKWorkoutSession`, traduzir distância em voltas,
/// contar o segundo e vibrar.
///
/// Essa separação não é estética. A execução é a única parte do produto que **só
/// pode ser testada de verdade dentro de uma piscina** — e quanto menos regra
/// morar aqui, menos coisa depende desse teste.
///
/// ## O princípio 0.1 governa o desenho inteiro
///
/// Com o Water Lock ligado o Apple Watch **ignora toque na tela**, e ele liga
/// sozinho ao iniciar um treino aquático. Nenhuma ação obrigatória pode depender
/// do dedo entre o início e o fim: o treino avança por volta contada, e só.
@MainActor
@Observable
final class WorkoutSessionController: NSObject {

    // MARK: - Estado observável pela interface

    /// Em que fase a execução está.
    enum Fase: Equatable {
        /// Ainda não começou.
        case ociosa
        /// Contagem regressiva de 3 s antes de a sessão iniciar (tela W6).
        case contagemInicial(Int)
        /// Executando: o estado detalhado está no `motor`.
        case executando
        /// Encerrada, aguardando o resumo (tela W10, épico 8.9).
        case encerrada(MotivoEncerramento)
        /// Sem autorização do HealthKit (tela W11, copy 15.11).
        case semAutorizacao
        /// A sessão não pôde iniciar (tela W11, copy 15.9).
        case falhaAoIniciar
    }

    private(set) var fase: Fase = .ociosa

    /// A máquina de estados pura. **É ela que sabe as regras.**
    private(set) var motor: ExecutionEngine

    /// Distância medida pelo HealthKit, em metros.
    ///
    /// **É esta que vai para o `HKWorkout`**, nunca a planejada (regra 11.10 e
    /// critério 8.9).
    private(set) var distanciaRealM = 0

    /// Quando a sessão começou de fato.
    private(set) var iniciadaEm: Date?

    /// Quando ela terminou. Nulo enquanto não terminou.
    private(set) var encerradaEm: Date?

    /// A distância que o treino previa, para o resumo comparar (copy 15.8).
    var distanciaPlanejadaM: Int { plano.distanciaPlanejadaM }

    /// A duração como `m:ss`, ou nulo enquanto a sessão não terminou.
    var duracaoFormatada: String? {
        guard let iniciadaEm, let encerradaEm else { return nil }
        let segundos = Int(encerradaEm.timeIntervalSince(iniciadaEm))
        return "\(segundos / 60):\(String(format: "%02d", segundos % 60))"
    }

    // MARK: - Dependências

    private let treino: Treino
    private let plano: ExecutionPlan
    private let store: WatchStore
    private let healthStore = HKHealthStore()

    private var sessao: HKWorkoutSession?
    private var construtor: HKLiveWorkoutBuilder?

    /// Traduz distância em voltas (regra 11.7).
    private var contadorDeVoltas: LapCounter

    /// O relógio de um segundo do descanso.
    private var tique: Task<Void, Never>?

    init(treino: Treino, store: WatchStore) {
        self.treino = treino
        self.store = store
        let plano = ExecutionPlan(treino: treino)
        self.plano = plano
        self.motor = ExecutionEngine(plano: plano)
        self.contadorDeVoltas = LapCounter(tamanhoRaiaM: plano.tamanhoRaiaM)
        super.init()
    }

    // MARK: - Início (fluxo 8.8)

    /// Pede autorização e começa a contagem de 3 segundos.
    ///
    /// **Sem autorização a sessão não inicia** e a tela W11 explica em português
    /// com o caminho para os Ajustes (critério 8.8).
    func iniciar() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            fase = .semAutorizacao
            return
        }
        do {
            try await healthStore.requestAuthorization(
                toShare: Self.tiposParaEscrever, read: Self.tiposParaLer)
        } catch {
            fase = .semAutorizacao
            return
        }

        await contarAteUm()
        iniciarSessao()
    }

    /// A contagem de `3 · 2 · 1` em tela cheia (tela W6).
    private func contarAteUm() async {
        for restante in stride(from: 3, through: 1, by: -1) {
            fase = .contagemInicial(restante)
            try? await Task.sleep(for: .seconds(1))
        }
    }

    /// Cria e inicia a `HKWorkoutSession` (spec 13.4).
    ///
    /// **A sessão não inicia sem `lapLength`** (critério 8.8). Não é
    /// preciosismo: sem ele o HealthKit não conta volta em piscina, e sem volta
    /// contada não existe avanço de série nem contagem de descanso — o produto
    /// inteiro deixa de funcionar.
    private func iniciarSessao() {
        let configuracao = HKWorkoutConfiguration()
        configuracao.activityType = .swimming
        configuracao.swimmingLocationType = .pool
        configuracao.lapLength = HKQuantity(
            unit: .meter(), doubleValue: Double(plano.tamanhoRaiaM))

        do {
            let sessao = try HKWorkoutSession(
                healthStore: healthStore, configuration: configuracao)
            let construtor = sessao.associatedWorkoutBuilder()
            construtor.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore, workoutConfiguration: configuracao)

            sessao.delegate = self
            construtor.delegate = self

            let agora = Date()
            // Iniciar a sessão é o que **liga o Water Lock sozinho** — a partir
            // daqui a tela ignora o dedo (princípio 0.1).
            sessao.startActivity(with: agora)
            construtor.beginCollection(withStart: agora) { _, _ in }

            self.sessao = sessao
            self.construtor = construtor
            self.iniciadaEm = agora

            motor.comecar()
            fase = .executando
            comecarOTique()
        } catch {
            // Copy 15.9. A sessão é descartada e nada é gravado (máquina 12.2).
            fase = .falhaAoIniciar
        }
    }

    // MARK: - O segundo que passa

    /// O relógio de um segundo que alimenta a contagem de descanso.
    ///
    /// Roda **sempre**, e não só durante o descanso: parar e recriar o laço a
    /// cada transição seria mais código e mais chance de o relógio ficar parado
    /// justamente quando a contagem começa. O motor ignora o segundo quando não
    /// está descansando (regra 11.10).
    private func comecarOTique() {
        tique?.cancel()
        tique = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.processar(.segundo)
            }
        }
    }

    // MARK: - Eventos

    /// Entrega um evento ao motor e dispara os hápticos que ele pedir.
    private func processar(_ evento: ExecutionEngine.Evento) {
        let hapticos = motor.processar(evento)
        for haptico in hapticos {
            vibrar(haptico)
        }
    }

    /// Traduz os hápticos da regra 11.9 em tipos do WatchKit.
    ///
    /// **Os cinco, e nada além.** A regra é explícita: háptico demais vira ruído
    /// e o nadador para de prestar atenção. O motor só emite estes cinco, e este
    /// método é o único lugar do app que vibra.
    private func vibrar(_ haptico: ExecutionEngine.Haptico) {
        switch haptico {
        case .entradaEmDescanso: WKInterfaceDevice.current().play(.notification)
        case .contagemFinal: WKInterfaceDevice.current().play(.directionUp)
        case .saidaDoDescanso: WKInterfaceDevice.current().play(.start)
        case .conclusao: WKInterfaceDevice.current().play(.success)
        }
    }

    // MARK: - Ações opcionais (tela W9)
    //
    // Alcançáveis só com o Water Lock destravado, segurando a coroa. Nenhuma
    // delas é necessária para o treino andar (princípio 0.1).

    func pausar() {
        sessao?.pause()
        processar(.pausar)
    }

    func retomar() {
        sessao?.resume()
        processar(.retomar)
    }

    func pularSerie() {
        processar(.pularSerie)
    }

    /// Encerra a sessão, grava o `HKWorkout` e registra a sessão local
    /// (épico 8.9).
    ///
    /// A ordem importa e é esta:
    /// 1. para o relógio de um segundo, para nada mais avançar;
    /// 2. decide o motivo (regras 11.10 e 11.11) — função pura, testada;
    /// 3. encerra a sessão do HealthKit;
    /// 4. grava o `HKWorkout`, **exceto** quando a sessão foi curta demais;
    /// 5. registra a `sessao_natacao` local com o resultado da gravação.
    ///
    /// O passo 5 acontece **sempre**, inclusive quando o 4 falha: é o que
    /// garante que "os dados ficaram no relógio" (copy 15.13) seja verdade.
    func encerrar() async {
        tique?.cancel()
        tique = nil

        var motivo = MotivoEncerramento.decidir(
            distanciaRealM: distanciaRealM, treinoConcluido: motor.estado == .concluido)

        let fim = Date()
        encerradaEm = fim
        sessao?.end()

        var uuidGravado: UUID?
        if motivo.deveGravarNoHealthKit {
            uuidGravado = await gravarNoHealthKit(fim: fim)
            if uuidGravado == nil {
                // Critério 8.9: falha de gravação **nunca é silenciosa**. A
                // sessão é preservada com `falhou` e o usuário é avisado pela
                // copy 15.13.
                motivo = .falhou
            }
        } else {
            // Regra 11.11: nada é gravado, e a coleta é descartada para o
            // HealthKit não guardar amostras órfãs de um treino que não existiu.
            construtor?.discardWorkout()
        }

        registrarSessaoLocal(motivo: motivo, fim: fim, uuid: uuidGravado)
        fase = .encerrada(motivo)
    }

    /// Fecha a coleta e grava o `HKWorkout` (critério 8.9, spec 13.4).
    ///
    /// Devolve: o UUID do treino gravado, ou `nil` se a gravação falhar.
    ///
    /// **A distância que vai para o HealthKit é a REAL**, medida pela própria
    /// coleta — nunca a planejada (regra 11.10). Quem nadou 1.200 de 2.100
    /// registra 1.200.
    ///
    /// Não há código de sincronização com o iPhone aqui, e não deve haver: o
    /// HealthKit sincroniza sozinho entre Watch e iPhone, e é por isso que o
    /// dado mais importante do produto atravessa sem uma linha nossa
    /// (decisão 4.3 e critério 8.9).
    private func gravarNoHealthKit(fim: Date) async -> UUID? {
        guard let construtor else { return nil }

        let metadados: [String: Any] = [
            // Os dois primeiros são o que faz o app Saúde exibir o treino como
            // natação em piscina, com voltas.
            HKMetadataKeyLapLength: HKQuantity(
                unit: .meter(), doubleValue: Double(plano.tamanhoRaiaM)),
            HKMetadataKeySwimmingLocationType: HKWorkoutSwimmingLocationType.pool.rawValue,
            // Chave própria (spec 13.4): permite reconhecer, no Histórico, qual
            // treino do app originou aquele registro.
            Self.chaveDoTitulo: treino.titulo ?? "",
        ]

        do {
            try await construtor.addMetadata(metadados)
            try await construtor.endCollection(at: fim)
            let treinoGravado = try await construtor.finishWorkout()
            return treinoGravado?.uuid
        } catch {
            return nil
        }
    }

    /// Registra a `sessao_natacao` no store do relógio (spec 7.9).
    ///
    /// O contador `vezes_executado` do treino é atualizado **na mesma
    /// transação** (regra 11.13) — quem garante isso é o repositório.
    ///
    /// ## Sessão descartada por curta não é gravada — decisão declarada
    ///
    /// O spec é ambíguo aqui e as duas leituras têm consequência visível:
    ///
    /// - a seção 7.9 lista `descartado_curto` como valor de
    ///   `motivo_encerramento`, o que sugere que a sessão é **persistida**;
    /// - a copy 15.12 diz "Treino muito curto. **Nada foi salvo**", e a regra
    ///   11.13 manda incrementar `vezes_executado` em **toda** inserção de
    ///   sessão.
    ///
    /// Seguir a primeira leitura faz um toque acidental de 10 metros virar
    /// "Feito 1 vez" na lista de Favoritos — exatamente o tipo de poluição que a
    /// regra 11.11 existe para evitar, só que no histórico do app em vez de no
    /// do HealthKit.
    ///
    /// Decisão: **não gravar**. Isso torna a copy 15.12 literalmente verdadeira,
    /// mantém o contador coerente com o que ele exibe, e preserva a regra 11.13
    /// intacta em vez de abrir uma exceção nela. O valor `descartado_curto`
    /// continua existindo e é o que a tela W10 mostra no momento — ele só não
    /// chega ao banco.
    private func registrarSessaoLocal(motivo: MotivoEncerramento, fim: Date, uuid: UUID?) {
        guard motivo != .descartado_curto else { return }

        let sessao = SessaoNatacao(
            treino: treino,
            // Snapshot do título: o Histórico sobrevive ao arquivamento do
            // treino (spec 7.9).
            tituloSnapshot: treino.titulo,
            iniciadaEm: iniciadaEm ?? fim,
            encerradaEm: fim,
            distanciaPlanejadaM: plano.distanciaPlanejadaM,
            // A real, sempre (regra 11.10).
            distanciaRealM: distanciaRealM,
            seriesConcluidas: motor.seriesConcluidas,
            repeticoesConcluidas: motor.repeticoesConcluidas,
            // Nulo quando a gravação falhou, e permanentemente nulo (spec 7.9).
            healthkitWorkoutUuid: uuid,
            tamanhoRaiaM: plano.tamanhoRaiaM,
            motivoEncerramento: motivo)

        _ = try? store.treinos.registrarSessao(sessao)
    }

    /// Chave de metadado própria (spec 13.4).
    static let chaveDoTitulo = "com.dablab.vounadar.tituloTreino"

    // MARK: - Tipos do HealthKit (spec 13.4)

    static let tiposParaEscrever: Set<HKSampleType> = [
        HKQuantityType(.distanceSwimming),
        HKQuantityType(.activeEnergyBurned),
        HKObjectType.workoutType(),
    ]

    static let tiposParaLer: Set<HKObjectType> = [
        HKQuantityType(.distanceSwimming),
        // Coletada porque vem de graça com a sessão, mas **não exibida** no v1
        // (assunção 24.7).
        HKQuantityType(.heartRate),
        HKObjectType.workoutType(),
    ]
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutSessionController: HKWorkoutSessionDelegate {

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState, date: Date
    ) {}

    /// A sessão falhou depois de iniciada.
    ///
    /// Copy 15.9. **Nunca falha silenciosa** (critério 8.9): o usuário é
    /// avisado, e o que já foi nadado continua no relógio.
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error)
    {
        Task { @MainActor [weak self] in
            self?.fase = .falhaAoIniciar
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutSessionController: HKLiveWorkoutBuilderDelegate {

    /// Chega uma amostra nova.
    ///
    /// A distância é o sinal que faz o treino andar: `LapCounter` a converte em
    /// voltas (regra 11.7), e cada volta vira um evento para o motor.
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        guard collectedTypes.contains(HKQuantityType(.distanceSwimming)),
            let estatistica = workoutBuilder.statistics(for: HKQuantityType(.distanceSwimming)),
            let metros = estatistica.sumQuantity()?.doubleValue(for: .meter())
        else { return }

        Task { @MainActor [weak self] in
            self?.registrarDistancia(metros)
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    /// Registra a distância e entrega as voltas novas ao motor.
    private func registrarDistancia(_ metros: Double) {
        distanciaRealM = Int(metros)
        let novas = contadorDeVoltas.registrar(distanciaTotalM: metros)
        for _ in 0..<novas {
            processar(.voltaCompletada)
        }
    }
}
