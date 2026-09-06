import SwiftUI

/// As telas da execução guiada — W6 a W9 e W11 (épico 8.8).
///
/// **Uma informação em destaque por tela, nunca duas**, e no máximo três
/// elementos de texto (DESIGN-SYSTEM.md seção 7). O contexto é molhado, sem
/// óculos, com dois segundos de atenção.
///
/// **Nenhuma ação obrigatória depende de toque** (princípio 0.1): o Water Lock
/// está ligado e a tela ignora o dedo. Pausar, pular e encerrar existem na W9,
/// alcançável segurando a coroa, e nenhuma delas é necessária para o treino
/// andar.
struct WatchSessionView: View {

    @State var controlador: WorkoutSessionController

    /// Fecha a execução e volta para a pré-visualização.
    var aoSair: () -> Void = {}

    /// Always-On com luminância reduzida: estado e número, sem animação e sem
    /// cor saturada (DESIGN-SYSTEM.md seção 7, item 7).
    @Environment(\.isLuminanceReduced) private var luminanciaReduzida

    var body: some View {
        Group {
            switch controlador.fase {
            case .ociosa:
                ProgressView()

            case .contagemInicial(let numero):
                ContagemInicial(numero: numero)

            case .executando:
                executando

            case .encerrada(let motivo):
                // A tela W10 (resumo) e a gravação são do épico 8.9.
                ResumoDaSessao(motivo: motivo, controlador: controlador, aoSair: aoSair)

            case .semAutorizacao:
                ErroDeAutorizacao(
                    copy: WatchCopy.execucaoSemAutorizacao,
                    caminho: WatchCopy.execucaoComoAutorizar,
                    aoSair: aoSair)

            case .falhaAoIniciar:
                // Falha ao iniciar não é falta de permissão: não há caminho a
                // oferecer, só tentar de novo.
                ErroDeAutorizacao(
                    copy: WatchCopy.execucaoFalhaAoIniciar, caminho: nil, aoSair: aoSair)
            }
        }
        .fundoDoRelogio()
        .task {
            guard controlador.fase == .ociosa else { return }
            await controlador.iniciar()
        }
    }

    /// W7 nadando, W8 descansando, e a W9 quando a coroa destrava.
    @ViewBuilder
    private var executando: some View {
        switch controlador.motor.estado {
        case .descansando(let descanso):
            TelaDescansando(descanso: descanso, luminanciaReduzida: luminanciaReduzida)

        case .nadando(let posicao):
            TelaNadando(
                posicao: posicao,
                serie: controlador.motor.serieAtual,
                metros: controlador.motor.metrosPercorridos,
                luminanciaReduzida: luminanciaReduzida)

        case .pausado:
            TelaPausada(controlador: controlador)

        case .concluido:
            TelaConcluida(controlador: controlador, aoSair: aoSair)

        case .preparando:
            ProgressView()
        }
    }
}

// MARK: - W6 Contagem inicial

/// W6 — `3 · 2 · 1` em tela cheia.
///
/// Um algarismo de 130 pt e nada mais: é o único momento do app em que a tela
/// tem uma coisa só.
private struct ContagemInicial: View {

    let numero: Int

    var body: some View {
        Text(verbatim: "\(numero)")
            .font(.watch(WatchTipografia.contagemInicial, .bold))
            .foregroundStyle(Color.watchNadando)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(Text(verbatim: "\(numero)"))
    }
}

// MARK: - W7 Nadando

/// W7 — nadando.
///
/// Três elementos, na ordem em que a persona da seção 2 precisa deles:
/// a repetição atual em 56 pt, a série, e o acumulado.
private struct TelaNadando: View {

    let posicao: ExecutionEngine.Posicao
    let serie: ExecutionPlan.SeriePlanejada?
    let metros: Int
    let luminanciaReduzida: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: "\(posicao.repeticao)")
                    .font(.watch(WatchTipografia.repeticaoAtual, .bold))
                Text(WatchCopy.execucaoDeTotal(serie?.repeticoes ?? 0))
                    .font(.watch(WatchTipografia.rotulo))
                    .foregroundStyle(Color.watchTextoSecundario)
            }
            // Always-On: cor apagada, sem saturação (design system seção 7).
            .foregroundStyle(luminanciaReduzida ? Color.watchNadandoApagado : Color.watchNadando)

            if let serie, !luminanciaReduzida {
                // Escondida no Always-On: lá ficam só estado e número.
                Text(verbatim: "\(serie.repeticoes)\u{00D7}\(serie.distanciaM) \(serie.nome)")
                    .font(.watch(WatchTipografia.rotulo, .regular))
                    .foregroundStyle(Color.watchTextoSecundario)
                    .lineLimit(2)
            }

            Text(verbatim: "\(WatchFormato.metros(metros)) m")
                .font(.watch(WatchTipografia.rotulo))
                .foregroundStyle(Color.watchTextoSecundario)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - W8 Descansando

/// W8 — descansando. **A tela mais importante do app.**
///
/// A contagem regressiva é o elemento dominante: 76 pt no descanso, **90 pt nos
/// últimos 3 segundos**. É a informação que a persona da seção 2 mais precisa,
/// na borda, com os óculos embaçados.
///
/// ## O requisito 17.12 em forma de código
///
/// Âmbar e verde têm **1,02:1 de contraste entre si**: para quem tem
/// deuteranopia — o daltonismo mais comum — os dois estados são a mesma cor,
/// justamente na transição que avisa "prepara pra sair".
///
/// Por isso a passagem para os últimos 3 segundos muda **três** coisas, e a cor
/// é só uma delas:
/// 1. a cor, de âmbar para verde;
/// 2. **o tamanho**, de 76 pt para 90 pt;
/// 3. **a pulsação**, uma vez por segundo.
///
/// E há um quarto canal fora da tela: o háptico da regra 11.9, um por segundo.
///
/// A pulsação **permanece com Reduce Motion ligado** (design system seção 8):
/// ela é sinal de acessibilidade, não decoração.
private struct TelaDescansando: View {

    let descanso: ExecutionEngine.Descanso
    let luminanciaReduzida: Bool

    private var estaNoFim: Bool { descanso.estaNosUltimosTresSegundos }

    private var cor: Color {
        if luminanciaReduzida { return .watchDescansandoApagado }
        return estaNoFim ? .watchSaida : .watchDescansando
    }

    private var tamanho: CGFloat {
        estaNoFim ? WatchTipografia.contagemDescansoFinal : WatchTipografia.contagemDescanso
    }

    var body: some View {
        VStack(spacing: 0) {
            // Copy 15.7.
            Text(WatchCopy.execucaoDescanso)
                .font(.watch(WatchTipografia.rotulo))
                .foregroundStyle(Color.watchTextoSecundario)

            Text(verbatim: "\(descanso.restanteSeg)")
                .font(.watch(tamanho, .bold))
                .foregroundStyle(cor)
                .contentTransition(.numericText(countsDown: true))
                // A pulsação é o terceiro canal do requisito 17.12, junto com a
                // cor e o tamanho. Sem animação no Always-On (seção 7).
                .scaleEffect(estaNoFim && !luminanciaReduzida ? 1.08 : 1.0)
                .animation(
                    luminanciaReduzida ? nil : .easeOut(duration: 0.25),
                    value: descanso.restanteSeg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(WatchCopy.execucaoDescanso))
        .accessibilityValue(Text(verbatim: "\(descanso.restanteSeg)"))
    }
}

// MARK: - W9 Desbloqueada

/// W9 — pausada, com as ações à mostra.
///
/// Alcançada segurando a coroa, que destrava o Water Lock. Três botões
/// empilhados, cada um com pelo menos 44 pt de altura.
private struct TelaPausada: View {

    let controlador: WorkoutSessionController

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Button { controlador.retomar() } label: {
                    Text(WatchCopy.execucaoRetomar).frame(maxWidth: .infinity)
                }
                .tint(Color.watchNadando)

                Button { controlador.pularSerie() } label: {
                    Text(WatchCopy.execucaoPularSerie).frame(maxWidth: .infinity)
                }

                Button { Task { await controlador.encerrar() } } label: {
                    Text(WatchCopy.execucaoEncerrar).frame(maxWidth: .infinity)
                }
                .tint(Color.watchDestrutivo)
            }
            .frame(minHeight: WatchTipografia.alvoDeToque)
        }
    }
}

// MARK: - Conclusão

/// O treino acabou, mas a sessão continua até o nadador encerrar.
///
/// **Não encerra sozinho** (regra 11.10): nadar mais que o planejado não é erro,
/// e a distância extra continua contando. Encerrar é ação do nadador.
private struct TelaConcluida: View {

    let controlador: WorkoutSessionController
    let aoSair: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text(WatchCopy.execucaoConcluido)
                .font(.watch(WatchTipografia.rotulo))
                .foregroundStyle(Color.watchSaida)

            Text(verbatim: "\(WatchFormato.metros(controlador.distanciaRealM)) m")
                .font(.watch(WatchTipografia.distanciaResumo, .bold))
                .foregroundStyle(Color.watchTextoPrimario)

            Button { Task { await controlador.encerrar() } } label: {
                Text(WatchCopy.execucaoEncerrar).frame(maxWidth: .infinity)
            }
            .tint(Color.watchDestrutivo)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// W10 — resumo, nas quatro variantes (épico 8.9).
///
/// **Legível com a mão molhada, sem exigir toque preciso**: um número grande, um
/// aviso quando há o que avisar, e um botão que ocupa a largura inteira.
///
/// As quatro variantes e o que cada uma diz:
/// - `concluido` — a distância, e nada mais. Não há o que explicar;
/// - `encerrado_antes` — copy 15.8, `{real} m de {planejado} m`. **Não é
///   mensagem de falha**: parar antes é decisão do nadador (regra 11.10);
/// - `descartado_curto` — copy 15.12, e nada foi salvo (regra 11.11);
/// - `falhou` — copy 15.13, dizendo onde os dados ficaram.
private struct ResumoDaSessao: View {

    let motivo: MotivoEncerramento
    let controlador: WorkoutSessionController
    let aoSair: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(verbatim: WatchFormato.metros(controlador.distanciaRealM))
                        .font(.watch(WatchTipografia.distanciaResumo, .bold))
                        .foregroundStyle(Color.watchTextoPrimario)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(WatchCopy.unidadeMetros)
                        .font(.watch(WatchTipografia.rotulo))
                        .foregroundStyle(Color.watchTextoSecundario)
                }

                if let aviso {
                    Text(aviso)
                        .font(.watch(WatchTipografia.rotulo, .regular))
                        .foregroundStyle(corDoAviso)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    Rotulo(
                        valor: "\(controlador.motor.seriesConcluidas)",
                        rotulo: WatchCopy.resumoSeries)
                    if let duracao = controlador.duracaoFormatada {
                        Rotulo(valor: duracao, rotulo: WatchCopy.resumoTempo)
                    }
                }

                Button(action: aoSair) {
                    Text(WatchCopy.acaoConcluir).frame(maxWidth: .infinity)
                }
                .tint(Color.watchNadando)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }

    /// O que o resumo precisa explicar, ou nada quando não há o que explicar.
    private var aviso: LocalizedStringResource? {
        switch motivo {
        case .concluido:
            nil
        case .encerrado_antes:
            WatchCopy.resumoRealDePlanejado(
                real: controlador.distanciaRealM,
                planejado: controlador.distanciaPlanejadaM)
        case .descartado_curto:
            WatchCopy.resumoMuitoCurto
        case .falhou:
            WatchCopy.resumoFalhaAoSalvar
        }
    }

    /// Só o que é problema de verdade fica em âmbar.
    ///
    /// `encerrado_antes` fica em cor secundária de propósito: a regra 11.10 diz
    /// que parar antes **não é erro**, e pintá-lo de alerta contradiria isso na
    /// única tela em que o nadador olha depois de sair da água.
    private var corDoAviso: Color {
        switch motivo {
        case .descartado_curto, .falhou: .watchDescansando
        case .concluido, .encerrado_antes: .watchTextoSecundario
        }
    }
}

/// Um número com rótulo embaixo, no resumo.
private struct Rotulo: View {

    let valor: String
    let rotulo: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: valor)
                .font(.watch(WatchTipografia.rotulo))
                .foregroundStyle(Color.watchTextoPrimario)
            Text(rotulo)
                .font(.watch(WatchTipografia.rotulo, .regular))
                .foregroundStyle(Color.watchTextoSecundario)
        }
    }
}

// MARK: - W11 Erro de autorização

/// W11 — sem autorização do HealthKit, ou falha ao iniciar.
///
/// Explica **em português** e oferece o caminho; a sessão não inicia
/// (critério 8.8, copy 15.11 e 15.9).
private struct ErroDeAutorizacao: View {

    let copy: LocalizedStringResource
    /// Onde a permissão se concede. Nulo quando não há caminho a oferecer.
    let caminho: LocalizedStringResource?
    let aoSair: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: Simbolos.semAutorizacao)
                    .font(.watch(28))
                    .foregroundStyle(Color.watchDescansando)

                Text(copy)
                    .font(.watch(WatchTipografia.rotulo, .regular))
                    .foregroundStyle(Color.watchTextoPrimario)
                    .multilineTextAlignment(.center)

                if let caminho {
                    Text(caminho)
                        .font(.watch(WatchTipografia.rotulo, .regular))
                        .foregroundStyle(Color.watchTextoSecundario)
                        .multilineTextAlignment(.center)
                }

                Button(action: aoSair) {
                    Text(WatchCopy.acaoVoltar).frame(maxWidth: .infinity)
                }
            }
        }
    }
}
