import Foundation
import SwiftData

/// As preferências do app — singleton, exatamente uma linha (spec 7.7).
///
/// Nasce na primeira abertura por `PreferencesRepository.seedPreferencesIfNeeded()`
/// com os defaults desta declaração, e nunca é apagada, exceto por "Apagar
/// todos os dados" nos Ajustes.
///
/// A unicidade é garantida **por código** no acesso (busca-o-primeiro-ou-cria):
/// o SwiftData não expressa "no máximo uma linha" (spec 7.11).
///
/// Cada aparelho tem o seu store (spec 4.1). Em conflito de sincronização vence
/// o `atualizado_em` mais recente (regra 11.12).
@Model
final class Preferencias {

    @Attribute(originalName: "id")
    var id: UUID

    /// Piso da faixa de distância pedida na geração.
    @Attribute(originalName: "distancia_min_m")
    var distanciaMinM: Int = 1500

    /// Teto da faixa. **Pode ser igual ao piso** — faixa fechada é caso de uso
    /// legítimo, e a tela P1 tem um estado próprio para ela (spec 7.7).
    @Attribute(originalName: "distancia_max_m")
    var distanciaMaxM: Int = 2500

    @Attribute(originalName: "incluir_educativos")
    var incluirEducativos: Bool = false

    @Attribute(originalName: "incluir_pernada")
    var incluirPernada: Bool = false

    /// Comprimento da raia, em metros. Aceita **10 a 50** (assunção 24.3).
    ///
    /// A faixa é larga de propósito: piscina de condomínio e de academia
    /// costuma ter 12, 15, 16, 18 ou 20 m, e o app precisa servi-las. Alimenta
    /// duas coisas — o `lapLength` do `HKWorkoutSession` (spec 13.4) e a
    /// adaptação de distância da regra 11.3.
    ///
    /// A validação de 10...50 vive na camada de acesso (spec 7.11).
    @Attribute(originalName: "tamanho_raia_m")
    var tamanhoRaiaM: Int = 25

    /// Falso até o usuário confirmar a piscina uma vez.
    ///
    /// **Enquanto for falso, não é possível gerar treino** — nos dois aparelhos
    /// (regra 11.4). Não é só requisito da execução: a regra 11.3 muda as
    /// distâncias e o próprio conteúdo do treino conforme a raia, então gerar
    /// antes de saber a piscina produziria um treino para piscina nenhuma.
    @Attribute(originalName: "raia_confirmada")
    var raiaConfirmada: Bool = false

    /// Multiplicador global da tabela de descanso (regra 11.5): `curto` 0,75×,
    /// `normal` 1,0×, `longo` 1,5×.
    ///
    /// É o único ajuste de descanso que o v1 oferece — editar bloco a bloco
    /// ficou para a v2 (roadmap 28.3). O valor vigente é congelado em
    /// `treino.ritmo_descanso_usado` a cada geração (princípio 0.6).
    @Attribute(originalName: "ritmo_descanso")
    var ritmoDescanso: RitmoDescanso = RitmoDescanso.normal

    /// Última `versao_catalogo` que o usuário viu.
    ///
    /// O default de schema é 0, mas o **seed grava a versão embarcada**, para
    /// instalação nova não ver banner de novidade no primeiro dia (spec 7.7).
    @Attribute(originalName: "versao_catalogo_visto")
    var versaoCatalogoVisto: Int = 0

    /// Decide quem vence na sincronização iPhone → Watch (regra 11.12).
    @Attribute(originalName: "atualizado_em")
    var atualizadoEm: Date

    @Attribute(originalName: "criado_em")
    var criadoEm: Date

    init(
        id: UUID = UUID(),
        distanciaMinM: Int = 1500,
        distanciaMaxM: Int = 2500,
        incluirEducativos: Bool = false,
        incluirPernada: Bool = false,
        tamanhoRaiaM: Int = 25,
        raiaConfirmada: Bool = false,
        ritmoDescanso: RitmoDescanso = .normal,
        versaoCatalogoVisto: Int = 0,
        atualizadoEm: Date = .now,
        criadoEm: Date = .now
    ) {
        self.id = id
        self.distanciaMinM = distanciaMinM
        self.distanciaMaxM = distanciaMaxM
        self.incluirEducativos = incluirEducativos
        self.incluirPernada = incluirPernada
        self.tamanhoRaiaM = tamanhoRaiaM
        self.raiaConfirmada = raiaConfirmada
        self.ritmoDescanso = ritmoDescanso
        self.versaoCatalogoVisto = versaoCatalogoVisto
        self.atualizadoEm = atualizadoEm
        self.criadoEm = criadoEm
    }
}

extension Preferencias {

    /// Faixa aceita para o comprimento da raia (assunção 24.3).
    ///
    /// Fica aqui, e não espalhada pela UI, porque três telas dependem dela: a
    /// P6 do iPhone, a W5 do relógio e a validação do repositório.
    static let faixaDeRaia = 10...50

    /// Faixa fechada: o usuário pediu uma distância exata em vez de um
    /// intervalo. Estado válido e com desenho próprio na tela P1 (spec 7.7).
    var faixaEstaFechada: Bool { distanciaMinM == distanciaMaxM }
}
