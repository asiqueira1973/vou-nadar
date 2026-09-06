import SwiftUI

/// W5 — Tamanho da piscina no relógio (critério 8.7, copy 15.3).
///
/// Lê e escreve: `preferencias.tamanho_raia_m` e `raia_confirmada`.
///
/// Mesma regra do iPhone (regra 11.4): sem piscina confirmada não se gera
/// treino, porque a regra 11.3 adapta as distâncias à raia e sem ela o treino
/// seria montado para piscina nenhuma.
///
/// O valor livre é ajustado **pela coroa**, de 10 a 50 (assunção 24.3): é a tela
/// que o nadador abre na borda, molhado, para corrigir a piscina antes de
/// começar — e ali toque preciso não existe.
struct WatchPoolSizeView: View {

    let store: WatchStore
    var aoConfirmar: () -> Void = {}

    @State private var metrosLivres: Double = 16
    @State private var usandoValorLivre = false
    @State private var selecionado: Int?

    @FocusState private var coroaFocada: Bool

    var body: some View {
        List {
            Section {
                linhaDeAtalho(25, rotulo: WatchCopy.piscinaAtalho25)
                linhaDeAtalho(50, rotulo: WatchCopy.piscinaAtalho50)

                Button {
                    usandoValorLivre = true
                    selecionado = Int(metrosLivres)
                    coroaFocada = true
                } label: {
                    HStack {
                        Text(WatchCopy.piscinaOutro)
                        Spacer(minLength: 0)
                        if usandoValorLivre {
                            Image(systemName: Simbolos.marcador)
                                .foregroundStyle(Color.watchNadando)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if usandoValorLivre {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(verbatim: "\(Int(metrosLivres))")
                                .font(.watch(WatchTipografia.distanciaDestaque, .bold))
                                .foregroundStyle(Color.watchTextoPrimario)
                            Text(WatchCopy.unidadeMetros)
                                .font(.watch(WatchTipografia.rotulo))
                                .foregroundStyle(Color.watchTextoSecundario)
                        }
                        Text(WatchCopy.piscinaAjudaDaCoroa)
                            .font(.watch(WatchTipografia.rotulo, .regular))
                            .foregroundStyle(Color.watchTextoSecundario)
                    }
                    .listRowBackground(Color.clear)
                    .focusable()
                    .focused($coroaFocada)
                    .digitalCrownRotation(
                        $metrosLivres,
                        from: Double(Preferencias.faixaDeRaia.lowerBound),
                        through: Double(Preferencias.faixaDeRaia.upperBound),
                        by: 1,
                        sensitivity: .low,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true)
                    .onChange(of: metrosLivres) { _, novo in selecionado = Int(novo) }
                    .accessibilityElement()
                    .accessibilityLabel(Text(WatchCopy.piscinaTitulo))
                    .accessibilityValue(Text(verbatim: "\(Int(metrosLivres)) m"))
                }
            }

            Section {
                Button {
                    confirmar()
                } label: {
                    Text(WatchCopy.acaoConfirmar)
                        .frame(maxWidth: .infinity)
                }
                .tint(Color.watchNadando)
                .disabled(selecionado == nil)
            }
        }
        .navigationTitle(Text(WatchCopy.piscinaTitulo))
        .fundoDoRelogio()
        .task { carregar() }
    }

    @ViewBuilder
    private func linhaDeAtalho(_ metros: Int, rotulo: LocalizedStringResource) -> some View {
        Button {
            usandoValorLivre = false
            selecionado = metros
        } label: {
            HStack {
                Text(rotulo)
                Spacer(minLength: 0)
                if selecionado == metros && !usandoValorLivre {
                    Image(systemName: Simbolos.marcador)
                        .foregroundStyle(Color.watchNadando)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func carregar() {
        guard let prefs = try? store.preferencias.preferenciasAtuais() else { return }
        guard prefs.raiaConfirmada else { return }
        selecionado = prefs.tamanhoRaiaM
        if prefs.tamanhoRaiaM != 25 && prefs.tamanhoRaiaM != 50 {
            usandoValorLivre = true
            metrosLivres = Double(prefs.tamanhoRaiaM)
        }
    }

    /// Grava e confirma (regra 11.4).
    ///
    /// A validação de 10 a 50 é do repositório, não da tela: a coroa já limita,
    /// mas trocar o controle não pode abrir caminho para gravar uma piscina
    /// impossível (spec 7.11).
    /// Grava e devolve o controle a quem abriu a tela.
    ///
    /// **Quem fecha é o chamador**, pelo `aoConfirmar` — e não um `dismiss()`
    /// daqui. Os dois juntos desfaziam dois níveis de navegação: confirmar a
    /// piscina vindo da tela Gerar voltava até o Início, em vez de voltar para
    /// o Gerar com a piscina já confirmada.
    private func confirmar() {
        guard let selecionado else { return }
        try? store.preferencias.confirmarPiscina(tamanhoRaiaM: selecionado)
        aoConfirmar()
    }
}
