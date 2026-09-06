import Foundation
import HealthKit

/// Lê o histórico de natação do HealthKit (épico 8.10).
///
/// Recebe: nada além da autorização do usuário.
/// Devolve: as sessões de natação em piscina, **de todos os apps**.
/// Erros: `.semAutorizacao` quando o usuário não concedeu leitura.
///
/// ## Por que ler do HealthKit e não do SwiftData
///
/// O iPhone **não tem** as sessões: elas nascem no relógio, no store dele, e não
/// há sincronização Watch → iPhone (princípio 0.7 e regra 11.18). O que atravessa
/// é o `HKWorkout`, que o HealthKit propaga sozinho entre os dois aparelhos
/// (decisão 4.3).
///
/// Isso tem uma consequência que o critério 8.10 transforma em requisito: se a
/// fonte é o HealthKit, **treinos de natação gravados por outros apps também
/// aparecem**. E devem aparecer — o HealthKit é do usuário, não do Vou Nadar.
/// Escondê-los seria fingir que o app é o único lugar onde o usuário nada.
///
/// ## Por que este arquivo NÃO está em `Data/Repositories/`
///
/// Aquela pasta é fonte dos dois targets, e o teste de pureza do critério 8.1.7
/// proíbe HealthKit lá — com razão: um `import HealthKit` numa fonte
/// compartilhada acopla o domínio a um framework de plataforma. `Data/Health/` é
/// só do iPhone, e é onde a leitura do HealthKit pertence.
///
/// O relógio não usa esta classe: ele lê o volume dele do store local (tela W1),
/// e é ele quem **escreve** no HealthKit (épico 8.9).
@MainActor
final class HealthHistoryReader {

    enum Falha: Error, Equatable {
        /// O usuário não concedeu leitura, ou o aparelho não tem HealthKit.
        ///
        /// A tela P4 explica e oferece o caminho, **sem quebrar** (critério 8.10).
        case semAutorizacao
    }

    private let healthStore = HKHealthStore()

    /// Os bundles que são "este app".
    ///
    /// Um `HKWorkout` gravado por qualquer outro identificador é de outro app e
    /// ganha o selo "fora do app". O do relógio está aqui porque **é ele quem
    /// grava** — o iPhone só lê (spec 4.1).
    static let bundlesDoApp: Set<String> = [
        "com.dablab.vounadar",
        "com.dablab.vounadar.watchkitapp",
    ]

    /// Tipos que o iPhone lê. **Ele nunca escreve** (spec 4.1 e 13.4).
    static let tiposParaLer: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.distanceSwimming),
    ]

    /// Pede autorização de leitura.
    ///
    /// Erros: `.semAutorizacao`. **Nunca lança para a tela quebrar** — a P4
    /// trata o erro mostrando a explicação e o caminho.
    func pedirAutorizacao() async throws(Falha) {
        guard HKHealthStore.isHealthDataAvailable() else { throw .semAutorizacao }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: Self.tiposParaLer)
        } catch {
            throw .semAutorizacao
        }
    }

    /// Busca as sessões de natação desde uma data.
    ///
    /// Recebe: a data mais antiga a considerar.
    /// Devolve: as sessões, da mais recente para a mais antiga.
    ///
    /// **Inclui águas abertas de propósito.** O v1 do app só gera treino de
    /// piscina (spec 3.2), mas o histórico é do usuário: se ele nadou no mar com
    /// outro app, o volume da semana dele inclui isso. Filtrar seria o app
    /// decidindo o que conta como natação na vida de alguém.
    func sessoes(desde: Date) async throws(Falha) -> [SessaoDoHistorico] {
        guard HKHealthStore.isHealthDataAvailable() else { throw .semAutorizacao }

        let periodo = HKQuery.predicateForSamples(withStart: desde, end: nil)
        let natacao = HKQuery.predicateForWorkouts(with: .swimming)
        let descritor = HKSampleQueryDescriptor(
            predicates: [.workout(NSCompoundPredicate(andPredicateWithSubpredicates: [periodo, natacao]))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)])

        do {
            let treinos = try await descritor.result(for: healthStore)
            return treinos.map(Self.converter)
        } catch {
            throw .semAutorizacao
        }
    }

    /// Traduz um `HKWorkout` para o modelo do Histórico.
    private static func converter(_ treino: HKWorkout) -> SessaoDoHistorico {
        let metros =
            treino.statistics(for: HKQuantityType(.distanceSwimming))?
            .sumQuantity()?
            .doubleValue(for: .meter()) ?? 0

        let bundle = treino.sourceRevision.source.bundleIdentifier
        let ehExterno = !bundlesDoApp.contains(bundle)

        return SessaoDoHistorico(
            id: treino.uuid,
            iniciadaEm: treino.startDate,
            duracao: treino.duration,
            distanciaM: Int(metros),
            // A chave própria da spec 13.4 é o que permite reconhecer qual
            // treino do app originou o registro. Treino de outro app não a tem.
            titulo: treino.metadata?[Self.chaveDoTitulo] as? String,
            origemExterna: ehExterno)
    }

    /// Quantas execuções guiadas **deste app** já aconteceram (critério 8.11).
    ///
    /// Recebe: a data mais antiga a considerar.
    /// Devolve: a contagem de `HKWorkout` gravados pelos bundles do app.
    ///
    /// ## Por que contar aqui, e não no banco
    ///
    /// A execução acontece no **relógio**, e a sessão fica no store dele. O
    /// iPhone não a tem, e não pode tê-la: não há canal Watch → iPhone
    /// (princípio 0.7 e regra 11.18).
    ///
    /// O que atravessa é o `HKWorkout` — então contar os que **este app**
    /// gravou dá o número certo sem inventar sincronização. Treino de outro app
    /// não conta: ele não consumiu execução guiada nenhuma.
    ///
    /// Sem autorização a contagem é **zero**, e zero libera. É a mesma
    /// assimetria da regra 11.17: negar acesso a quem pagou é pior que liberar a
    /// quem não pagou.
    func execucoesDoApp(desde: Date) async -> Int {
        let sessoes = (try? await sessoes(desde: desde)) ?? []
        return sessoes.count { !$0.origemExterna }
    }

    /// A chave de metadado que o relógio grava (spec 13.4).
    static let chaveDoTitulo = "com.dablab.vounadar.tituloTreino"
}
