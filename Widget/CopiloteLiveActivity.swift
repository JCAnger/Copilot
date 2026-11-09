import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Diagnostic CarPlay
// Passe à true pour remplacer la vue CarPlay par un simple texte.
// Si Copilote apparaît alors dans CarPlay, c'est la mise en page compacte qui pose problème.
let modeDiagnostic = false

/// Live Activity « Copilote ».
/// - `.medium` : écran verrouillé / bannière iPhone
/// - `.small`  : CarPlay (Dashboard) et Smart Stack de l'Apple Watch
struct CopiloteLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CopiloteAttributes.self) { context in
            CopiloteVue(etat: context.state)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LogoVue(etat: context.state, taille: 34)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.valeur)
                        .font(.title3.bold())
                        .foregroundStyle(.green)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.titre).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } compactLeading: {
                // CarPlay combine compactLeading et compactTrailing : le titre y est visible.
                HStack(spacing: 6) {
                    LogoVue(etat: context.state, taille: 22)
                    Text(context.state.titre)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            } compactTrailing: {
                Text(context.state.valeur).font(.caption.bold()).foregroundStyle(.green)
            } minimal: {
                LogoVue(etat: context.state, taille: 22)
            }
        }
        // 👉 Déclare une mise en page dédiée pour CarPlay et l'Apple Watch.
        // Test de diagnostic : commente cette ligne pour laisser le système
        // utiliser sa présentation compacte par défaut.
        .supplementalActivityFamilies([.small])
    }
}

/// Couleurs adaptatives : fond blanc et texte foncé en mode clair,
/// fond sombre et texte clair en mode sombre (suit l'apparence du système).
private extension Color {
    static func adaptative(clair: (Double, Double, Double), sombre: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? sombre : clair
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }

    static let texteFonce = adaptative(clair: (0.08, 0.10, 0.14), sombre: (0.96, 0.97, 0.98))
    static let texteSecondaireFonce = adaptative(clair: (0.28, 0.31, 0.37), sombre: (0.70, 0.73, 0.78))
    static let bleuFonce = adaptative(clair: (0.0, 0.30, 0.80), sombre: (0.40, 0.65, 1.0))
    static let vertFonce = adaptative(clair: (0.0, 0.42, 0.20), sombre: (0.30, 0.85, 0.50))
}

/// Choisit la présentation selon la famille demandée par le système.
struct CopiloteVue: View {
    @Environment(\.activityFamily) private var famille
    let etat: CopiloteAttributes.ContentState

    var body: some View {
        switch famille {
        case .small:
            // CarPlay rend la Live Activity en apparence sombre (fond gris, texte blanc).
            // On impose un fond blanc laiteux et l'apparence claire pour s'aligner
            // sur les autres tuiles du Dashboard (texte foncé sur fond clair).
            Group {
                if modeDiagnostic {
                    Text("Copilote · \(etat.valeur)")
                } else {
                    VueCompacteCarPlay(etat: etat)
                }
            }
            .environment(\.colorScheme, .light)
            // La teinte seule est mélangée au fond sombre du système (rendu gris) :
            // on peint donc nous-mêmes un fond clair opaque sur toute la tuile.
            .background {
                ContainerRelativeShape()
                    .fill(Color(white: 0.94))
                    .ignoresSafeArea()
            }
            .activityBackgroundTint(Color(white: 0.94))
        default:
            // iPhone : fond transparent au lieu du fond blanc opaque par défaut.
            VueEcranVerrouille(etat: etat)
                .activityBackgroundTint(.clear)
        }
    }
}

/// Version CarPlay : une info, lisible en une seconde.
/// Polices et couleurs système pour rester lisible sur tous les écrans de voiture.
struct VueCompacteCarPlay: View {
    let etat: CopiloteAttributes.ContentState

    var body: some View {
        HStack(spacing: 5) {
            // Logo de l'enseigne, ou pastille colorée : le symbole se repère d'un coup d'œil.
            if etat.enseigne != nil {
                LogoVue(etat: etat, taille: 34)
            } else {
                Image(systemName: etat.scenario.symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(etat.titre)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.texteFonce)
                    .lineLimit(2)
                    .layoutPriority(1)
                // Seconde ligne : prix, durée de conduite, adresse…
                Text(etat.detail)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.texteSecondaireFonce)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
            }
            Spacer(minLength: 4)
            // La valeur reste à droite, mais discrète pour ne pas masquer le titre et le détail.
            Text(etat.valeur)
                .font(.caption.bold())
                .foregroundStyle(Color.vertFonce)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: 48, alignment: .trailing)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Version écran verrouillé : un peu plus de contexte.
struct VueEcranVerrouille: View {
    let etat: CopiloteAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            // Fond transparent : textes clairs pour rester lisibles sur le fond d'écran.
            LogoVue(etat: etat, taille: 50, couleurSymbole: .white)
            VStack(alignment: .leading, spacing: 3) {
                Text(etat.scenario.label.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.75))
                Text(etat.titre).font(.headline).foregroundStyle(.white)
                Text(etat.detail).font(.subheadline).foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            Text(etat.valeur)
                .font(.title2.bold())
                .foregroundStyle(.green)
        }
        .padding()
    }
}

// MARK: - Aperçus Xcode

// Valeurs d'exemple utilisées uniquement par l'aperçu Xcode ; l'app n'affiche que des données réelles.
#Preview("Écran verrouillé", as: .content, using: CopiloteAttributes(nomTrajet: "Aperçu")) {
    CopiloteLiveActivity()
} contentStates: {
    CopiloteAttributes.ContentState(scenario: .carburant, titre: "TotalEnergies",
                                    detail: "Gazole 1,859 € · Coupvray", valeur: "2,4 km",
                                    enseigne: .totalenergies)
    CopiloteAttributes.ContentState(scenario: .pause, titre: "Aire de repos",
                                    detail: "Pause conseillée", valeur: "12 km")
}
