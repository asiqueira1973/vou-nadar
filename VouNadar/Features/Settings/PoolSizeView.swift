import SwiftUI

/// P6 — Tamanho da piscina (critérios 8.3.1 a 8.3.4, copy 15.3).
///
/// Recebe: o repositório de preferências e o modo de apresentação.
/// Escreve: `preferencias.tamanho_raia_m` e `preferencias.raia_confirmada`.
///
/// **Por que esta tela é obrigatória antes de gerar** (regra 11.4): a regra 11.3
/// adapta a distância de cada exercício ao número inteiro de voltas da piscina.
/// Sem saber a raia, o app não sabe nem quantos metros tem uma repetição, nem
/// quais exercícios sobrevivem à guarda de desvio. Gerar antes de confirmar
/// produziria um treino para piscina nenhuma — por isso o bloqueio não é só da
/// execução, é da geração.
///
/// A faixa de 10 a 50 m (assunção 24.3) é larga de propósito: piscina de
/// condomínio e academia costuma ter 12, 15, 16, 18 ou 20 m, e o app precisa
/// servi-las.
struct PoolSizeView: View {

    /// Como a tela chegou à frente do usuário.
    enum Modo {
        /// Primeira abertura: **obrigatória**, sem botão voltar, nenhuma opção
        /// pré-selecionada, e um botão "Continuar" na barra inferior (estado
        /// declarado na seção 6 do design system).
        case obrigatoria
        /// Empurrada pelos Ajustes: já tem valor, grava a cada toque, e o botão
        /// voltar do sistema é o caminho de saída.
        case ajustes
    }

    let repositorio: PreferencesRepository
    let modo: Modo

    /// Chamado depois de confirmar, para o fluxo obrigatório sair da tela.
    var aoConfirmar: () -> Void = {}

    /// Valor em edição. Nulo no modo obrigatório até o usuário escolher —
    /// nenhuma opção nasce marcada, para a escolha ser consciente.
    @State private var metros: Int?

    /// Verdadeiro quando o usuário escolheu "Outro" e o `Stepper` está à vista.
    @State private var usandoValorLivre = false

    /// Mensagem de erro de validação (critério 8.3.2).
    @State private var erro: String?

    /// Valor que o `Stepper` edita. Nasce em 16 m, que é uma piscina de
    /// condomínio típica e deixa claro que o campo aceita valor incomum.
    @State private var metrosLivres = 16

    var body: some View {
        List {
            Section {
                LinhaSelecionavel(selecionada: metros == 25 && !usandoValorLivre) {
                    escolherAtalho(25)
                } rotulo: {
                    Text(Copy.piscinaAtalho25)
                }

                LinhaSelecionavel(selecionada: metros == 50 && !usandoValorLivre) {
                    escolherAtalho(50)
                } rotulo: {
                    Text(Copy.piscinaAtalho50)
                }

                LinhaSelecionavel(selecionada: usandoValorLivre) {
                    escolherValorLivre()
                } rotulo: {
                    Text(Copy.piscinaOutro)
                }

                if usandoValorLivre {
                    // `Stepper` do sistema, não redesenhado (guardrail 11), com
                    // a faixa da assunção 24.3 aplicada pelo próprio controle.
                    Stepper(value: $metrosLivres, in: Preferencias.faixaDeRaia) {
                        LabeledContent {
                            Text(verbatim: "\(metrosLivres)")
                                .font(.valorDaLinha)
                                .foregroundStyle(Color.textoSecundario)
                        } label: {
                            Text(Copy.piscinaMetros)
                        }
                    }
                    .onChange(of: metrosLivres) { _, novo in
                        metros = novo
                        if modo == .ajustes { gravar(novo) }
                    }
                }
            } footer: {
                Text(Copy.piscinaRodape)
            }
        }
        .listaDoApp()
        .navigationTitle(Text(Copy.piscinaTitulo))
        .navigationBarTitleDisplayMode(.large)
        // No modo obrigatório não há saída pela barra: a piscina é requisito da
        // geração (regra 11.4), não uma preferência que se adia.
        .navigationBarBackButtonHidden(modo == .obrigatoria)
        .interactiveDismissDisabled(modo == .obrigatoria)
        .safeAreaInset(edge: .bottom) {
            if modo == .obrigatoria {
                BarraDeAcaoPrimaria(
                    desabilitado: metros == nil,
                    acao: confirmar
                ) {
                    Text(Copy.piscinaContinuar)
                }
            }
        }
        .alert(
            Text(Copy.piscinaTitulo),
            isPresented: Binding(get: { erro != nil }, set: { if !$0 { erro = nil } }),
            presenting: erro
        ) { _ in
            Button(role: .cancel) { erro = nil } label: { Text(Copy.acaoEntendi) }
        } message: { mensagem in
            Text(mensagem)
        }
        .task { carregarEstadoInicial() }
    }

    // MARK: - Ações

    /// Carrega o valor já gravado, quando existe (modo Ajustes).
    ///
    /// No modo obrigatório nada é pré-selecionado: `raia_confirmada` é falso e
    /// o valor de `tamanho_raia_m` ainda é o default de schema, não uma escolha
    /// do usuário.
    private func carregarEstadoInicial() {
        guard let prefs = try? repositorio.preferenciasAtuais() else { return }
        guard prefs.raiaConfirmada else { return }
        metros = prefs.tamanhoRaiaM
        if prefs.tamanhoRaiaM != 25 && prefs.tamanhoRaiaM != 50 {
            usandoValorLivre = true
            metrosLivres = prefs.tamanhoRaiaM
        }
    }

    /// Marca um dos dois atalhos (25 m ou 50 m).
    private func escolherAtalho(_ valor: Int) {
        usandoValorLivre = false
        metros = valor
        if modo == .ajustes { gravar(valor) }
    }

    /// Passa para o valor livre, revelando o `Stepper` de 10 a 50.
    private func escolherValorLivre() {
        usandoValorLivre = true
        metros = metrosLivres
        if modo == .ajustes { gravar(metrosLivres) }
    }

    /// Confirma a escolha no fluxo obrigatório, destravando a geração
    /// (regra 11.4 e critério 8.3.1).
    private func confirmar() {
        guard let metros else { return }
        gravar(metros)
        if erro == nil { aoConfirmar() }
    }

    /// Grava o valor, mostrando a mensagem de validação se ele for recusado
    /// (critério 8.3.2).
    ///
    /// O `Stepper` já limita a 10...50, então este caminho de erro só é
    /// alcançável por chamada direta ao repositório. Ele existe porque a
    /// validação é do repositório, não do controle — trocar o controle não pode
    /// abrir caminho para gravar uma piscina impossível (spec 7.11).
    private func gravar(_ valor: Int) {
        do {
            try repositorio.confirmarPiscina(tamanhoRaiaM: valor)
            erro = nil
        } catch let falha as PreferencesError {
            erro = falha.mensagemParaUsuario
        } catch {
            erro = String(describing: error)
        }
    }
}
