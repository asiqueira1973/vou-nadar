import SwiftData
import SwiftUI

/// P1 — Home (critérios 8.3.1 e 8.4).
///
/// Lê: `preferencias`, `equipamento_selecionado` e o catálogo embarcado.
/// Escreve: `preferencias` e `equipamento_selecionado`.
///
/// Estrutura: `List` inset grouped com três Sections, título grande que encolhe
/// ao rolar, engrenagem na barra de navegação e o botão primário na barra
/// inferior de área segura (DESIGN-SYSTEM.md seção 3).
///
/// **O único bloqueio desta tela é a piscina não confirmada** (regra 11.4): com
/// `raia_confirmada == false` o botão fica inerte e a copy 15.2 aparece acima
/// dele. O aviso de repertório curto (regra 11.19) **não bloqueia nada** — ele é
/// uma linha no topo da lista e o botão continua ativo.
struct HomeView: View {

    let repositorio: PreferencesRepository
    let catalogo: CatalogStore
    let compras: PurchaseService

    @Environment(\.modelContext) private var context


    @State private var minM = 1500
    @State private var maxM = 2500
    @State private var incluirEducativos = false
    @State private var incluirPernada = false
    @State private var equipamentos: Set<String> = []
    @State private var raiaConfirmada = false
    @State private var tamanhoRaiaM = 25

    @State private var mostrandoAjustes = false

    /// A piscina obrigatória da primeira abertura (regra 11.4, fluxo 9.1).
    @State private var mostrandoPiscinaObrigatoria = false

    /// O treino recém-gerado, que empurra a tela P2. Ainda **não está no
    /// banco**: ele só é gravado quando o usuário favorita.
    @State private var treinoGerado: WorkoutPresentation?

    /// O resultado bruto da última geração, guardado para a gravação copiar os
    /// campos que a apresentação não carrega — alvo de seção, ordem, descanso
    /// entre séries e entre seções.
    @State private var ultimoResultado: GenerationResult?

    /// Quantas execuções guiadas já aconteceram (critério 8.11).
    @State private var execucoesFeitas = 0
    @State private var mostrandoPaywall = false
    @State private var leitorDoHistorico = HealthHistoryReader()

    var body: some View {
        List {
            // Execuções livres acabando (assunção 24.5). Fica ANTES do aviso de
            // repertório porque é o único que custa dinheiro ao usuário — ele
            // precisa saber antes de chegar à borda da piscina e descobrir lá.
            if let restantes = execucoesLivresRestantes {
                Section {
                    Button {
                        mostrandoPaywall = true
                    } label: {
                        LabeledContent {
                            Text(Copy.paywallRestaurar)
                                .font(.footnote)
                                .foregroundStyle(.tint)
                        } label: {
                            Text(Copy.paywallExecucoesRestantes(restantes))
                                .font(.footnote)
                                .foregroundStyle(Color.textoSecundario)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Aviso de repertório curto, quando houver: primeira linha da lista,
            // e o botão continua ativo (regra 11.19).
            if precisaAvisarRepertorioCurto {
                Section {
                    Label {
                        Text(Copy.homeRepertorioCurto)
                            .font(.footnote)
                            .foregroundStyle(Color.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: Simbolos.avisoRepertorioCurto)
                            .foregroundStyle(Color.statusAlerta)
                    }
                }
            }

            // MARK: Distância
            Section {
                LabeledContent {
                    Text(verbatim: Formato.faixa(minM: minM, maxM: maxM))
                        .font(.valorDaLinha)
                        .foregroundStyle(Color.textoSecundario)
                } label: {
                    Text(Copy.homeFaixa)
                }

                DistanceRangeSlider(minM: $minM, maxM: $maxM) {
                    try? repositorio.atualizarFaixa(minM: minM, maxM: maxM)
                }
            } header: {
                Text(Copy.homeSecaoDistancia)
            }

            // MARK: Equipamento na mochila
            Section {
                ForEach(catalogo.selectableEquipment) { equipamento in
                    LinhaSelecionavel(selecionada: equipamentos.contains(equipamento.equipamento_id))
                    {
                        alternarEquipamento(equipamento.equipamento_id)
                    } rotulo: {
                        Label(equipamento.nome, systemImage: equipamento.icone_sf)
                    }
                }
            } header: {
                Text(Copy.homeSecaoEquipamento)
            }

            // MARK: Interruptores
            Section {
                // `Toggle` do sistema, com a descrição num `VStack` dentro do
                // rótulo — não redesenhado (guardrail 11).
                Toggle(isOn: $incluirEducativos) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.homeIncluirEducativos)
                        Text(Copy.homeIncluirEducativosNota)
                            .font(.footnote)
                            .foregroundStyle(Color.textoSecundario)
                    }
                }
                .onChange(of: incluirEducativos) { _, _ in gravarInterruptores() }

                Toggle(isOn: $incluirPernada) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.homeIncluirPernada)
                        Text(Copy.homeIncluirPernadaNota)
                            .font(.footnote)
                            .foregroundStyle(Color.textoSecundario)
                    }
                }
                .onChange(of: incluirPernada) { _, _ in gravarInterruptores() }
            }
        }
        .listaDoApp()
        // Título grande que encolhe para `.headline` na barra ao rolar
        // (guardrail 7).
        .navigationTitle(Text(Copy.appNome))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    mostrandoAjustes = true
                } label: {
                    Image(systemName: Simbolos.ajustes)
                }
                // Botão só com símbolo precisa de rótulo (design system 9).
                .accessibilityLabel(Text(Copy.a11yAbrirAjustes))
            }
        }
        .safeAreaInset(edge: .bottom) {
            BarraDeAcaoPrimaria(
                motivoDoBloqueio: raiaConfirmada ? nil : Copy.homeBloqueadoSemPiscina,
                acao: { gerar() }
            ) {
                Text(Copy.homeBotaoGerar)
            }
        }
        .navigationDestination(isPresented: $mostrandoAjustes) {
            SettingsView(repositorio: repositorio, catalogo: catalogo, compras: compras)
        }
        .sheet(isPresented: $mostrandoPaywall) {
            PaywallView(compras: compras)
                .presentationDetents([.large])
        }
        .navigationDestination(item: $treinoGerado) { treino in
            WorkoutDetailView(
                treino: treino,
                aoFavoritar: { titulo in try favoritar(treino, titulo: titulo) },
                aoGerarOutro: gerarOutro)
        }
        // A piscina da primeira abertura é apresentada em folha que não fecha
        // por gesto: ela é requisito da geração, não uma preferência que se
        // adia (regra 11.4).
        .sheet(isPresented: $mostrandoPiscinaObrigatoria) {
            NavigationStack {
                PoolSizeView(repositorio: repositorio, modo: .obrigatoria) {
                    mostrandoPiscinaObrigatoria = false
                    carregar()
                }
            }
            .interactiveDismissDisabled()
        }
        .onChange(of: mostrandoAjustes) { _, aberto in
            // Voltar dos Ajustes pode ter trocado piscina, ritmo ou equipamento.
            if !aberto { carregar() }
        }
        .task {
            aoAparecer()
            await contarExecucoes()
        }
    }

    // MARK: - Estado

    /// Carrega as preferências e decide se a piscina obrigatória entra na frente
    /// (fluxo 9.1).
    private func aoAparecer() {
        carregar()
        if !raiaConfirmada { mostrandoPiscinaObrigatoria = true }
    }

    /// Quantas execuções livres restam, ou nulo quando não há o que avisar —
    /// já comprou, ou ainda nem começou.
    ///
    /// **Gerar treino nunca é bloqueado** (critério 8.11): este aviso é
    /// informação, e o botão Gerar continua ativo em qualquer caso.
    private var execucoesLivresRestantes: Int? {
        guard !compras.comprado else { return nil }
        let restantes = PurchaseGate.execucoesLivresRestantes(
            comprado: false, execucoesFeitas: execucoesFeitas)
        // Só avisa quando já usou pelo menos uma: antes disso, falar de limite
        // seria vender antes de entregar.
        return execucoesFeitas > 0 ? restantes : nil
    }

    /// Conta as execuções guiadas pelo HealthKit (critério 8.11).
    private func contarExecucoes() async {
        let desde = Date(timeIntervalSinceNow: -60 * 60 * 24 * 365 * 5)
        execucoesFeitas = await leitorDoHistorico.execucoesDoApp(desde: desde)
    }

    private func carregar() {
        guard let prefs = try? repositorio.preferenciasAtuais() else { return }
        minM = prefs.distanciaMinM
        maxM = prefs.distanciaMaxM
        incluirEducativos = prefs.incluirEducativos
        incluirPernada = prefs.incluirPernada
        raiaConfirmada = prefs.raiaConfirmada
        tamanhoRaiaM = prefs.tamanhoRaiaM
        equipamentos = (try? repositorio.equipamentosSelecionados()) ?? []
    }

    private func gravarInterruptores() {
        try? repositorio.atualizarInterruptores(
            incluirEducativos: incluirEducativos, incluirPernada: incluirPernada)
    }

    // MARK: - Geração (épico 8.4)

    /// Gera um treino com o que está na tela e empurra a P2 (critério 8.4).
    ///
    /// O motor é **função pura** (contrato 13.1) e roda em poucos
    /// milissegundos sobre os 226 exercícios, bem dentro do orçamento de 1
    /// segundo do requisito 17.2 — por isso a chamada é direta, sem tarefa em
    /// segundo plano nem indicador de progresso.
    ///
    /// Nada é gravado aqui: a persistência é do épico 8.5.
    private func gerar(anteriores: [String]? = nil) {
        guard raiaConfirmada else { return }

        // Regra 11.3: o catálogo é adaptado à piscina ANTES do sorteio, e é
        // isso que faz a verificação de faixa da regra 11.2 rodar sobre a
        // distância real.
        let adaptado = AdaptedCatalog(
            catalogo: catalogo.allExercises, tamanhoRaiaM: tamanhoRaiaM)

        let ritmo = (try? repositorio.preferenciasAtuais().ritmoDescanso) ?? .normal
        var rng = SystemRandomNumberGenerator()
        let resultado = WorkoutGenerator(catalogo: adaptado).gerar(
            GenerationRequest(
                minMeters: minM, maxMeters: maxM,
                selectedEquipment: equipamentos,
                includeDrills: incluirEducativos, includeKick: incluirPernada,
                laneLengthM: tamanhoRaiaM, restPace: ritmo,
                previousExerciseIds: anteriores),
            using: &rng)

        ultimoResultado = resultado
        treinoGerado = WorkoutPresentation(resultado: resultado, catalogo: catalogo)
    }

    /// Favorita o treino que está na tela (épico 8.5, regra 11.14).
    ///
    /// **É aqui que o treino entra no banco.** Um treino gerado e não favoritado
    /// não é persistido: ele vive só enquanto está na tela, e "Gerar outro" o
    /// substitui. Gravar toda geração encheria o store de treinos que ninguém
    /// pediu — e o spec do Vou Nadar, ao contrário do Swim Builder, não tem
    /// regra de limpeza automática. Princípio 0.7: a solução mais simples que
    /// funciona.
    ///
    /// A gravação leva as quatro seções e todas as séries, com os descansos e as
    /// voltas exatamente como a geração os congelou (critério 8.5 e princípio
    /// 0.6).
    private func favoritar(_ apresentacao: WorkoutPresentation, titulo: String) throws {
        guard let resultado = ultimoResultado else { return }
        let repositorioDeTreinos = WorkoutRepository(context: context)
        let treino = try repositorioDeTreinos.salvar(
            resultado, origem: .gerado_iphone, faixaPedida: minM...maxM)
        try repositorioDeTreinos.favoritar(treino, titulo: titulo)
        // A tela volta a mostrar o treino já com o título, lido do banco.
        treinoGerado = WorkoutPresentation(treino: treino, catalogo: catalogo)
    }

    /// "Gerar outro" do menu da P2: mesma faixa, conjunto de exercícios
    /// diferente.
    private func gerarOutro() {
        gerar(anteriores: treinoGerado?.todosOsExercicioIds)
    }

    private func alternarEquipamento(_ id: String) {
        let passaAEstarMarcado = !equipamentos.contains(id)
        try? repositorio.definirEquipamento(id, selecionado: passaAEstarMarcado)
        equipamentos = (try? repositorio.equipamentosSelecionados()) ?? equipamentos
    }

    /// Regra 11.19: menos de 30 candidatos com esta combinação de raia,
    /// equipamentos e interruptores.
    private var precisaAvisarRepertorioCurto: Bool {
        guard raiaConfirmada else { return false }
        return RepertoireGuard.deveAvisar(
            catalogo: catalogo.allExercises,
            tamanhoRaiaM: tamanhoRaiaM,
            equipamentos: equipamentos,
            incluirEducativos: incluirEducativos,
            incluirPernada: incluirPernada)
    }
}
