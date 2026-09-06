import SwiftData
import SwiftUI

/// P5 — Ajustes (critérios 8.3.4 e 8.3.5).
///
/// Recebe: o repositório de preferências e o catálogo embarcado.
/// Lê e escreve: `preferencias` e `equipamento_selecionado`.
///
/// Chega pela engrenagem na barra de navegação da Home, **não por uma aba**
/// (DESIGN-SYSTEM.md seção 3): as três abas são Treino, Favoritos e Histórico.
///
/// As seções "Sobre", "Restaurar compra" e "Apagar todos os dados" que o design
/// mostra chegam nos épicos 8.5 e 8.11; aqui estão as três que o épico 8.3
/// define: piscina, ritmo de descanso e equipamento.
struct SettingsView: View {

    let repositorio: PreferencesRepository
    let catalogo: CatalogStore
    let compras: PurchaseService

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var abrirURL

    /// Comprimento da raia, para a linha de valor da Section "Piscina".
    @State private var tamanhoRaiaM = 25

    /// Ritmo vigente (regra 11.5).
    @State private var ritmo: RitmoDescanso = .normal

    /// `equipamento_id` marcados (spec 7.8).
    @State private var equipamentos: Set<String> = []

    /// A confirmação de apagar dados, em **duas etapas**.
    @State private var primeiraPergunta = false
    @State private var segundaPergunta = false

    /// Resultado do "Restaurar compra".
    @State private var avisoDaRestauracao: LocalizedStringResource?

    @State private var mostrandoPaywall = false

    var body: some View {
        List {
            // MARK: Piscina
            Section {
                NavigationLink {
                    PoolSizeView(repositorio: repositorio, modo: .ajustes)
                } label: {
                    LabeledContent {
                        Text(verbatim: "\(tamanhoRaiaM) m")
                            .font(.valorDaLinha)
                            .foregroundStyle(Color.textoSecundario)
                    } label: {
                        Text(Copy.piscinaTitulo)
                    }
                }
            } header: {
                Text(Copy.ajustesSecaoPiscina)
            }

            // MARK: Descanso (critério 8.3.5)
            Section {
                ForEach(RitmoDescanso.allCases, id: \.self) { opcao in
                    LinhaSelecionavel(selecionada: ritmo == opcao) {
                        escolherRitmo(opcao)
                    } rotulo: {
                        Text(opcao.rotulo)
                    }
                }
            } header: {
                Text(Copy.ajustesSecaoDescanso)
            } footer: {
                // Copy 15.5 — o efeito explicado em uma frase na própria tela,
                // que é o que o critério 8.3.5 exige.
                Text(Copy.ajustesDescansoExplicacao)
            }

            // MARK: Equipamento (spec 7.8)
            Section {
                ForEach(catalogo.selectableEquipment) { equipamento in
                    LinhaSelecionavel(selecionada: equipamentos.contains(equipamento.equipamento_id))
                    {
                        alternarEquipamento(equipamento.equipamento_id)
                    } rotulo: {
                        // O SF Symbol vem do JSON, nunca de string no código
                        // (guardrail 10 e spec 7.3).
                        Label(equipamento.nome, systemImage: equipamento.icone_sf)
                    }
                }
            } header: {
                Text(Copy.ajustesSecaoEquipamento)
            }

            // MARK: Sobre
            Section {
                LabeledContent {
                    Text(verbatim: Self.versaoDoApp)
                        .font(.valorDaLinha)
                        .foregroundStyle(Color.textoSecundario)
                } label: {
                    Text(Copy.ajustesVersaoDoApp)
                }

                LabeledContent {
                    Text(verbatim: "\(catalogo.catalogVersion)")
                        .font(.valorDaLinha)
                        .foregroundStyle(Color.textoSecundario)
                } label: {
                    Text(Copy.ajustesVersaoDoCatalogo)
                }

                Button { abrirURL(Self.privacidade) } label: {
                    Text(Copy.ajustesPrivacidade)
                }
                Button { abrirURL(Self.suporte) } label: {
                    Text(Copy.ajustesSuporte)
                }
            } header: {
                Text(Copy.ajustesSecaoSobre)
            }

            // MARK: Compra (critério 8.11)
            Section {
                // Quem quer pagar antes de gastar as três execuções livres tem
                // que conseguir. Sem esta linha, o único caminho até o paywall
                // seria esperar o limite acabar — o que é vender mal e, pior,
                // deixa o revisor da App Store sem como chegar à tela de compra.
                if !compras.comprado {
                    Button { mostrandoPaywall = true } label: {
                        Text(Copy.ajustesComprar)
                    }
                }

                Button {
                    Task { await restaurar() }
                } label: {
                    HStack {
                        Text(Copy.paywallRestaurar)
                        Spacer(minLength: 0)
                        // Estado "em processamento" declarado na seção 6 do
                        // design system.
                        if compras.processando { ProgressView() }
                    }
                }
                .disabled(compras.processando)
            } footer: {
                if let avisoDaRestauracao {
                    Text(avisoDaRestauracao)
                }
            }

            // MARK: Apagar dados
            Section {
                Button(role: .destructive) {
                    primeiraPergunta = true
                } label: {
                    Text(Copy.ajustesApagarDados)
                        .foregroundStyle(Color.statusErro)
                }
            } footer: {
                Text(Copy.ajustesApagarRodape)
            }
        }
        .listaDoApp()
        // Duas etapas, e a segunda diz o que NÃO é apagado: o dado de saúde do
        // usuário não é do app (spec 7.10 e seção 20).
        .alert(Copy.ajustesApagarPrimeiraPergunta, isPresented: $primeiraPergunta) {
            Button(role: .cancel) {} label: { Text(Copy.acaoCancelar) }
            Button(role: .destructive) { segundaPergunta = true } label: {
                Text(Copy.ajustesApagarConfirmar)
            }
        }
        .alert(Copy.ajustesApagarSegundaPergunta, isPresented: $segundaPergunta) {
            Button(role: .cancel) {} label: { Text(Copy.acaoCancelar) }
            Button(role: .destructive) { apagarTudo() } label: {
                Text(Copy.ajustesApagarConfirmar)
            }
        }
        .navigationTitle(Text(Copy.ajustes))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $mostrandoPaywall) {
            PaywallView(compras: compras)
                .presentationDetents([.large])
        }
        .task { carregar() }
    }

    // MARK: - Estado

    /// Recarrega tudo o que a tela mostra. Roda também ao voltar da P6, para a
    /// linha de valor da piscina refletir a troca.
    private func carregar() {
        guard let prefs = try? repositorio.preferenciasAtuais() else { return }
        tamanhoRaiaM = prefs.tamanhoRaiaM
        ritmo = prefs.ritmoDescanso
        equipamentos = (try? repositorio.equipamentosSelecionados()) ?? []
    }

    /// Grava o ritmo de descanso (regra 11.5 e critério 8.3.5).
    ///
    /// Vale para as **próximas** gerações. Treino já salvo mantém o ritmo com
    /// que nasceu, congelado em `ritmo_descanso_usado` (princípio 0.6).
    private func escolherRitmo(_ novo: RitmoDescanso) {
        ritmo = novo
        try? repositorio.atualizarRitmoDescanso(novo)
    }

    /// Marca ou desmarca um equipamento (spec 7.8).
    private func alternarEquipamento(_ id: String) {
        let passaAEstarMarcado = !equipamentos.contains(id)
        try? repositorio.definirEquipamento(id, selecionado: passaAEstarMarcado)
        equipamentos = (try? repositorio.equipamentosSelecionados()) ?? equipamentos
    }

    /// Restaura a compra (critério 8.11).
    private func restaurar() async {
        avisoDaRestauracao =
            await compras.restaurar() ? Copy.paywallComprado : Copy.paywallFalhaAoRestaurar
    }

    /// Apaga treinos, sessões e preferências deste aparelho.
    ///
    /// **Não apaga os `HKWorkout`.** Dado de saúde é do usuário e sai pelo app
    /// Saúde (spec 7.10 e seção 20) — apagá-lo aqui seria assumir uma autoridade
    /// que o app não tem, e é por isso que a segunda pergunta diz isso.
    ///
    /// As preferências são recriadas pelo seed na próxima leitura, com os
    /// defaults de 7.7 — inclusive `raia_confirmada = false`, que leva o usuário
    /// de volta à tela de piscina.
    private func apagarTudo() {
        try? context.delete(model: SessaoNatacao.self)
        try? context.delete(model: Treino.self)
        try? context.delete(model: EquipamentoSelecionado.self)
        try? context.delete(model: Preferencias.self)
        try? context.save()

        _ = try? repositorio.seedPreferencesIfNeeded()
        carregar()
    }

    /// A versão do app, como a ficha da loja a mostra: `1.0 (1)`.
    private static var versaoDoApp: String {
        let curta = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(curta) (\(build))"
    }

    /// Os dois links fixos da Dab Lab.
    ///
    /// Não são segredo nem variável de ambiente (spec 18): o projeto não tem
    /// nenhuma, e se aparecer uma é sinal de que alguém introduziu backend
    /// contra o anti-escopo.
    private static let privacidade = URL(
        string: "https://dablab.notion.site/politica-de-privacidade")!
    private static let suporte = URL(string: "https://suportedablab.carrd.co/")!
}

extension RitmoDescanso {

    /// O rótulo exibido nos Ajustes (DESIGN-SYSTEM.md seção 3).
    var rotulo: LocalizedStringResource {
        switch self {
        case .curto: Copy.ritmoCurto
        case .normal: Copy.ritmoNormal
        case .longo: Copy.ritmoLongo
        }
    }
}
